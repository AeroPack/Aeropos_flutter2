import 'package:drift/drift.dart';

class ReservedSkus extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sku => text().unique()();
  IntColumn get tenantId => integer()();
  BoolColumn get isUsed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get reservedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get usedAt => dateTime().nullable()();
}
