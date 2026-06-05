import 'package:drift/drift.dart';

@DataClassName('ReturnEntity')
class Returns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get originalInvoiceId => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer()();
  RealColumn get refundAmount => real().withDefault(const Constant(0.0))();
  TextColumn get refundMethod => text().withDefault(const Constant('wallet'))();
  TextColumn get notes => text().nullable()();
  IntColumn get newSaleId => integer().nullable()();
  BoolColumn get restock => boolean().withDefault(const Constant(true))();

  IntColumn get companyId => integer()();

  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  TextColumn get transactionId => text()();
  TextColumn get idempotencyKey => text()();
}
