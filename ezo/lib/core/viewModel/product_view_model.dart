import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import '../services/i_sync_service.dart';
import 'package:uuid/uuid.dart';
import '../repositories/category_repository.dart';
import '../repositories/unit_repository.dart';
import '../repositories/brand_repository.dart';
import '../models/category.dart';
import '../models/unit.dart';
import '../models/brand.dart';
import '../di/service_locator.dart';
import '../../config/app_config.dart';

class ProductViewModel {
  final AppDatabase _database;
  final CategoryRepository _categoryRepository;
  final UnitRepository _unitRepository;
  final BrandRepository _brandRepository;
  // CHANGE: ISyncService instead of SyncService
  final ISyncService _syncService;
  final _uuid = const Uuid();

  ProductViewModel(
    this._database,
    this._categoryRepository,
    this._unitRepository,
    this._brandRepository,
    // CHANGE: ISyncService instead of SyncService
    this._syncService,
  );

  AppDatabase get database => _database;

  Stream<List<ProductEntity>> get allProducts => _database.watchAllProducts();

  Stream<List<drift.TypedResult>> get allProductsWithCategory =>
      _database.watchProductsWithCategory();

  late final Stream<List<Category>> allCategories = _categoryRepository.watchAllCategories();
  late final Stream<List<Unit>> allUnits = _unitRepository.watchAllUnits();
  late final Stream<List<Brand>> allBrands = _brandRepository.watchAllBrands();

