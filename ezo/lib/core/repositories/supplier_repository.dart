import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/user.dart';
import '../di/service_locator.dart';
import 'sync_repository.dart';

class SupplierRepository {
  final AppDatabase _database;

  SupplierRepository(this._database);

  Future<List<User>> getAllSuppliers() async {
    final entities = await (_database.select(
      _database.suppliers,
    )..where((t) => t.isDeleted.equals(false))).get();
    return entities.map(_mapToDomain).toList();
  }

  Stream<List<User>> watchAllSuppliers() {
    return (_database.select(_database.suppliers)
          ..where((t) => t.isDeleted.equals(false)))
        .watch()
        .map((entities) => entities.map(_mapToDomain).toList());
  }

  Future<User?> getSupplierById(int id) async {
    try {
      final entity = await (_database.select(
        _database.suppliers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return entity != null ? _mapToDomain(entity) : null;
    } catch (e) {
      return null;
    }
  }

  Future<int> createSupplier(User user) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    return await _database.transaction(() async {
      final companion = SuppliersCompanion.insert(
        uuid: user.uuid,
        name: user.name,
        phone: Value(user.phone),
        email: Value(user.email),
        address: Value(user.address),
        tenantId: 1,
        isDeleted: Value(user.isDeleted),
      );
      final id = await _database.into(_database.suppliers).insert(companion);
      await syncRepo.logOperation(
        entity: 'suppliers',
        entityId: user.uuid,
        opType: SyncOpType.insert,
        data: user.toJson(),
      );
      return id;
    });
  }

  Future<bool> updateSupplier(User user) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    return await _database.transaction(() async {
      final companion = SuppliersCompanion(
        id: Value(user.id),
        uuid: Value(user.uuid),
        name: Value(user.name),
        phone: Value(user.phone),
        email: Value(user.email),
        address: Value(user.address),
        tenantId: const Value(1),
        updatedAt: Value(DateTime.now()),
        isDeleted: Value(user.isDeleted),
      );
      final success = await _database
          .update(_database.suppliers)
          .replace(companion);
      if (success) {
        await syncRepo.logOperation(
          entity: 'suppliers',
          entityId: user.uuid,
          opType: SyncOpType.update,
          data: user.toJson(),
        );
      }
      return success;
    });
  }

  Future<int> deleteSupplier(int id) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final entity = await (_database.select(
      _database.suppliers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entity == null) return 0;

    return await _database.transaction(() async {
      final result =
          await (_database.update(
            _database.suppliers,
          )..where((t) => t.id.equals(id))).write(
            SuppliersCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (result > 0) {
        await syncRepo.logOperation(
          entity: 'suppliers',
          entityId: entity.uuid,
          opType: SyncOpType.delete,
          data: _mapToDomain(entity).toJson(),
        );
      }
      return result;
    });
  }

  User _mapToDomain(SupplierEntity entity) {
    return User(
      id: entity.id,
      uuid: entity.uuid,
      name: entity.name,
      phone: entity.phone,
      email: entity.email,
      address: entity.address,
      role: 'supplier',
      creditLimit: 0,
      currentBalance: 0,
      isDeleted: entity.isDeleted,
    );
  }
}
