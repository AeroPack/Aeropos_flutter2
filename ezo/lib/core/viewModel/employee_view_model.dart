import 'package:flutter/foundation.dart';
import 'package:aeropos/core/database/app_database.dart';
import '../services/i_sync_service.dart';
import '../repositories/employee_repository.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/user.dart';
import '../../core/models/enums/sync_status.dart';

class EmployeeViewModel {
  final AppDatabase _database;
  final EmployeeRepository _employeeRepository;
  final ISyncService _syncService;
  final _uuid = const Uuid();

  EmployeeViewModel(
    this._database,
    this._employeeRepository,
    this._syncService,
  );

  // Expose stream of employees
  Stream<List<EmployeeEntity>> get allEmployees => _database
      .select(_database.employees)
      .watch()
      .map(
        (employees) => employees.where((e) => e.isDeleted == false).toList(),
      );

  Future<EmployeeEntity> addEmployee({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? role,
    String? password,
    String? authMethod, // 'manual' or 'google'
  }) async {
    // For Google Auth employees the name field is hidden — derive from email prefix
    final effectiveName = name.trim().isNotEmpty
        ? name.trim()
        : (email != null && email.contains('@')
              ? email.split('@')[0]
              : 'Employee');

    final id = await _employeeRepository.createEmployee(
      User(
        id: 0,
        uuid: _uuid.v4(),
        name: effectiveName,
        phone: phone ?? '',
        email: email ?? '',
        address: address ?? '',
        role: role ?? 'employee',
        currentBalance: 0,
        password: password,
      ),
      authMethod: authMethod,
    );

    return await (_database.select(
      _database.employees,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> updateEmployee(EmployeeEntity user) async {
    final domainUser = User(
      id: user.id,
      uuid: user.uuid,
      name: user.name,
      phone: user.phone,
      email: user.email,
      address: user.address,
      role: user.role,
      currentBalance: 0,
      syncStatus: SyncStatus.fromValue(user.syncStatus),
      isDeleted: user.isDeleted,
    );
    await _employeeRepository.updateEmployee(domainUser);
  }

  Future<void> deleteEmployee(int id) async {
    await _employeeRepository.deleteEmployee(id);
  }

  Future<void> syncPendingEmployees() async {
    try {
      await _syncService.push();
    } catch (e) {
      debugPrint('EmployeeViewModel syncPendingEmployees error: $e');
    }
  }

  Future<void> fetchAndSync() async {
    try {
      await _syncService.pull();
    } catch (e) {
      debugPrint('EmployeeViewModel fetchAndSync error: $e');
    }
  }
}
