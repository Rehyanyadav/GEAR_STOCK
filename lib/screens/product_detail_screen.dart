import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/products/data/products_notifier.dart';
import '../features/stock/data/stock_notifier.dart';
import '../models/stock_movement.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import 'add_edit_product_screen.dart';
import 'stock_in_screen.dart';
import 'stock_out_screen.dart';

import '../widgets/gooey_hover_button.dart';
class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final stockAsync = ref.watch(stockProvider);

    return productsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error loading products: $e'))),
      data: (products) {
        final product = products.where((p) => p.id == widget.productId).firstOrNull;

        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Product Not Found')),
            body: const Center(child: Text('Product does not exist or was deleted.')),
          );
        }

        final productMovements = stockAsync.valueOrNull?.where((m) => m.productId == product.id).toList() ?? [];

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Text(
              product.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Part',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditProductScreen(
                        productToEdit: product,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Specs',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Part details copied: ${product.name} (${product.sku})'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHigh)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: GooeyHoverButton(child: OutlinedButton.icon(
                      icon:  Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.primaryContainer),
                      label: const Text('Stock Out'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side:  BorderSide(color: Theme.of(context).colorScheme.primaryContainer, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StockOutScreen(
                              preselectedProduct: product,
                            ),
                          ),
                        );
                      },
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GooeyHoverButton(child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Stock In'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StockInScreen(
                              preselectedProduct: product,
                            ),
                          ),
                        );
                      },
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
                // Hero Visual Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
                  ),
                  child: Column(
                    children: [
                      // Verification badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryFixed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'GENUINE ${product.brand.toUpperCase()}',
                              style:  TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: product.isLowStock ? Theme.of(context).colorScheme.errorContainer : AppStatusColors.of(context).successContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              product.isLowStock
                                  ? 'Low Stock: ${product.currentStock} Units'
                                  : 'In Stock: ${product.currentStock} Units',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: product.isLowStock
                                    ? Theme.of(context).colorScheme.onErrorContainer
                                    : AppStatusColors.of(context).onSuccessContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Large Component Illustration / Icon
                      ProductImage(
                        source: product.imageUrl,
                        width: 160,
                        height: 128,
                        borderRadius: 12,
                        placeholderIcon: Icons.precision_manufacturing,
                      ),
                      const SizedBox(height: 16),

                      // Title & Brand
                      Text(
                        product.name,
                        textAlign: TextAlign.center,
                        style:  TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${product.brand} • ${product.category}',
                        style:  TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Barcode & SKU Row with Copy
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: product.barcode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Barcode ${product.barcode} copied to clipboard'),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               Icon(Icons.qr_code_2, size: 16, color: Theme.of(context).colorScheme.secondary),
                              const SizedBox(width: 6),
                              Text(
                                'SKU: ${product.sku}  |  EAN: ${product.barcode}',
                                style:  TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                               Icon(Icons.copy, size: 12, color: Theme.of(context).colorScheme.secondary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Key Metrics 4-Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Available Stock',
                        value: '${product.currentStock}',
                        sublabel: 'Floor count',
                        highlight: product.isLowStock,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Min Threshold',
                        value: '${product.minStock}',
                        sublabel: 'Safety limit',
                        highlight: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Shelf / Bin',
                        value: product.shelfLocation,
                        sublabel: 'Workshop aisle',
                        highlight: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Profit Margin',
                        value: '${product.profitMargin.toStringAsFixed(0)}%',
                        sublabel: 'Net spread',
                        highlight: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Pricing Breakdown Card
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
                        'PRICING STRUCTURE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.secondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Retail Selling Price', style: TextStyle(fontSize: 13)),
                          Text(
                            '₹${product.sellingPrice.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text('Mechanic Trade Price', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.secondary)),
                          Text(
                            '₹${(product.sellingPrice * 0.9).toStringAsFixed(0)}',
                            style:  TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text('Wholesale Landing Cost', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.secondary)),
                          Text(
                            '₹${product.costPrice.toStringAsFixed(0)}',
                            style:  TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Description & Specifications Card
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
                        'TECHNICAL SPECIFICATIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.secondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        product.description,
                        style:  TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      ...product.specs.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 130,
                                child: Text(
                                  entry.key,
                                  style:  TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
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

                // Primary Supplier Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:  Icon(Icons.local_shipping_outlined, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                              'PRIMARY SUPPLIER',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                            ),
                            Text(
                              product.supplierName,
                              style:  TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                            ),
                             Text(
                              'Average delivery turnaround: 2-3 days',
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stock Movement Timeline
                 Text(
                  'RECENT MOVEMENT LOG',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                ),
                const SizedBox(height: 10),
                if (productMovements.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('No recent stock movements recorded.'),
                    ),
                  )
                else
                  ...productMovements.take(5).map((m) {
                    final isAdd = m.quantity > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAdd ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isAdd ? AppStatusColors.of(context).success : Theme.of(context).colorScheme.error,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.referenceNumber.isNotEmpty ? m.referenceNumber : m.type.label,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  m.timestamp.toString().substring(0, 16),
                                  style:  TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isAdd ? '+' : ''}${m.quantity}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isAdd ? AppStatusColors.of(context).success : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sublabel,
    required bool highlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? Theme.of(context).colorScheme.errorContainer.withAlpha(80) : Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? Theme.of(context).colorScheme.error.withAlpha(120) : Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: highlight ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: highlight ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 10,
              color: highlight ? Theme.of(context).colorScheme.error.withAlpha(200) : Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