  Future<void> addProduct({
    required String name,
    String? sku,
    required double price,
    required double stockQuantity,
    double? cost,
    int? categoryId,
    int? unitId,
    int? brandId,
    String? gstType,
    String? gstRate,
    String? hsn,
    String? description,
    String? localPath,
    String? imageUrl,
    double discount = 0.0,
    bool isPercentDiscount = false,
  }) async {
    final entry = ProductsCompanion(
      uuid: drift.Value(_uuid.v4()),
      name: drift.Value(name),
      sku: sku == null || sku.isEmpty ? const drift.Value(null) : drift.Value(sku),
      price: drift.Value(price),
      stockQuantity: drift.Value(stockQuantity.toInt()),
      cost: drift.Value(cost),
      categoryId: drift.Value(categoryId),
      unitId: drift.Value(unitId),
      brandId: drift.Value(brandId),
      gstType: drift.Value(gstType),
      gstRate: drift.Value(gstRate),
      hsn: drift.Value(hsn),
      description: drift.Value(description),
      localPath: drift.Value(localPath),
      imageUrl: drift.Value(imageUrl),
      discount: drift.Value(discount),
      isPercentDiscount: drift.Value(isPercentDiscount),
      isActive: const drift.Value(true),
      tenantId: const drift.Value(1),
      syncStatus: const drift.Value(1),
      isDeleted: const drift.Value(false),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    );

    final categoryUuid = await _resolveUuidById(_database.categories, categoryId);
    final unitUuid = await _resolveUuidById(_database.units, unitId);
    final brandUuid = await _resolveUuidById(_database.brands, brandId);

    try {
      await _database.transaction(() async {
        await _database.insertProduct(entry);
        await _syncService.logOperation(
          entity: 'products',
          opType: 1,
          entityId: entry.uuid.value,
          data: {
            'uuid': entry.uuid.value,
            'name': name,
            'sku': sku,
            'price': price,
            'stock_quantity': stockQuantity,
            'cost': cost,
            'category_uuid': categoryUuid,
            'unit_uuid': unitUuid,
            'brand_uuid': brandUuid,
            'gst_type': gstType,
            'gst_rate': gstRate,
            'hsn': hsn,
            'description': description,
            'image_url': imageUrl,
            'discount': discount,
            'is_percent_discount': isPercentDiscount,
            'is_active': true,
            'is_deleted': false,
          },
        );
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isSkuUnique(String sku, {int? excludeId}) async {
    final query = _database.select(_database.products)
      ..where((tbl) => tbl.sku.equals(sku))
      ..where((tbl) => tbl.isDeleted.equals(false));
    if (excludeId != null) {
      query.where((tbl) => tbl.id.isNotValue(excludeId));
    }
    final result = await query.getSingleOrNull();
    return result == null;
  }

  Future<bool> isNameUnique(String name, {int? excludeId}) async {
    final normalizedName = name.trim().toLowerCase();
    final results = await _database.customSelect(
      "SELECT * FROM products WHERE LOWER(TRIM(name)) = ?"
      " AND is_deleted = 0"
      "${excludeId != null ? ' AND id != ?' : ''}",
      variables: [
        drift.Variable.withString(normalizedName),
        if (excludeId != null) drift.Variable.withInt(excludeId),
      ],
    ).get();
    return results.isEmpty;
  }

  Future<bool> isHsnUnique(String hsn, {int? excludeId}) async {
    final results = await _database.customSelect(
      "SELECT * FROM products WHERE hsn = ? AND is_deleted = 0"
      "${excludeId != null ? ' AND id != ?' : ''}",
      variables: [
        drift.Variable.withString(hsn),
        if (excludeId != null) drift.Variable.withInt(excludeId),
      ],
    ).get();
    return results.isEmpty;
  }

  Future<void> updateProduct(ProductEntity product) async {
    final categoryUuid = await _resolveUuidById(_database.categories, product.categoryId);
    final unitUuid = await _resolveUuidById(_database.units, product.unitId);
    final brandUuid = await _resolveUuidById(_database.brands, product.brandId);

    await _database.transaction(() async {
      await _database.updateProduct(product);
      await _syncService.logOperation(
        entity: 'products',
        entityId: product.uuid,
        opType: 2,
        data: {
          'uuid': product.uuid,
          'name': product.name,
          'sku': product.sku,
          'price': product.price,
          'stock_quantity': product.stockQuantity,
          'cost': product.cost,
          'category_uuid': categoryUuid,
          'unit_uuid': unitUuid,
          'brand_uuid': brandUuid,
          'gst_type': product.gstType,
          'gst_rate': product.gstRate,
          'description': product.description,
          'image_url': product.imageUrl,
          'discount': product.discount,
          'is_percent_discount': product.isPercentDiscount,
          'is_active': product.isActive,
          'is_deleted': product.isDeleted,
        },
      );
    });
  }

  Future<String?> _resolveUuidById(dynamic table, int? localId) async {
    if (localId == null) return null;
    final row = await (_database.select(table)
          ..where((t) => (t as dynamic).id.equals(localId)))
        .getSingleOrNull();
    return (row as dynamic)?.uuid as String?;
  }

  Future<void> deleteProduct(int id) async {
    await _database.transaction(() async {
      final entity = await (_database.select(_database.products)
        ..where((t) => t.id.equals(id))).getSingleOrNull();
      await _database.deleteProduct(id);
      if (entity != null) {
        await _syncService.logOperation(
          entity: 'products',
          entityId: entity.uuid,
          opType: 3,
          data: {'uuid': entity.uuid, 'is_deleted': true},
        );
      }
    });
  }

  Future<void> syncPendingProducts() async {
    try {
      await _syncService.push();
      await syncPendingImages();
    } catch (e) {
      debugPrint('ProductViewModel syncPendingProducts error: $e');
    }
  }

  Future<void> uploadProductImage(String uuid, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return;

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          localPath,
          filename: localPath.split('/').last,
        ),
      });

      final response = await ServiceLocator.instance.dio.post(
        '/api/products/$uuid/image',
        data: formData,
      );

      if (response.statusCode == 200) {
        final rawUrl = response.data['imageUrl'] as String?;
        if (rawUrl != null) {
          final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
          final fullUrl = rawUrl.startsWith('http') ? rawUrl : '$base$rawUrl';
          await (_database.update(_database.products)
                ..where((t) => t.uuid.equals(uuid)))
              .write(ProductsCompanion(
            imageUrl: drift.Value(fullUrl),
            localPath: const drift.Value(null),
            updatedAt: drift.Value(DateTime.now()),
          ));
        }
      }
    } catch (e) {
      debugPrint('ProductViewModel uploadProductImage error: $e');
    }
  }

  Future<void> syncPendingImages() async {
    final pending = await (_database.select(_database.products)
          ..where((t) => t.localPath.isNotNull())
          ..where((t) => t.isDeleted.equals(false)))
        .get();

    for (final product in pending) {
      if (product.localPath != null) {
        await uploadProductImage(product.uuid, product.localPath!);
      }
    }
  }

  Future<void> fetchAndSync() async {
    try {
      await _syncService.pull();
    } catch (e) {
      debugPrint('ProductViewModel fetchAndSync error: $e');
    }
  }

  Future<void> saveProductUnit(ProductUnitsCompanion unit) async {
    await _database.into(_database.productUnits).insert(unit);
  }

  Future<void> updateProductUnit(ProductUnitsCompanion unit) async {
    await (_database.update(
      _database.productUnits,
    )..where((t) => t.id.equals(unit.id.value))).write(unit);
  }

  Future<List<ProductUnitEntity>> getProductUnits(int productId) async {
    return await (_database.select(
      _database.productUnits,
    )..where((t) => t.productId.equals(productId))).get();
  }

  Future<void> deleteProductUnits(int productId) async {
    await (_database.delete(
      _database.productUnits,
    )..where((t) => t.productId.equals(productId))).go();
  }

  Future<void> deleteProductUnit(int id) async {
    await (_database.delete(
      _database.productUnits,
    )..where((t) => t.id.equals(id))).go();
  }
}
