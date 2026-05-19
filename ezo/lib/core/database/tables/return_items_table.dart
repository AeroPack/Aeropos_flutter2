import 'package:drift/drift.dart';

@DataClassName('ReturnItemEntity')
class ReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get returnId => integer()();
  IntColumn get productId => integer()();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  TextColumn get condition => text().withDefault(const Constant('good'))();
  BoolColumn get restock => boolean().withDefault(const Constant(true))();
  IntColumn get originalInvoiceItemId => integer().nullable()();

  IntColumn get tenantId => integer()();

  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  TextColumn get transactionId => text()();
  TextColumn get idempotencyKey => text()();
}
