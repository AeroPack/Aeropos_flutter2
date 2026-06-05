import 'enums/sync_status.dart';
import 'product_unit.dart';

class Product {
  final int id;
  final String uuid;
  final String name;
  final String? sku;
  final int? categoryId;
  final int? unitId;
  final int? baseUnitId;
  final bool allowLooseSale;
  final String? type;
  final String? packSize;
  final double price;
  final double? cost;
  final int stockQuantity;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final bool isDeleted;
  final String? imageUrl;
  final String? localPath;
  final int? brandId;
  final String? description;

  final String? gstType;
  final String? gstRate;
  final String? hsn;
  final double discount;
  final bool isPercentDiscount;
  final int? companyId;
  final List<ProductUnit> availableUnits;

  Product({
    required this.id,
    required this.uuid,
    required this.name,
    this.sku,
    this.categoryId,
    this.unitId,
    this.baseUnitId,
    this.allowLooseSale = true,
    this.type,
    this.packSize,
    required this.price,
    this.cost,
    this.stockQuantity = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.synced,
    this.isDeleted = false,
    this.imageUrl,
    this.localPath,
    this.brandId,
    this.description,
    this.gstType,
    this.gstRate,
    this.hsn,
    this.discount = 0.0,
    this.isPercentDiscount = false,
    this.companyId,
    this.availableUnits = const [],
  });

  Product copyWith({
    int? id,
    String? uuid,
    String? name,
    String? sku,
    int? categoryId,
    int? unitId,
    int? baseUnitId,
    bool? allowLooseSale,
    String? type,
    String? packSize,
    double? price,
    double? cost,
    int? stockQuantity,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    bool? isDeleted,
    String? imageUrl,
    String? localPath,
    int? brandId,
    String? description,
    String? gstType,
    String? gstRate,
    String? hsn,
    double? discount,
    bool? isPercentDiscount,
    int? companyId,
    List<ProductUnit>? availableUnits,
  }) {
    return Product(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      categoryId: categoryId ?? this.categoryId,
      unitId: unitId ?? this.unitId,
      baseUnitId: baseUnitId ?? this.baseUnitId,
      allowLooseSale: allowLooseSale ?? this.allowLooseSale,
      type: type ?? this.type,
      packSize: packSize ?? this.packSize,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      imageUrl: imageUrl ?? this.imageUrl,
      localPath: localPath ?? this.localPath,
      brandId: brandId ?? this.brandId,
      description: description ?? this.description,
      gstType: gstType ?? this.gstType,
      gstRate: gstRate ?? this.gstRate,
      hsn: hsn ?? this.hsn,
      discount: discount ?? this.discount,
      isPercentDiscount: isPercentDiscount ?? this.isPercentDiscount,
      companyId: companyId ?? this.companyId,
      availableUnits: availableUnits ?? this.availableUnits,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'name': name,
    'sku': sku,
    'category_id': categoryId,
    'unit_id': unitId,
    'base_unit_id': baseUnitId,
    'allow_loose_sale': allowLooseSale,
    'type': type,
    'pack_size': packSize,
    'price': price,
    'cost': cost,
    'stock_quantity': stockQuantity,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_deleted': isDeleted,
    'image_url': imageUrl,
    'local_path': localPath,
    'brand_id': brandId,
    'description': description,
    'gst_type': gstType,
    'gst_rate': gstRate,
    'hsn': hsn,
    'discount': discount,
    'is_percent_discount': isPercentDiscount,
    'tenant_id': companyId,
  };
}
