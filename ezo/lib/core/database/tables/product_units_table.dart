import 'package:drift/drift.dart';

import 'products_table.dart';
import 'units_table.dart';

@DataClassName('ProductUnitEntity')
class ProductUnits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get unitId => integer().references(Units, #id)();
  RealColumn get conversionFactor => real()();
  RealColumn get sellingPrice => real().nullable()();
  TextColumn get barcode => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  IntColumn get tenantId => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {productId, unitId},
  ];
}
