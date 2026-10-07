import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/app_database.dart';
import '../../sync/data/sync_queue_repository.dart';

// ── AsyncNotifier ──────────────────────────────────────────────────────────────

class CategoriesNotifier extends AsyncNotifier<List<String>> {
  late AppDatabase _db;
  String? _userId;

  static const List<String> defaultCategories = [
    'Brakes',
    'Chains',
    'Tyres & Tubes',
    'Gears & Shifters',
    'Pedals',
    'Cables & Housing',
    'Wheels & Rims',
    'Handlebars & Grips',
    'Saddles & Posts',
    'Lubricants & Care',
    'Accessories',
  ];

  @override
  Future<List<String>> build() async {
    _db = ref.watch(appDatabaseProvider);
    _userId = ref.watch(authenticatedUserIdProvider);

    // Watch live categories from DB
    final sub = _db.watchAllCategories().listen((rows) {
      state = AsyncData(rows.map((r) => r.name).toList());
    });
    ref.onDispose(sub.cancel);

    final initialRows = await _db.watchAllCategories().first;
    if (initialRows.isEmpty) {
      final products = await _db.getAllProducts();
      if (products.isNotEmpty) return const [];

      for (final cat in defaultCategories) {
        await _db.upsertCategory(CategoriesTableCompanion.insert(
          id: cat,
          name: cat,
        ));
      }
      return defaultCategories;
    }

    return initialRows.map((r) => r.name).toList();
  }

  /// Adds a new category if it doesn't already exist.
  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final existing = await _db.watchAllCategories().first;
    if (existing.any((category) => category.name == trimmed)) return;

    await _db.saveCategory(
      category: CategoriesTableCompanion.insert(id: trimmed, name: trimmed),
      queuedChange: _userId == null
          ? null
          : createSyncQueueEntry(
              userId: _userId!,
              entityType: 'category',
              entityId: trimmed,
              operation: 'upsert',
              payload: {'name': trimmed},
            ),
    );
  }

  Future<void> deleteCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await _db.deleteCategory(
      trimmed,
      queuedChange: _userId == null
          ? null
          : createSyncQueueEntry(
              userId: _userId!,
              entityType: 'category',
              entityId: trimmed,
              operation: 'delete',
              payload: {'name': trimmed},
            ),
    );
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<String>>(
  CategoriesNotifier.new,
);
