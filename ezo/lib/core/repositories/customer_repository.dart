import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/user.dart';
import '../di/service_locator.dart';
import 'sync_repository.dart';

class CustomerRepository {
  final AppDatabase _database;

  CustomerRepository(this._database);

  Future<List<User>> getAllCustomers() async {
    final entities = await (_database.select(
      _database.customers,
    )..where((t) => t.isDeleted.equals(false))).get();
    return entities.map(_mapToDomain).toList();
  }

  Stream<List<User>> watchAllCustomers() {
    return (_database.select(_database.customers)
          ..where((t) => t.isDeleted.equals(false)))
        .watch()
        .map((entities) => entities.map(_mapToDomain).toList());
  }

  Future<User?> getCustomerById(int id) async {
    try {
      final entity = await (_database.select(
        _database.customers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return entity != null ? _mapToDomain(entity) : null;
    } catch (e) {
      return null;
    }
  }

  Future<int> createCustomer(User user) async {
    final syncRepo = ServiceLocator.instance.syncRepository;

    return await _database.transaction(() async {
      final companion = CustomersCompanion.insert(
        uuid: user.uuid,
        name: user.name,
        phone: Value(user.phone),
        email: Value(user.email),
        gstin: Value(user.gstin),
        address: Value(user.address),
        creditLimit: Value(user.creditLimit),
        currentBalance: Value(user.currentBalance),
        companyId: ServiceLocator.instance.sessionService.companyId,
        isDeleted: Value(user.isDeleted),
      );
      final id = await _database.into(_database.customers).insert(companion);

      await syncRepo.logOperation(
        entity: 'customers',
        entityId: user.uuid,
        opType: SyncOpType.insert,
        data: user.toJson(),
      );

      return id;
    });
  }

  Future<bool> updateCustomer(User user) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final now = DateTime.now();

    return await _database.transaction(() async {
      final companion = CustomersCompanion(
        id: Value(user.id),
        uuid: Value(user.uuid),
        name: Value(user.name),
        phone: Value(user.phone),
        email: Value(user.email),
        gstin: Value(user.gstin),
        address: Value(user.address),
        creditLimit: Value(user.creditLimit),
        currentBalance: Value(user.currentBalance),
        companyId: Value(ServiceLocator.instance.sessionService.companyId),
        updatedAt: Value(now),
        isDeleted: Value(user.isDeleted),
      );
      final success = await _database
          .update(_database.customers)
          .replace(companion);

      if (success) {
        await syncRepo.logOperation(
          entity: 'customers',
          entityId: user.uuid,
          opType: SyncOpType.update,
          data: user.toJson(),
        );
      }

      return success;
    });
  }

  Future<int> deleteCustomer(int id) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final now = DateTime.now();

    final entity = await (_database.select(
      _database.customers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entity == null) return 0;

    return await _database.transaction(() async {
      final result =
          await (_database.update(
            _database.customers,
          )..where((t) => t.id.equals(id))).write(
            CustomersCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(now),
            ),
          );

      if (result > 0) {
        await syncRepo.logOperation(
          entity: 'customers',
          entityId: entity.uuid,
          opType: SyncOpType.delete,
          data: _mapToDomain(entity).toJson(),
        );
      }

      return result;
    });
  }

  User _mapToDomain(CustomerEntity entity) {
    return User(
      id: entity.id,
      uuid: entity.uuid,
      name: entity.name,
      phone: entity.phone,
      email: entity.email,
      gstin: entity.gstin,
      address: entity.address,
      role: 'customer',
      creditLimit: entity.creditLimit,
      currentBalance: entity.currentBalance,
      isDeleted: entity.isDeleted,
    );
  }
}
