import 'package:drift/drift.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/database/tables/product_units_table.dart';
import 'package:aeropos/core/database/tables/units_table.dart';
import 'package:aeropos/core/models/product_unit.dart';

part 'product_unit_dao.g.dart';

@DriftAccessor(tables: [ProductUnits, Units])
class ProductUnitDao extends DatabaseAccessor<AppDatabase>
    with _$ProductUnitDaoMixin {
  ProductUnitDao(super.db);

  Future<List<ProductUnit>> getUnitsForProduct(int productId) async {
    final query = select(productUnits).join([
      leftOuterJoin(units, units.id.equalsExp(productUnits.unitId)),
    ])..where(productUnits.productId.equals(productId));

    final results = await query.get();
    return results.map((row) {
      final pu = row.readTable(productUnits);
      final u = row.readTableOrNull(units);
      return ProductUnit(
        id: pu.id,
        productId: pu.productId,
        unitId: pu.unitId,
        conversionFactor: pu.conversionFactor,
        sellingPrice: pu.sellingPrice,
        barcode: pu.barcode,
        isDefault: pu.isDefault,
        unitName: u?.name,
        unitSymbol: u?.symbol,
      );
    }).toList();
  }

  Future<ProductUnit?> getDefaultUnit(int productId) async {
    final query =
        select(productUnits).join([
          leftOuterJoin(units, units.id.equalsExp(productUnits.unitId)),
        ])..where(
          productUnits.productId.equals(productId) &
              productUnits.isDefault.equals(true),
        );

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final pu = row.readTable(productUnits);
    final u = row.readTableOrNull(units);
    return ProductUnit(
      id: pu.id,
      productId: pu.productId,
      unitId: pu.unitId,
      conversionFactor: pu.conversionFactor,
      sellingPrice: pu.sellingPrice,
      barcode: pu.barcode,
      isDefault: pu.isDefault,
      unitName: u?.name,
      unitSymbol: u?.symbol,
    );
  }

  Future<ProductUnit?> getUnitByBarcode(String barcode) async {
    final query = select(productUnits).join([
      leftOuterJoin(units, units.id.equalsExp(productUnits.unitId)),
    ])..where(productUnits.barcode.equals(barcode));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final pu = row.readTable(productUnits);
    final u = row.readTableOrNull(units);
    return ProductUnit(
      id: pu.id,
      productId: pu.productId,
      unitId: pu.unitId,
      conversionFactor: pu.conversionFactor,
      sellingPrice: pu.sellingPrice,
      barcode: pu.barcode,
      isDefault: pu.isDefault,
      unitName: u?.name,
      unitSymbol: u?.symbol,
    );
  }

  Future<double> calculatePrice({
    required int productId,
    required double quantity,
    required ProductUnit unit,
  }) async {
    final qtyInBase = quantity * unit.conversionFactor;

    if (unit.sellingPrice != null) {
      return unit.sellingPrice! * quantity;
    }

    final basePrice = await _getBasePrice(productId);
    if (basePrice != null) {
      return qtyInBase * basePrice;
    }

    return 0.0;
  }

  Future<double?> _getBasePrice(int productId) async {
    final query = select(productUnits)
      ..where((t) => t.productId.equals(productId) & t.sellingPrice.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.conversionFactor)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    if (result == null) return null;

    return result.sellingPrice! / result.conversionFactor;
  }

  Future<int> insertProductUnit(ProductUnitsCompanion entry) async {
    return into(productUnits).insert(entry);
  }

  Future<bool> updateProductUnit(ProductUnitsCompanion entry) async {
    return update(
      productUnits,
    ).replace(entry.toColumns(true) as ProductUnitEntity);
  }

  Future<int> deleteProductUnit(int id) async {
    return (delete(productUnits)..where((t) => t.id.equals(id))).go();
  }
}
