import 'package:drift/drift.dart';

/// Drift table definition for product categories.
/// Maps 1-to-1 with Supabase `categories` table.
class CategoriesTable extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  @override
  Set<Column> get primaryKey => {id};
}
