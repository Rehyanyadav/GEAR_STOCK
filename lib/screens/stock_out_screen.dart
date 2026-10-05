import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/products/data/products_notifier.dart';
import '../features/stock/data/stock_notifier.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../theme/app_theme.dart';

import '../widgets/gooey_hover_button.dart';
class StockOutItem {
  Product product;
  int quantity;
  double unitPrice;
  StockOutItem({required this.product, required this.quantity, required this.unitPrice});
}

class StockOutScreen extends ConsumerStatefulWidget {
  final Product? preselectedProduct;

  const StockOutScreen({
    super.key,
    this.preselectedProduct,
  });

  @override
  ConsumerState<StockOutScreen> createState() => _StockOutScreenState();
}

class _StockOutScreenState extends ConsumerState<StockOutScreen> {
  final TextEditingController _referenceController =
      TextEditingController(text: 'JOB-${DateTime.now().minute}${DateTime.now().second}');
  final TextEditingController _notesController = TextEditingController();

  StockMovementType _selectedType = StockMovementType.outboundService;
  final List<StockOutItem> _outboundItems = [];
  bool _includeGst = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedProduct != null) {
      _outboundItems.add(
        StockOutItem(
          product: widget.preselectedProduct!,
          quantity: 1,
          unitPrice: widget.preselectedProduct!.sellingPrice,
        ),
      );
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _outboundItems.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  double get _gstAmount => _includeGst ? (_subtotal * 0.18) : 0.0;
  double get _grandTotal => _subtotal + _gstAmount;

  void _showAddProductDialog(List<Product> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Part to Issue',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: products.isEmpty
                      ? const Center(child: Text('No products in catalog yet.'))
                      : ListView.builder(
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final hasStock = product.currentStock > 0;
                            return ListTile(
                              leading:  Icon(Icons.build_circle, color: Theme.of(context).colorScheme.primaryContainer),
                              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${product.barcode.isNotEmpty ? product.barcode : product.sku} • Stock: ${product.currentStock} left',
                                style: TextStyle(color: hasStock ? null : Theme.of(context).colorScheme.error),
                              ),
                              trailing: Text(
                                '₹${product.sellingPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              enabled: hasStock,
                              onTap: () {
                                setState(() {
                                  _outboundItems.add(
                                    StockOutItem(
                                      product: product,
                                      quantity: 1,
                                      unitPrice: product.sellingPrice,
                                    ),
                                  );
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmStockOut() async {
    if (_outboundItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item to issue.')),
      );
      return;
    }

    // Validate quantities
    for (final item in _outboundItems) {
      if (item.quantity > item.product.currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot issue ${item.quantity} units of ${item.product.name}. Only ${item.product.currentStock} left in stock!'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(stockProvider.notifier).addStockOutBatch([
        for (final item in _outboundItems)
          StockOutEntry(
            productId: item.product.id,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            note: _notesController.text.trim(),
            referenceNumber: _referenceController.text.trim(),
          ),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock out logged successfully (${_selectedType.label})!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProducts = ref.watch(productsProvider);

    return asyncProducts.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (products) => _buildScaffold(products),
    );
  }

  Widget _buildScaffold(List<Product> products) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Issue Stock',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHigh)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Total Issue Value', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary)),
                      Text(
                        '₹${_grandTotal.toStringAsFixed(0)}',
                        style:  TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primaryContainer),
                      ),
                    ],
                  ),
                  Text(
                    '${_outboundItems.length} items selected',
                    style:  TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: GooeyHoverButton(child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.remove_circle),
                  label: const Text('Confirm Stock Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  onPressed: _isSubmitting ? null : _confirmStockOut,
                )),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outbound Type Segmented Control
             Text('REASON / TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeChip(StockMovementType.outboundSale, '🛍️ Counter Sale (दुकान बिक्री)'),
                  const SizedBox(width: 8),
                  _buildTypeChip(StockMovementType.outboundService, '🔧 Workshop Repair (सर्विस)'),
                  const SizedBox(width: 8),
                  _buildTypeChip(StockMovementType.returnToVendor, '🔄 Vendor Return (वापसी)'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reference and Notes Card
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
                  const Text('Reference / Job Card #', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _referenceController,
                    decoration:  InputDecoration(
                      hintText: 'e.g. Job #88 or Walk-in Cash Sale',
                      prefixIcon: Icon(Icons.tag, size: 20, color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Customer or Mechanic Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    decoration:  InputDecoration(
                      hintText: 'e.g. Trek Domane rear brake caliper replacement',
                      prefixIcon: Icon(Icons.note_alt_outlined, size: 20, color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Line items header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(
                  'PARTS TO ISSUE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                ),
                TextButton.icon(
                  onPressed: () => _showAddProductDialog(products),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Part'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (_outboundItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('No parts added to this outbound ticket yet.'),
                ),
              )
            else
              ...List.generate(_outboundItems.length, (index) {
                final item = _outboundItems[index];
                final isOutOfStock = item.quantity > item.product.currentStock;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOutOfStock ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:  Icon(Icons.build_circle, color: Theme.of(context).colorScheme.primaryContainer, size: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'SKU: ${item.product.sku}',
                                      style:  TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${item.product.currentStock} in stock)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: item.product.isLowStock ? Theme.of(context).colorScheme.error : AppStatusColors.of(context).success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon:  Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.secondary),
                            onPressed: () {
                              setState(() {
                                _outboundItems.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                               Text('Quantity: ', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 16),
                                      onPressed: () {
                                        if (item.quantity > 1) {
                                          setState(() => item.quantity--);
                                        }
                                      },
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 16),
                                      onPressed: () {
                                        setState(() => item.quantity++);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${(item.quantity * item.unitPrice).toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '@ ₹${item.unitPrice.toStringAsFixed(0)}/ea',
                                style:  TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.secondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (isOutOfStock) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child:  Row(
                            children: [
                              Icon(Icons.error_outline, size: 12, color: Theme.of(context).colorScheme.onErrorContainer),
                              SizedBox(width: 4),
                              Text(
                                'Quantity exceeds available stock on floor!',
                                style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onErrorContainer, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),

            const SizedBox(height: 12),

            // Tax & Billing Option
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Include 18% GST in Bill', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Switch(
                    value: _includeGst,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: (val) => setState(() => _includeGst = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(StockMovementType type, String label) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedType = type);
      },
      selectedColor: Theme.of(context).colorScheme.primaryFixed,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide.none,
      showCheckmark: false,
    );
  }
}
