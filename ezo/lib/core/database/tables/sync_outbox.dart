import 'package:drift/drift.dart';

@DataClassName('SyncOutboxEntity')
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get tenantId => text()();
  TextColumn get companyId => text()();
  TextColumn get deviceId => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  IntColumn get opType => integer()();
  TextColumn get data => text()();
  DateTimeColumn get createdAt => dateTime()();

  // NEW: Retry tracking
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, failed, needs_attention, dead
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
}
