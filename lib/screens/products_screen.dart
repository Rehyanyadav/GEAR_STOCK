import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/categories/data/categories_notifier.dart';
import '../features/products/data/products_notifier.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';
import 'add_edit_product_screen.dart';
import 'barcode_scanner_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name_asc';
  String _selectedCategory = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _applyFilters(List<Product> products) {
    var result = products.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q);
      final matchesCat =
          _selectedCategory == 'all' ||
          p.category.toLowerCase() == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    switch (_sortBy) {
      case 'stock_asc':
        result.sort((a, b) => a.currentStock.compareTo(b.currentStock));
      case 'price_desc':
        result.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
      case 'price_asc':
        result.sort((a, b) => a.sellingPrice.compareTo(b.sellingPrice));
      case 'name_asc':
      default:
        result.sort((a, b) => a.name.compareTo(b.name));
    }
    return result;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Sort Inventory By',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('Stock: Low to High'),
                selected: _sortBy == 'stock_asc',
                onTap: () {
                  setState(() => _sortBy = 'stock_asc');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('Price: High to Low'),
                selected: _sortBy == 'price_desc',
                onTap: () {
                  setState(() => _sortBy = 'price_desc');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('Price: Low to High'),
                selected: _sortBy == 'price_asc',
                onTap: () {
                  setState(() => _sortBy = 'price_asc');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Name: A to Z'),
                selected: _sortBy == 'name_asc',
                onTap: () {
                  setState(() => _sortBy = 'name_asc');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteProduct(Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Delete "${product.name}" and its stock history permanently?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    try {
      await ref.read(productsProvider.notifier).deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${product.name}" deleted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete "${product.name}": $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProducts = ref.watch(productsProvider);
    final asyncCategories = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addProductFab',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Part',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditProductScreen(),
            ),
          );
        },
      ),
      body: asyncProducts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text('Error loading products: $e'),
              TextButton(
                onPressed: () => ref.invalidate(productsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (products) {
          final filtered = _applyFilters(products);
          final categories = [
            {'id': 'all', 'label': 'All'},
            for (final category
                in asyncCategories.valueOrNull ?? const <String>[])
              {'id': category.toLowerCase(), 'label': category},
          ];
          return Column(
            children: [
              // Sticky Search and Filter Header
              Container(
                color: Theme.of(context).colorScheme.surface.withAlpha(245),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    // Search Input with integrated barcode scanner button
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() => _searchQuery = val);
                              },
                              decoration: InputDecoration(
                                hintText: 'Search parts, brand, SKU...',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  size: 20,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.qr_code_scanner,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            tooltip: 'Scan Barcode',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const BarcodeScannerScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Category Chips List
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = _selectedCategory == cat['id'];
                          return ChoiceChip(
                            label: Text(cat['label'] as String),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(
                                () => _selectedCategory = cat['id'] as String,
                              );
                            },
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            side: BorderSide.none,
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Control Strip: Showing count & Sort
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SHOWING ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.secondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${filtered.length} items',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _showSortOptions,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _getSortLabel(_sortBy),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Icon(
                              Icons.expand_more,
                              size: 16,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Products List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No products found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting your search or category filter',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _selectedCategory = 'all';
                                });
                              },
                              child: const Text('Reset Filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          return ProductCard(
                            product: product,
                            onLongPress: () => _confirmDeleteProduct(product),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(
                                    productId: product.id,
                                  ),
                                ),
                              );
                            },
                            onAdjustStock: (delta) {
                              // Stock adjustments go through StockNotifier
                              // to keep an audit trail in stock_movements.
                              // Handled via ProductDetailScreen.
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getSortLabel(String sort) {
    switch (sort) {
      case 'stock_asc':
        return 'Stock: Low to High';
      case 'price_desc':
        return 'Price: High to Low';
      case 'price_asc':
        return 'Price: Low to High';
      case 'name_asc':
      default:
        return 'Name: A to Z';
    }
  }
}
