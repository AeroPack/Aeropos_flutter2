import 'package:drift/drift.dart';
import 'package:aeropos/core/database/tables/suppliers_table.dart';

@DataClassName('PurchaseReceiptEntity')
class PurchaseReceipts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get invoiceNumber => text()();
  TextColumn get supplierInvoiceNumber => text().nullable()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get tax => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('COMPLETED'))();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get date => dateTime()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get tenantId => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}
