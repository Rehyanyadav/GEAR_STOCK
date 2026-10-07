import 'package:drift/drift.dart';

class SyncCursorsTable extends Table {
  @override
  String get tableName => 'sync_cursors';

  TextColumn get id => text()();
  TextColumn get syncedAt => text()();
  TextColumn get lastId => text()();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
