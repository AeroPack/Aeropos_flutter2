import 'package:drift/drift.dart';
import 'package:aeropos/core/database/app_database.dart';

class UnitConversionService {
  final AppDatabase db;

  UnitConversionService(this.db);

  Future<double> convertToBaseUnit({
    required int productId,
    required double quantity,
    required int fromUnitId,
  }) async {
    if (quantity <= 0) return 0;

    final productUnit =
        await (db.select(db.productUnits)..where(
              (t) =>
                  t.productId.equals(productId) & t.unitId.equals(fromUnitId),
            ))
            .getSingleOrNull();

    if (productUnit != null) {
      return quantity * productUnit.conversionFactor;
    }

    return quantity;
  }

  Future<double> convertFromBaseUnit({
    required int productId,
    required double baseQuantity,
    required int toUnitId,
  }) async {
    if (baseQuantity <= 0) return 0;

    final productUnit =
        await (db.select(db.productUnits)..where(
              (t) => t.productId.equals(productId) & t.unitId.equals(toUnitId),
            ))
            .getSingleOrNull();

    if (productUnit != null && productUnit.conversionFactor > 0) {
      return baseQuantity / productUnit.conversionFactor;
    }

    return baseQuantity;
  }

  Future<int?> getBaseUnitId(int productId) async {
    final product = await (db.select(
      db.products,
    )..where((t) => t.id.equals(productId))).getSingleOrNull();

    return product?.baseUnitId;
  }

  Future<double> calculateSellingPrice({
    required int productId,
    required double quantity,
    required int unitId,
  }) async {
    final productUnit =
        await (db.select(db.productUnits)..where(
              (t) => t.productId.equals(productId) & t.unitId.equals(unitId),
            ))
            .getSingleOrNull();

    if (productUnit == null) {
      final product = await (db.select(
        db.products,
      )..where((t) => t.id.equals(productId))).getSingleOrNull();
      return product?.price ?? 0;
    }

    if (productUnit.sellingPrice != null) {
      return productUnit.sellingPrice! * quantity;
    }

    final basePrice = await _getBasePrice(productId);
    if (basePrice != null) {
      final qtyInBase = quantity * productUnit.conversionFactor;
      return qtyInBase * basePrice;
    }

    return 0;
  }

  Future<double?> _getBasePrice(int productId) async {
    final unitsWithPrice =
        await (db.select(db.productUnits)
              ..where(
                (t) =>
                    t.productId.equals(productId) & t.sellingPrice.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.conversionFactor)])
              ..limit(1))
            .getSingleOrNull();

    if (unitsWithPrice == null) return null;
    return unitsWithPrice.sellingPrice! / unitsWithPrice.conversionFactor;
  }
}
