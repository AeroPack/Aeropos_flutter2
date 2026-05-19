import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/unit.dart';
import '../di/service_locator.dart';
import 'sync_repository.dart';

class UnitRepository {
  final AppDatabase _database;

  UnitRepository(this._database);

  Future<List<Unit>> getAllUnits() async {
    final entities = await (_database.select(
      _database.units,
    )..where((t) => t.isDeleted.equals(false))).get();
    return entities.map(_mapToDomain).toList();
  }

  Stream<List<Unit>> watchAllUnits() {
    return (_database.select(_database.units)
          ..where((t) => t.isDeleted.equals(false)))
        .watch()
        .map((entities) => entities.map(_mapToDomain).toList());
  }

  Future<Unit?> getUnitById(int id) async {
    try {
      final all = await getAllUnits();
      return all.firstWhere((u) => u.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<int> createUnit(Unit unit) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    return await _database.transaction(() async {
      final companion = UnitsCompanion.insert(
        uuid: unit.uuid,
        name: unit.name,
        symbol: unit.symbol,
        isActive: Value(unit.isActive),
        tenantId: 1,
        isDeleted: Value(unit.isDeleted),
      );
      final id = await _database.into(_database.units).insert(companion);
      await syncRepo.logOperation(
        entity: 'units',
        entityId: unit.uuid,
        opType: SyncOpType.insert,
        data: unit.toJson(),
      );
      return id;
    });
  }

  Future<bool> updateUnit(Unit unit) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    return await _database.transaction(() async {
      final companion = UnitsCompanion(
        id: Value(unit.id),
        uuid: Value(unit.uuid),
        name: Value(unit.name),
        symbol: Value(unit.symbol),
        isActive: Value(unit.isActive),
        updatedAt: Value(DateTime.now()),
        isDeleted: Value(unit.isDeleted),
      );
      final success = await _database
          .update(_database.units)
          .replace(companion);
      if (success) {
        await syncRepo.logOperation(
          entity: 'units',
          entityId: unit.uuid,
          opType: SyncOpType.update,
          data: unit.toJson(),
        );
      }
      return success;
    });
  }

  Future<int> deleteUnit(int id) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final entity = await (_database.select(
      _database.units,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entity == null) return 0;

    return await _database.transaction(() async {
      final result =
          await (_database.update(
            _database.units,
          )..where((t) => t.id.equals(id))).write(
            UnitsCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (result > 0) {
        await syncRepo.logOperation(
          entity: 'units',
          entityId: entity.uuid,
          opType: SyncOpType.delete,
          data: _mapToDomain(entity).toJson(),
        );
      }
      return result;
    });
  }

  Unit _mapToDomain(UnitEntity entity) {
    return Unit(
      id: entity.id,
      uuid: entity.uuid,
      name: entity.name,
      symbol: entity.symbol,
      isActive: entity.isActive,
      isDeleted: entity.isDeleted,
    );
  }
}
