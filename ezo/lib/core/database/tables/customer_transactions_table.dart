import 'package:drift/drift.dart';

@DataClassName('CustomerTransactionEntity')
class CustomerTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get customerId => integer()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'credit' or 'debit'
  TextColumn get remarks => text().nullable()();
  IntColumn get companyId => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}
