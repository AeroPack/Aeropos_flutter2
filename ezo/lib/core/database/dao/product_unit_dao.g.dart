// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_unit_dao.dart';

// ignore_for_file: type=lint
mixin _$ProductUnitDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProductsTable get products => attachedDatabase.products;
  $UnitsTable get units => attachedDatabase.units;
  $ProductUnitsTable get productUnits => attachedDatabase.productUnits;
  ProductUnitDaoManager get managers => ProductUnitDaoManager(this);
}

class ProductUnitDaoManager {
  final _$ProductUnitDaoMixin _db;
  ProductUnitDaoManager(this._db);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$UnitsTableTableManager get units =>
      $$UnitsTableTableManager(_db.attachedDatabase, _db.units);
  $$ProductUnitsTableTableManager get productUnits =>
      $$ProductUnitsTableTableManager(_db.attachedDatabase, _db.productUnits);
}
