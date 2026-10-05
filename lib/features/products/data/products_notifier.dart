import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/app_database.dart';
import '../../sync/data/sync_queue_repository.dart';
import '../../../models/product.dart';

// ── Mapper ────────────────────────────────────────────────────────────────────

/// Converts a Drift [ProductsTableData] row into the domain [Product] model
/// used across the UI layer.
Product _toProduct(ProductsTableData row) => Product(
  id: row.id,
  name: row.name,
  sku: row.sku,
  category: row.categoryId ?? '',
  brand: row.brand,
  costPrice: row.costPrice,
  sellingPrice: row.sellingPrice,
  currentStock: row.currentStock,
  minStock: row.minStock,
  shelfLocation: row.shelfLocation,
  barcode: row.barcode ?? '',
  supplierName: row.supplierName,
  description: row.description ?? '',
  imageUrl: row.imageUrl,
);

// ── AsyncNotifier ──────────────────────────────────────────────────────────────

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  late AppDatabase _db;
  String? _userId;

  @override
  Future<List<Product>> build() async {
    _db = ref.watch(appDatabaseProvider);
    _userId = ref.watch(authenticatedUserIdProvider);
    // Convert stream into a future for initial load, then keep it live.
    final sub = _db.watchAllProducts().listen((rows) {
      state = AsyncData(rows.map(_toProduct).toList());
    });
    ref.onDispose(sub.cancel);
    // Return the first batch synchronously.
    return _db.watchAllProducts().first.then((r) => r.map(_toProduct).toList());
  }

  Future<void> refreshFromDatabase() async {
    final rows = await _db.getAllProducts();
    state = AsyncData(rows.map(_toProduct).toList());
  }

  Future<void> addProduct({
    required String name,
    required String sku,
    required double costPrice,
    required double sellingPrice,
    required int minStock,
    String category = '',
    String brand = '',
    String shelfLocation = '',
    String? imageUrl,
    String? barcode,
    String supplierName = '',
    String description = '',
    int currentStock = 0,
  }) async {
    final catTrimmed = category.trim();
    final id = const Uuid().v4();
    final product = ProductsTableCompanion.insert(
      id: id,
      name: name,
      sku: sku,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      minStock: Value(minStock),
      categoryId: catTrimmed.isNotEmpty ? Value(catTrimmed) : const Value(null),
      brand: Value(brand),
      shelfLocation: Value(shelfLocation),
      imageUrl: Value(imageUrl),
      barcode: Value(barcode),
      supplierName: Value(supplierName),
      description: Value(description),
      currentStock: Value(currentStock),
    );
    await _db.saveProduct(
      product: product,
      category: catTrimmed.isEmpty
          ? null
          : CategoriesTableCompanion.insert(id: catTrimmed, name: catTrimmed),
      queuedChange: _userId == null
          ? null
          : createSyncQueueEntry(
              userId: _userId!,
              entityType: 'product',
              entityId: id,
              operation: 'upsert',
              payload: {
                'id': id,
                'name': name,
                'sku': sku,
                'cost_price': costPrice,
                'selling_price': sellingPrice,
                'current_stock': currentStock,
                'min_stock': minStock,
                'category_name': catTrimmed,
                'brand': brand,
                'shelf_location': shelfLocation,
                'image_url': imageUrl,
                'barcode': barcode,
                'supplier_name': supplierName,
                'description': description,
                'is_deleted': false,
              },
            ),
    );
  }

  Future<void> updateProduct(Product product) async {
    final catTrimmed = product.category.trim();
    final previous = await _db.getProductById(product.id);
    final companion = ProductsTableCompanion.insert(
      id: product.id,
      name: product.name,
      sku: product.sku,
      costPrice: product.costPrice,
      sellingPrice: product.sellingPrice,
      minStock: Value(product.minStock),
      categoryId: catTrimmed.isNotEmpty ? Value(catTrimmed) : const Value(null),
      brand: Value(product.brand),
      shelfLocation: Value(product.shelfLocation),
      imageUrl: Value(product.imageUrl),
      barcode: Value(product.barcode),
      supplierName: Value(product.supplierName),
      description: Value(product.description),
      currentStock: Value(product.currentStock),
    );
    await _db.saveProduct(
      product: companion,
      category: catTrimmed.isEmpty
          ? null
          : CategoriesTableCompanion.insert(id: catTrimmed, name: catTrimmed),
      queuedChange: _userId == null
          ? null
          : createSyncQueueEntry(
              userId: _userId!,
              entityType: 'product',
              entityId: product.id,
              operation: 'upsert',
              payload: {
                'id': product.id,
                'name': product.name,
                'sku': product.sku,
                'cost_price': product.costPrice,
                'selling_price': product.sellingPrice,
                'min_stock': product.minStock,
                'category_name': catTrimmed,
                'brand': product.brand,
                'shelf_location': product.shelfLocation,
                'image_url': product.imageUrl,
                'barcode': product.barcode,
                'supplier_name': product.supplierName,
                'description': product.description,
                'is_deleted': false,
                'previous_image_url': previous?.imageUrl,
              },
            ),
    );
  }

  Future<void> deleteProduct(String id) async {
    final product = await _db.getProductById(id);
    if (product == null) {
      throw StateError('Product "$id" does not exist.');
    }
    final imageUrl = product.imageUrl;
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        !kIsWeb &&
        !imageUrl.startsWith('http://') &&
        !imageUrl.startsWith('https://') &&
        !imageUrl.startsWith('supabase://')) {
      final imageFile = File(imageUrl);
      if (await imageFile.exists()) await imageFile.delete();
    }

    await _db.deleteProduct(
      id,
      queuedChange: _userId == null
          ? null
          : createSyncQueueEntry(
              userId: _userId!,
              entityType: 'product',
              entityId: id,
              operation: 'delete',
              payload: {'id': id},
            ),
    );
  }

  Future<Product?> getById(String id) async {
    final row = await _db.getProductById(id);
    return row != null ? _toProduct(row) : null;
  }

  Future<Product?> getByBarcode(String barcode) async {
    final row = await _db.getProductByBarcode(barcode);
    return row != null ? _toProduct(row) : null;
  }
}

final productsProvider = AsyncNotifierProvider<ProductsNotifier, List<Product>>(
  ProductsNotifier.new,
);
