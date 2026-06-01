import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aeropos/core/database/app_database.dart';
import '../services/i_sync_service.dart';
import 'package:uuid/uuid.dart';

class UnitViewModel {
  final AppDatabase _database;
  final ISyncService _syncService;
  final _uuid = const Uuid();

  UnitViewModel(this._database, this._syncService);

  // Expose stream of units from DB
  Stream<List<UnitEntity>> get allUnits => _database.watchAllUnits();

  Future<void> addUnit({required String name, required String symbol}) async {
    final uuid = _uuid.v4();
    final entry = UnitsCompanion(
      uuid: drift.Value(uuid),
      name: drift.Value(name),
      symbol: drift.Value(symbol),
      isActive: const drift.Value(true),
      tenantId: const drift.Value(1),
      syncStatus: const drift.Value(1),
      isDeleted: const drift.Value(false),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    );

    await _database.insertUnit(entry);
    await _syncService.logOperation(
      entity: 'units',
      entityId: uuid,
      opType: 1,
      data: {
        'uuid': uuid,
        'name': name,
        'symbol': symbol,
        'is_active': true,
        'is_deleted': false,
      },
    );
  }

  Future<void> updateUnit(UnitEntity unit) async {
    await _database.updateUnit(unit);
    await _syncService.logOperation(
      entity: 'units',
      entityId: unit.uuid,
      opType: 2,
      data: {
        'uuid': unit.uuid,
        'name': unit.name,
        'symbol': unit.symbol,
        'is_active': unit.isActive,
        'is_deleted': unit.isDeleted,
      },
    );
  }

  Future<void> deleteUnit(int id) async {
    final entity = await (_database.select(_database.units)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await _database.deleteUnit(id);
    if (entity != null) {
      await _syncService.logOperation(
        entity: 'units',
        entityId: entity.uuid,
        opType: 3,
        data: {'uuid': entity.uuid, 'is_deleted': true},
      );
    }
  }

  Future<void> syncPendingUnits() async {
    try {
      await _syncService.push();
    } catch (e) {
      debugPrint('UnitViewModel syncPendingUnits error: $e');
    }
  }

  Future<void> fetchAndSync() async {
    try {
      await _syncService.pull();
    } catch (e) {
      debugPrint('UnitViewModel fetchAndSync error: $e');
    }
  }
}
