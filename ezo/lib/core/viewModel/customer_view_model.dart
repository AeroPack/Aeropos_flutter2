import 'package:flutter/foundation.dart';
import 'package:aeropos/core/database/app_database.dart';
import '../services/i_sync_service.dart';
import '../repositories/customer_repository.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/user.dart';
import '../../core/models/enums/sync_status.dart';

class CustomerViewModel {
  final AppDatabase _database;
  final CustomerRepository _customerRepository;
  final ISyncService _syncService;
  final _uuid = const Uuid();

  CustomerViewModel(
    this._database,
    this._customerRepository,
    this._syncService,
  );

  // Expose stream of customers
  Stream<List<CustomerEntity>> get allCustomers => _database
      .select(_database.customers)
      .watch()
      .map(
        (customers) => customers.where((c) => c.isDeleted == false).toList(),
      );

  Future<CustomerEntity> addCustomer({
    required String name,
    String? phone,
    String? email,
    String? gstin,
    String? address,
    double creditLimit = 0.0,
  }) async {
    final id = await _customerRepository.createCustomer(
      User(
        id: 0,
        uuid: _uuid.v4(),
        name: name,
        phone: phone ?? '',
        email: email ?? '',
        gstin: gstin,
        address: address ?? '',
        role: 'customer',
        creditLimit: creditLimit,
        currentBalance: 0,
      ),
    );

    return await (_database.select(
      _database.customers,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> updateCustomer(CustomerEntity user) async {
    // Mapping entity back to domain User for repo (technical debt: should use Customer model consistently)
    final domainUser = User(
      id: user.id,
      uuid: user.uuid,
      name: user.name,
      phone: user.phone ?? '',
      email: user.email ?? '',
      address: user.address ?? '',
      role: 'customer',
      creditLimit: user.creditLimit,
      currentBalance: user.currentBalance,
      syncStatus: SyncStatus.fromValue(user.syncStatus),
      isDeleted: user.isDeleted,
    );
    await _customerRepository.updateCustomer(domainUser);
  }

  Future<void> deleteCustomer(int id) async {
    await _customerRepository.deleteCustomer(id);
  }

  Future<void> syncPendingCustomers() async {
    try {
      await _syncService.push();
    } catch (e) {
      debugPrint('CustomerViewModel syncPendingCustomers error: $e');
    }
  }

  Future<void> fetchAndSync() async {
    try {
      await _syncService.pull();
    } catch (e) {
      debugPrint('CustomerViewModel fetchAndSync error: $e');
    }
  }
}
