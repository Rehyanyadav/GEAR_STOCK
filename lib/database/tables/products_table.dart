import 'package:drift/drift.dart';
import 'categories_table.dart';

/// Drift table definition for products.
/// Maps 1-to-1 with Supabase `products` table.
/// - Uses UUID text PKs to stay in sync with Supabase.
/// - [isDeleted] enables soft-delete — never hard-delete business data.
/// - [currentStock] is updated automatically by the SQLite trigger
///   `trg_update_stock` in [AppDatabase].
class ProductsTable extends Table {
  @override
  String get tableName => 'products';

  TextColumn get id => text()();
  TextColumn get sku => text().unique()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get categoryId =>
      text().nullable().references(CategoriesTable, #id)();
  TextColumn get brand => text().withDefault(const Constant(''))();
  RealColumn get costPrice => real()();
  RealColumn get sellingPrice => real()();
  IntColumn get currentStock => integer().withDefault(const Constant(0))();
  IntColumn get minStock => integer().withDefault(const Constant(0))();
  TextColumn get shelfLocation => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get supplierName => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
