import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/brand.dart';
import '../di/service_locator.dart';
import 'sync_repository.dart';

class BrandRepository {
  final AppDatabase _database;

  BrandRepository(this._database);

  Future<List<Brand>> getAllBrands() async {
    final entities = await (_database.select(
      _database.brands,
    )..where((t) => t.isDeleted.equals(false))).get();
    return entities.map(_mapToDomain).toList();
  }

  Stream<List<Brand>> watchAllBrands() {
    return (_database.select(_database.brands)
          ..where((t) => t.isDeleted.equals(false)))
        .watch()
        .map((entities) => entities.map(_mapToDomain).toList());
  }

  Future<Brand?> getBrandById(int id) async {
    final entity = await (_database.select(
      _database.brands,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return entity != null ? _mapToDomain(entity) : null;
  }

  Future<int> createBrand(Brand brand) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    return await _database.transaction(() async {
      final companion = BrandsCompanion.insert(
        uuid: brand.uuid,
        name: brand.name,
        description: Value(brand.description),
        isActive: Value(brand.isActive),
        tenantId: 1,
        isDeleted: Value(brand.isDeleted),
      );
      final id = await _database.into(_database.brands).insert(companion);
      await syncRepo.logOperation(
        entity: 'brands',
        entityId: brand.uuid,
        opType: SyncOpType.insert,
        data: brand.toJson(),
      );
      return id;
    });
  }

  Future<bool> updateBrand(Brand brand) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    return await _database.transaction(() async {
      final companion = BrandsCompanion(
        id: Value(brand.id),
        uuid: Value(brand.uuid),
        name: Value(brand.name),
        description: Value(brand.description),
        isActive: Value(brand.isActive),
        updatedAt: Value(DateTime.now()),
        isDeleted: Value(brand.isDeleted),
      );
      final success = await _database
          .update(_database.brands)
          .replace(companion);
      if (success) {
        await syncRepo.logOperation(
          entity: 'brands',
          entityId: brand.uuid,
          opType: SyncOpType.update,
          data: brand.toJson(),
        );
      }
      return success;
    });
  }

  Future<int> deleteBrand(int id) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final entity = await (_database.select(
      _database.brands,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entity == null) return 0;

    return await _database.transaction(() async {
      final result =
          await (_database.update(
            _database.brands,
          )..where((t) => t.id.equals(id))).write(
            BrandsCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (result > 0) {
        await syncRepo.logOperation(
          entity: 'brands',
          entityId: entity.uuid,
          opType: SyncOpType.delete,
          data: _mapToDomain(entity).toJson(),
        );
      }
      return result;
    });
  }

  Brand _mapToDomain(BrandEntity entity) {
    return Brand(
      id: entity.id,
      uuid: entity.uuid,
      name: entity.name,
      description: entity.description,
      isActive: entity.isActive,
      isDeleted: entity.isDeleted,
    );
  }
}
