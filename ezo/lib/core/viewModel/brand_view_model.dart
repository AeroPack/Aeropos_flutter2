import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aeropos/core/database/app_database.dart';
import '../services/i_sync_service.dart';
import '../di/service_locator.dart';
import 'package:uuid/uuid.dart';

class BrandViewModel {
  final AppDatabase _database;
  final ISyncService _syncService;
  final _uuid = const Uuid();

  BrandViewModel(this._database, this._syncService);

  // Expose stream of brands from DB
  Stream<List<BrandEntity>> get allBrands => _database.watchAllBrands();

  Future<void> addBrand({required String name, String? description}) async {
    final uuid = _uuid.v4();
    final entry = BrandsCompanion(
      uuid: drift.Value(uuid),
      name: drift.Value(name),
      description: drift.Value(description),
      isActive: const drift.Value(true),
      companyId: drift.Value(ServiceLocator.instance.sessionService.companyId),
      syncStatus: const drift.Value(1),
      isDeleted: const drift.Value(false),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    );

    await _database.insertBrand(entry);
    await _syncService.logOperation(
      entity: 'brands',
      entityId: uuid,
      opType: 1,
      data: {
        'uuid': uuid,
        'name': name,
        'description': description,
        'is_active': true,
        'is_deleted': false,
      },
    );
  }

  Future<void> updateBrand(BrandEntity brand) async {
    await _database.updateBrand(brand);
    await _syncService.logOperation(
      entity: 'brands',
      entityId: brand.uuid,
      opType: 2,
      data: {
        'uuid': brand.uuid,
        'name': brand.name,
        'description': brand.description,
        'is_active': brand.isActive,
        'is_deleted': brand.isDeleted,
      },
    );
  }

  Future<void> deleteBrand(int id) async {
    final entity = await (_database.select(_database.brands)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await _database.deleteBrand(id);
    if (entity != null) {
      await _syncService.logOperation(
        entity: 'brands',
        entityId: entity.uuid,
        opType: 3,
        data: {'uuid': entity.uuid, 'is_deleted': true},
      );
    }
  }

  Future<void> syncPendingBrands() async {
    try {
      await _syncService.push();
    } catch (e) {
      debugPrint('BrandViewModel syncPendingBrands error: $e');
    }
  }

  Future<void> fetchAndSync() async {
    try {
      await _syncService.pull();
    } catch (e) {
      debugPrint('BrandViewModel fetchAndSync error: $e');
    }
  }
}
