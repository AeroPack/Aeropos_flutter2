import 'package:drift/drift.dart';

@DataClassName('SyncErrorEntity')
class SyncErrors extends Table {
  TextColumn get id => text()(); // UUID primary key
  TextColumn get entityType => text()(); // product, customer, supplier, etc.
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // create, update, delete
  TextColumn get payload => text()(); // JSON string
  TextColumn get errorMessage => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, failed, resolved
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
