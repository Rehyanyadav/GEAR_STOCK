import 'package:drift/drift.dart';
import 'products_table.dart';
import 'suppliers_table.dart';

/// Allowed movement types — stored as text so they are readable in SQL.
/// Matches the existing domain model [StockMovementType] enum labels.
class StockMovementsTable extends Table {
  @override
  String get tableName => 'stock_movements';

  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(ProductsTable, #id)();
  /// 'IN' or 'OUT' — validated in the repository before insert.
  TextColumn get type => text()();
  IntColumn get quantity => integer()(); // always positive
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get referenceNumber =>
      text().withDefault(const Constant(''))();
  RealColumn get unitPrice => real().withDefault(const Constant(0))();
  TextColumn get operatorName =>
      text().withDefault(const Constant(''))();
  TextColumn get supplierId =>
      text().nullable().references(SuppliersTable, #id)();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
