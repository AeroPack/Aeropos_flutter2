import 'package:drift/drift.dart';

@DataClassName('InventoryMovementEntity')
class InventoryMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get productId => integer()();
  RealColumn get quantity => real()();
  TextColumn get type => text()(); // 'SALE' | 'RETURN' | 'ADJUSTMENT'
  IntColumn get referenceId => integer().nullable()();
  IntColumn get performedBy => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get companyId => integer()();

  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  TextColumn get transactionId => text()();
  TextColumn get idempotencyKey => text()();
}
