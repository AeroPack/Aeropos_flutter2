import 'package:drift/drift.dart';

@DataClassName('InvoiceEntity')
class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get invoiceNumber => text()();
  IntColumn get customerId =>
      integer().nullable()(); // Reference to Customers table id
  DateTimeColumn get date => dateTime()();
  RealColumn get subtotal => real()();
  RealColumn get tax => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
  TextColumn get paymentMethod =>
      text().nullable()(); // e.g. 'cash', 'card', 'upi'
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('PENDING'))();
  TextColumn get signUrl => text().nullable()();

  IntColumn get companyId => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get transactionId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get deletedBy => integer().nullable()();
  TextColumn get deleteReason => text().nullable()();

  // Sync columns
  IntColumn get syncStatus => integer().withDefault(
    const Constant(0),
  )(); // 0: synched, 1: pending, 2: error
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get idempotencyKey => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {invoiceNumber, companyId},
  ];
}
