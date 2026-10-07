import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show SqliteException;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/app_database.dart';

class ProductsSyncService {
  ProductsSyncService(this._db, this._supabase);

  final AppDatabase _db;
  final SupabaseClient _supabase;

  Future<void> downloadProducts({required String shopId}) async {
    final categoryNames = <String, String>{};
    final legacyCategoryNames = <String, String>{};
    for (var offset = 0; ; offset += 1000) {
      final rows = await _supabase
          .from('categories')
          .select('id,name')
          .eq('shop_id', shopId)
          .order('id')
          .range(offset, offset + 999);
      for (final row in rows) {
        final name = row['name'] as String;
        categoryNames[row['id'] as String] = name;
        legacyCategoryNames[name.toLowerCase()] = name;
        await _db.upsertCategory(
          CategoriesTableCompanion.insert(id: name, name: name),
        );
      }
      if (rows.length < 1000) break;
    }

    for (var offset = 0; ; offset += 1000) {
      final rows = await _supabase
          .from('products')
          .select()
          .eq('shop_id', shopId)
          .order('id')
          .range(offset, offset + 999);
      for (final row in rows) {
        final categoryId = row['category_id'] as String?;
        final categoryName = categoryId == null
            ? null
            : categoryNames[categoryId] ??
                  legacyCategoryNames[categoryId.toLowerCase()];
        final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
        final updatedAt = DateTime.tryParse(row['updated_at'] as String? ?? '');
        final product = ProductsTableCompanion.insert(
          id: row['id'] as String,
          name: row['name'] as String,
          sku: row['sku'] as String,
          costPrice: (row['cost_price'] as num).toDouble(),
          sellingPrice: (row['selling_price'] as num).toDouble(),
          description: Value(row['description'] as String?),
          categoryId: Value(categoryName),
          brand: Value((row['brand'] as String?) ?? ''),
          currentStock: Value((row['current_stock'] as int?) ?? 0),
          minStock: Value((row['min_stock'] as int?) ?? 0),
          shelfLocation: Value((row['shelf_location'] as String?) ?? ''),
          imageUrl: Value(_localImageReference(row['image_url'] as String?)),
          barcode: Value(row['barcode'] as String?),
          supplierName: Value((row['supplier_name'] as String?) ?? ''),
          isDeleted: Value((row['is_deleted'] as bool?) ?? false),
          createdAt: Value(createdAt ?? DateTime.now()),
          updatedAt: Value(updatedAt ?? DateTime.now()),
        );
        await _upsertDownloadedProduct(product);
      }
      if (rows.length < 1000) break;
    }
  }

  Future<void> refreshStockSnapshots({required String shopId}) async {
    for (var offset = 0; ; offset += 1000) {
      final rows = await _supabase
          .from('products')
          .select('id,current_stock')
          .eq('shop_id', shopId)
          .order('id')
          .range(offset, offset + 999);
      await _db.updateStockSnapshots({
        for (final row in rows)
          row['id'] as String: (row['current_stock'] as int?) ?? 0,
      });
      if (rows.length < 1000) break;
    }
  }

  Future<void> _upsertDownloadedProduct(ProductsTableCompanion product) async {
    try {
      await _db.upsertProduct(product);
    } catch (error) {
      final sqliteError = _findSqliteException(error);
      if (product.categoryId.value == null ||
          sqliteError?.resultCode != 19 ||
          sqliteError?.message.contains('FOREIGN KEY constraint failed') !=
              true) {
        rethrow;
      }
      await _db.upsertProduct(product.copyWith(categoryId: const Value(null)));
    }
  }

  Future<void> uploadProductPayload(
    Map<String, dynamic> payload, {
    required String shopId,
  }) async {
    final data = Map<String, dynamic>.from(payload)..['shop_id'] = shopId;
    data.remove('previous_image_url');
    final categoryName = data.remove('category_name') as String?;
    final imageUrl = data['image_url'] as String?;
    if (imageUrl?.startsWith('supabase://') ?? false) {
      data['image_url'] = imageUrl!.substring('supabase://'.length);
    }
    if (categoryName != null && categoryName.isNotEmpty) {
      data['category_id'] = await _upsertRemoteCategory(
        categoryName,
        shopId: shopId,
      );
    } else {
      data['category_id'] = null;
    }
    await _supabase.from('products').upsert(data, onConflict: 'id');
  }

  Future<void> uploadCategoryPayload(
    Map<String, dynamic> payload, {
    required String shopId,
  }) async {
    final name = (payload['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name cannot be empty.');
    }
    await _upsertRemoteCategory(name, shopId: shopId);
  }

  Future<String> _upsertRemoteCategory(
    String name, {
    required String shopId,
  }) async {
    final category = await _supabase
        .from('categories')
        .upsert({'name': name, 'shop_id': shopId}, onConflict: 'shop_id,name')
        .select('id')
        .single();
    return category['id'] as String;
  }

  Future<void> deleteProduct({
    required String id,
    required String shopId,
  }) async {
    final archived = await _supabase
        .from('products')
        .update({'is_deleted': true})
        .eq('id', id)
        .eq('shop_id', shopId)
        .select('id');
    if (archived.isEmpty) {
      throw StateError(
        'Product "$id" was not found in the current shop or could not be archived.',
      );
    }
  }

  Future<void> deleteCategory({
    required String name,
    required String shopId,
  }) async {
    final rows = await _supabase
        .from('categories')
        .select('id')
        .eq('name', name)
        .eq('shop_id', shopId)
        .limit(1);
    if (rows.isEmpty) return;

    final categoryId = rows.first['id'] as String;
    await _supabase
        .from('products')
        .update({'category_id': null})
        .eq('category_id', categoryId)
        .eq('shop_id', shopId);
    await _supabase
        .from('categories')
        .delete()
        .eq('id', categoryId)
        .eq('shop_id', shopId);
  }
}

SqliteException? _findSqliteException(Object error) {
  if (error is SqliteException) return error;
  if (error is DriftRemoteException) {
    return _findSqliteException(error.remoteCause);
  }
  return null;
}

String? _localImageReference(String? imageUrl) {
  if (imageUrl == null ||
      imageUrl.startsWith('/') ||
      imageUrl.startsWith('http://') ||
      imageUrl.startsWith('https://') ||
      imageUrl.startsWith('supabase://')) {
    return imageUrl;
  }
  return 'supabase://$imageUrl';
}

final productsSyncServiceProvider = Provider<ProductsSyncService>((ref) {
  return ProductsSyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(supabaseClientProvider),
  );
});
