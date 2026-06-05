import 'package:drift/drift.dart';

@DataClassName('InvoiceAuditLogEntity')
class InvoiceAuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get invoiceId => integer()();
  TextColumn get actionType =>
      text()(); // 'RETURN' | 'EXCHANGE' | 'DELETE' | 'NOTE_UPDATE'
  IntColumn get performedBy => integer()();
  DateTimeColumn get performedAt =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get versionNumber => integer()();

  TextColumn get changes =>
      text()(); // JSON delta: {"total": {"from": 500, "to": 300}}
  TextColumn get summarySnapshot =>
      text().nullable()(); // optional lightweight snapshot
  TextColumn get reason => text().nullable()();
  TextColumn get metadata => text().nullable()(); // JSON

  IntColumn get companyId => integer()();

  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  TextColumn get transactionId => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get previousHash => text()();
  TextColumn get hash => text()();
}
