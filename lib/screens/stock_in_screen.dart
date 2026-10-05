import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/products/data/products_notifier.dart';
import '../features/stock/data/stock_notifier.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

import '../widgets/gooey_hover_button.dart';
class StockInItem {
  Product product;
  int quantity;
  double unitCost;
  StockInItem({required this.product, required this.quantity, required this.unitCost});
}

class StockInScreen extends ConsumerStatefulWidget {
  /// Optional: pre-selected product (e.g. from barcode scan or low-stock alert).
  final Product? preselectedProduct;

  const StockInScreen({super.key, this.preselectedProduct});

  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  final TextEditingController _invoiceController =
      TextEditingController(text: 'PO-${DateTime.now().year}-${DateTime.now().minute}${DateTime.now().second}');
  final TextEditingController _notesController = TextEditingController();

  final List<StockInItem> _inboundItems = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedProduct != null) {
      _inboundItems.add(StockInItem(
        product: widget.preselectedProduct!,
        quantity: 10,
        unitCost: widget.preselectedProduct!.costPrice,
      ));
    }
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalBillAmount =>
      _inboundItems.fold(0.0, (sum, item) => sum + (item.quantity * item.unitCost));

  int get _totalUnits => _inboundItems.fold(0, (sum, item) => sum + item.quantity);

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
                        'Select Part to Receive',
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
                            return ListTile(
                              leading:  Icon(Icons.build_circle, color: Theme.of(context).colorScheme.primary),
                              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${product.barcode.isNotEmpty ? product.barcode : product.sku} • Current stock: ${product.currentStock}'),
                              trailing: Text('₹${product.costPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              onTap: () {
                                setState(() {
                                  _inboundItems.add(StockInItem(
                                    product: product,
                                    quantity: 1,
                                    unitCost: product.costPrice,
                                  ));
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

  Future<void> _confirmStockIn() async {
    if (_inboundItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item to receive.')),
      );
      return;
    }
    if (_isSubmitting) return; // prevent double-submit
    setState(() => _isSubmitting = true);

    try {
      await ref.read(stockProvider.notifier).addStockInBatch([
        for (final item in _inboundItems)
          StockInEntry(
            productId: item.product.id,
            quantity: item.quantity,
            unitPrice: item.unitCost,
            note: _notesController.text.trim(),
            referenceNumber: _invoiceController.text.trim(),
          ),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Received $_totalUnits units successfully!'),
            backgroundColor: AppStatusColors.of(context).success,
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
          'Receive Stock',
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
                       Text('Total Inbound Value', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary)),
                      Text(
                        '₹${_totalBillAmount.toStringAsFixed(0)}',
                        style:  TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                  Text(
                    '$_totalUnits units in ${_inboundItems.length} lines',
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
                      : const Icon(Icons.archive),
                  label: const Text('Confirm & Log Stock In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: _isSubmitting ? null : _confirmStockIn,
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
            // Supplier & PO Invoice Card
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
                   Text('RECEIPT DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                  const SizedBox(height: 12),

                  const Text('Invoice or reference (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _invoiceController,
                    decoration:  InputDecoration(
                      hintText: 'e.g. INV-001',
                      prefixIcon: Icon(Icons.receipt_long, size: 20, color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Inbound Line Items Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(
                  'RECEIVED PARTS LIST',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                ),
                TextButton.icon(
                  onPressed: () => _showAddProductDialog(products),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add SKU'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Inbound items list
            if (_inboundItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('No parts added to this inbound batch yet.'),
                ),
              )
            else
              ...List.generate(_inboundItems.length, (index) {
                final item = _inboundItems[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
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
                            child:  Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary, size: 24),
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
                                Text(
                                  'SKU: ${item.product.sku} • Bin: ${item.product.shelfLocation}',
                                  style:  TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon:  Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.secondary),
                            onPressed: () {
                              setState(() => _inboundItems.removeAt(index));
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
                                        if (item.quantity > 1) setState(() => item.quantity--);
                                      },
                                    ),
                                    Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 16),
                                      onPressed: () => setState(() => item.quantity++),
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
                                '₹${(item.quantity * item.unitCost).toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '@ ₹${item.unitCost.toStringAsFixed(0)}/ea',
                                style:  TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.secondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 12),

            // Additional Notes
            const Text('Receiving Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Inspected shipment, no seal damage on packaging.',
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
