import 'package:drift/drift.dart';

@DataClassName('WalletTransactionEntity')
class WalletTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get customerId => integer()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'credit' | 'debit'
  TextColumn get referenceType => text()(); // 'RETURN' | 'SALE'
  IntColumn get referenceId => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get companyId => integer()();

  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  TextColumn get transactionId => text()();
  TextColumn get idempotencyKey => text()();
}
