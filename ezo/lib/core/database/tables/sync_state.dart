import 'package:drift/drift.dart';

@DataClassName('SyncStateEntity')
class SyncState extends Table {
  TextColumn get tenantId => text()();
  TextColumn get companyId => text()();
  TextColumn get deviceId => text()();
  IntColumn get lastServerVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {tenantId, companyId, deviceId};
}
