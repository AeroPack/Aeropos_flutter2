import 'package:drift/drift.dart';

@DataClassName('StockOutboxEntity')
class StockOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get tenantId => text()();
  TextColumn get companyId => text()();
  TextColumn get deviceId => text()();
  TextColumn get productId => text()();
  RealColumn get delta => real()();
  TextColumn get reason => text()();
  TextColumn get refId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
