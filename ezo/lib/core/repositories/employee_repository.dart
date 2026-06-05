import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/user.dart';
import '../di/service_locator.dart';
import 'sync_repository.dart';

class EmployeeRepository {
  final AppDatabase _database;

  EmployeeRepository(this._database);

  Future<List<User>> getAllEmployees() async {
    final entities = await (_database.select(
      _database.employees,
    )..where((t) => t.isDeleted.equals(false))).get();
    return entities.map(_mapToDomain).toList();
  }

  Stream<List<User>> watchAllEmployees() {
    return (_database.select(_database.employees)
          ..where((t) => t.isDeleted.equals(false)))
        .watch()
        .map((entities) => entities.map(_mapToDomain).toList());
  }

  Future<User?> getEmployeeById(int id) async {
    try {
      final entity = await (_database.select(
        _database.employees,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return entity != null ? _mapToDomain(entity) : null;
    } catch (e) {
      return null;
    }
  }

  Future<int> createEmployee(User user, {String? authMethod}) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    return await _database.transaction(() async {
      final companion = EmployeesCompanion.insert(
        uuid: user.uuid,
        name: user.name,
        phone: Value(user.phone),
        email: Value(user.email),
        address: Value(user.address),
        role: Value(user.role),
        password: Value(user.password),
        googleAuth: Value(authMethod == 'google'),
        companyId: ServiceLocator.instance.sessionService.companyId,
        isDeleted: Value(user.isDeleted),
      );
      final id = await _database.into(_database.employees).insert(companion);
      await syncRepo.logOperation(
        entity: 'employees',
        entityId: user.uuid,
        opType: SyncOpType.insert,
        data: user.toJson(),
      );
      return id;
    });
  }

  Future<bool> updateEmployee(User user) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    return await _database.transaction(() async {
      final companion = EmployeesCompanion(
        id: Value(user.id),
        uuid: Value(user.uuid),
        name: Value(user.name),
        phone: Value(user.phone),
        email: Value(user.email),
        address: Value(user.address),
        role: Value(user.role),
        password: Value(user.password),
        updatedAt: Value(DateTime.now()),
        isDeleted: Value(user.isDeleted),
      );
      final success = await _database
          .update(_database.employees)
          .replace(companion);
      if (success) {
        await syncRepo.logOperation(
          entity: 'employees',
          entityId: user.uuid,
          opType: SyncOpType.update,
          data: user.toJson(),
        );
      }
      return success;
    });
  }

  Future<int> deleteEmployee(int id) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final entity = await (_database.select(
      _database.employees,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entity == null) return 0;

    return await _database.transaction(() async {
      final result =
          await (_database.update(
            _database.employees,
          )..where((t) => t.id.equals(id))).write(
            EmployeesCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (result > 0) {
        await syncRepo.logOperation(
          entity: 'employees',
          entityId: entity.uuid,
          opType: SyncOpType.delete,
          data: _mapToDomain(entity).toJson(),
        );
      }
      return result;
    });
  }

  User _mapToDomain(EmployeeEntity entity) {
    return User(
      id: entity.id,
      uuid: entity.uuid,
      name: entity.name,
      phone: entity.phone,
      email: entity.email,
      address: entity.address,
      role: entity.role,
      password: entity.password,
      isDeleted: entity.isDeleted,
    );
  }
}
