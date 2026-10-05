import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/app_database.dart';
import '../../../models/supplier.dart';
import '../../sync/data/sync_queue_repository.dart';

// ── Mapper ────────────────────────────────────────────────────────────────────

Supplier _toSupplier(SuppliersTableData row) => Supplier(
      id: row.id,
      name: row.name,
      contactPerson: row.contactPerson,
      phone: row.phone,
      email: row.email,
      city: row.city,
      activeOrders: 0,
      outstandingDues: 0,
      categories: const [],
      leadTimeDays: row.leadTimeDays,
      rating: row.rating,
    );

// ── AsyncNotifier ──────────────────────────────────────────────────────────────

class SuppliersNotifier extends AsyncNotifier<List<Supplier>> {
  late AppDatabase _db;
  String? _userId;

  @override
  Future<List<Supplier>> build() async {
    _db = ref.watch(appDatabaseProvider);
    _userId = ref.watch(authenticatedUserIdProvider);
    final sub = _db.watchAllSuppliers().listen((rows) {
      state = AsyncData(rows.map(_toSupplier).toList());
    });
    ref.onDispose(sub.cancel);
    return _db.watchAllSuppliers().first.then((r) => r.map(_toSupplier).toList());
  }

  Future<void> addSupplier({
    required String name,
    String contactPerson = '',
    String phone = '',
    String email = '',
    String city = '',
    String? gstNumber,
    int leadTimeDays = 0,
    double rating = 0,
  }) async {
    final id = const Uuid().v4();
    final supplier = SuppliersTableCompanion.insert(
      id: id,
      name: name,
      contactPerson: Value(contactPerson),
      phone: Value(phone),
      email: Value(email),
      city: Value(city),
      gstNumber: Value(gstNumber),
      leadTimeDays: Value(leadTimeDays),
      rating: Value(rating),
    );
    await _db.saveSupplier(
      supplier: supplier,
      queuedChange: _userId == null
          ? null
          : createSyncQueueEntry(
              userId: _userId!,
              entityType: 'supplier',
              entityId: id,
              operation: 'upsert',
              payload: {
                'id': id,
                'name': name,
                'contact_person': contactPerson,
                'phone': phone,
                'email': email,
                'city': city,
                'gst_number': gstNumber,
                'lead_time_days': leadTimeDays,
                'rating': rating,
                'is_deleted': false,
              },
            ),
    );
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _db.saveSupplier(
      supplier: SuppliersTableCompanion.insert(
        id: supplier.id,
        name: supplier.name,
        contactPerson: Value(supplier.contactPerson),
        phone: Value(supplier.phone),
        email: Value(supplier.email),
        city: Value(supplier.city),
        leadTimeDays: Value(supplier.leadTimeDays),
        rating: Value(supplier.rating),
      ),
      queuedChange: _userId == null
          ? null
          : createSyncQueueEntry(
              userId: _userId!,
              entityType: 'supplier',
              entityId: supplier.id,
              operation: 'upsert',
              payload: {
                'id': supplier.id,
                'name': supplier.name,
                'contact_person': supplier.contactPerson,
                'phone': supplier.phone,
                'email': supplier.email,
                'city': supplier.city,
                'lead_time_days': supplier.leadTimeDays,
                'rating': supplier.rating,
                'is_deleted': false,
              },
            ),
    );
  }

  /// Soft-deletes a supplier. Business data is never hard-deleted.
  Future<void> deleteSupplier(String id) async {
    await _db.softDeleteSupplier(
      id,
      queuedChange: _userId == null
          ? null
          : createSyncQueueEntry(
              userId: _userId!,
              entityType: 'supplier',
              entityId: id,
              operation: 'delete',
              payload: {'id': id, 'is_deleted': true},
            ),
    );
  }
}

final suppliersProvider =
    AsyncNotifierProvider<SuppliersNotifier, List<Supplier>>(
  SuppliersNotifier.new,
);
