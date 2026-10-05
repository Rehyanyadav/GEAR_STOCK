import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../features/products/data/products_notifier.dart';
import '../features/stock/data/stock_notifier.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../theme/app_theme.dart';

import '../widgets/gooey_hover_button.dart';
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({
    super.key,
  });

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedRange = 'This Month';
  final List<String> _ranges = ['Today', 'This Week', 'This Month', 'All Time'];
  bool _isExporting = false;

  DateTime _getFilterStartDate(String range) {
    final now = DateTime.now();
    switch (range) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'All Time':
      default:
        return DateTime(2000, 1, 1);
    }
  }

  Future<void> _exportInventoryCsv(List<Product> products) async {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final List<List<dynamic>> rows = [
        [
          'Part Name',
          'Barcode',
          'SKU',
          'Category',
          'Brand',
          'Cost Price (₹)',
          'Selling Price (₹)',
          'Current Stock',
          'Min Stock',
          'Stock Value (₹)',
          'Supplier',
          'Status',
        ],
      ];

      for (final p in products) {
        rows.add([
          p.name,
          p.barcode,
          p.sku,
          p.category,
          p.brand,
          p.costPrice.toStringAsFixed(2),
          p.sellingPrice.toStringAsFixed(2),
          p.currentStock,
          p.minStock,
          (p.currentStock * p.costPrice).toStringAsFixed(2),
          p.supplierName,
          p.isLowStock ? 'LOW STOCK' : 'IN STOCK',
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name: 'GearStock_Inventory_$dateStr.csv',
      );

      await Share.shareXFiles(
        [xfile],
        text: 'GearStock Inventory Report ($dateStr)',
        subject: 'GearStock Bicycle Parts Inventory Report',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final movementsAsync = ref.watch(stockProvider);

    final products = productsAsync.valueOrNull ?? [];
    final movements = movementsAsync.valueOrNull ?? [];

    // Genuine calculations
    double totalVal = 0.0;
    double totalRetailVal = 0.0;
    final Map<String, double> categoryValues = {};

    for (final p in products) {
      final costVal = p.currentStock * p.costPrice;
      totalVal += costVal;
      totalRetailVal += (p.currentStock * p.sellingPrice);
      final cat = p.category.isNotEmpty ? p.category : 'General';
      categoryValues[cat] = (categoryValues[cat] ?? 0) + costVal;
    }

    // Genuine Average Profit Margin
    double avgMargin = 0.0;
    final validMargins = products.where((p) => p.sellingPrice > 0).map((p) => p.profitMargin).toList();
    if (validMargins.isNotEmpty) {
      avgMargin = validMargins.reduce((a, b) => a + b) / validMargins.length;
    }

    // High turnover products computed from genuine movements in selected range
    final startDate = _getFilterStartDate(_selectedRange);
    final periodMovements = movements.where((m) {
      final isOutbound = m.type == StockMovementType.outboundSale ||
          m.type == StockMovementType.outboundService;
      final inRange = m.timestamp.isAfter(startDate) || m.timestamp.isAtSameMomentAs(startDate);
      return isOutbound && inRange;
    }).toList();

    // Map productId -> total units issued
    final Map<String, int> productIssuedMap = {};
    for (final m in periodMovements) {
      productIssuedMap[m.productId] = (productIssuedMap[m.productId] ?? 0) + m.quantity;
    }

    final sortedTurnover = productIssuedMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Audit metrics
    final totalParts = products.length;
    final lowStockCount = products.where((p) => p.isLowStock && p.currentStock > 0).length;
    final outOfStockCount = products.where((p) => p.currentStock <= 0).length;
    final healthyCount = totalParts - lowStockCount - outOfStockCount;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Inventory Reports & Audits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share / Export CSV',
                  onPressed: () => _exportInventoryCsv(products),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time range selector
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _ranges.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final r = _ranges[index];
                  final isSelected = _selectedRange == r;
                  return ChoiceChip(
                    label: Text(r),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedRange = r);
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                    labelStyle: TextStyle(
                      color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide.none,
                    showCheckmark: false,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Top Valuation Grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text('Total Inventory Cost', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalVal.toStringAsFixed(0)}',
                          style:  TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                             Icon(Icons.inventory_2_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '$totalParts parts in stock',
                              style:  TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text('Avg Profit Margin', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary)),
                        const SizedBox(height: 4),
                        Text(
                          '${avgMargin.toStringAsFixed(1)}%',
                          style:  TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              avgMargin >= 15 ? Icons.check_circle : Icons.warning_amber_rounded,
                              size: 14,
                              color: avgMargin >= 15 ? AppStatusColors.of(context).success : Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Retail: ₹${totalRetailVal.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: avgMargin >= 15 ? AppStatusColors.of(context).success : Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stock Audit Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('STOCK HEALTH & AUDIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHealthBadge(
                          'Healthy Stock',
                          '$healthyCount',
                          AppStatusColors.of(context).success,
                          Icons.check_circle_outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHealthBadge(
                          'Low Stock',
                          '$lowStockCount',
                          Colors.amber.shade700,
                          Icons.warning_amber_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHealthBadge(
                          'Out of Stock',
                          '$outOfStockCount',
                          Theme.of(context).colorScheme.error,
                          Icons.cancel_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category Valuation Breakdown Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'CAPITAL BY CATEGORY',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 14),
                  if (categoryValues.isEmpty)
                     Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No categorized products found.', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.secondary)),
                    )
                  else
                    ...categoryValues.entries.map((entry) {
                      final fraction = totalVal > 0 ? (entry.value / totalVal) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(
                                  '₹${entry.value.toStringAsFixed(0)} (${(fraction * 100).toStringAsFixed(1)}%)',
                                  style:  TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 6,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                                valueColor:  AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Fast Moving Parts Card (Real dynamic movements)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'HIGH TURNOVER ITEMS ($_selectedRange)',
                        style:  TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, letterSpacing: 0.6),
                      ),
                      const Icon(Icons.bolt, color: Colors.amber, size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (sortedTurnover.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.query_stats, size: 36, color: Theme.of(context).colorScheme.secondary.withAlpha(120)),
                            const SizedBox(height: 6),
                             Text(
                              'No parts issued in this time range.',
                              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.secondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...sortedTurnover.take(5).map((entry) {
                      final prod = products.where((p) => p.id == entry.key).firstOrNull;
                      final name = prod?.name ?? 'Part ID: ${entry.key.substring(0, 8)}...';
                      final units = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                             Icon(Icons.trending_up, color: Theme.of(context).colorScheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryFixed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$units units issued',
                                style:  TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Export button at bottom
            SizedBox(
              width: double.infinity,
              height: 48,
              child: GooeyHoverButton(child: ElevatedButton.icon(
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export Complete CSV Report', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _exportInventoryCsv(products),
              )),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthBadge(String title, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
