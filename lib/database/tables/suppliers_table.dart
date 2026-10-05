import 'package:drift/drift.dart';

/// Drift table definition for suppliers.
/// Maps 1-to-1 with Supabase `suppliers` table.
class SuppliersTable extends Table {
  @override
  String get tableName => 'suppliers';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get contactPerson =>
      text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get city => text().withDefault(const Constant(''))();
  TextColumn get gstNumber => text().nullable()();
  IntColumn get leadTimeDays =>
      integer().withDefault(const Constant(0))();
  RealColumn get rating => real().withDefault(const Constant(0))();
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
