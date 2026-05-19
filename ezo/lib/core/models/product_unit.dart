class ProductUnit {
  final int id;
  final int productId;
  final int unitId;
  final double conversionFactor;
  final double? sellingPrice;
  final String? barcode;
  final bool isDefault;

  final String? unitName;
  final String? unitSymbol;

  const ProductUnit({
    required this.id,
    required this.productId,
    required this.unitId,
    required this.conversionFactor,
    this.sellingPrice,
    this.barcode,
    this.isDefault = false,
    this.unitName,
    this.unitSymbol,
  });

  ProductUnit copyWith({
    int? id,
    int? productId,
    int? unitId,
    double? conversionFactor,
    double? sellingPrice,
    String? barcode,
    bool? isDefault,
    String? unitName,
    String? unitSymbol,
  }) {
    return ProductUnit(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitId: unitId ?? this.unitId,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      barcode: barcode ?? this.barcode,
      isDefault: isDefault ?? this.isDefault,
      unitName: unitName ?? this.unitName,
      unitSymbol: unitSymbol ?? this.unitSymbol,
    );
  }
}
