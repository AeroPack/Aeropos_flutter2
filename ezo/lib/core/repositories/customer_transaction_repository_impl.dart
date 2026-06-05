import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/dao/customer_transaction_dao.dart';
import '../models/customer_transaction.dart';
import '../models/enums/sync_status.dart';
import '../di/service_locator.dart';
import 'customer_transaction_repository.dart';

class CustomerTransactionRepositoryImpl
    implements CustomerTransactionRepository {
  final AppDatabase db;
  final CustomerTransactionDao _dao;

  CustomerTransactionRepositoryImpl(this.db) : _dao = db.customerTransactionDao;

  @override
  Future<List<CustomerTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? customerId,
    TransactionType? type,
  }) async {
    var entities = await _dao.getAll();

    if (customerId != null) {
      entities = entities
          .where((e) => e.customerId.toString() == customerId)
          .toList();
    }

    if (type != null) {
      entities = entities.where((e) => e.type == type.name).toList();
    }

    if (startDate != null) {
      entities = entities
          .where(
            (e) =>
                e.createdAt.isAfter(startDate) ||
                e.createdAt.isAtSameMomentAs(startDate),
          )
          .toList();
    }

    if (endDate != null) {
      entities = entities
          .where(
            (e) => e.createdAt.isBefore(endDate.add(const Duration(days: 1))),
          )
          .toList();
    }

    return Future.wait(entities.map((e) => _mapToDomain(e)));
  }

  @override
  Future<void> addTransaction(CustomerTransaction transaction) async {
    final syncEngine = ServiceLocator.instance.syncEngine;
    final companion = CustomerTransactionsCompanion(
      uuid: Value(transaction.id),
      customerId: Value(int.tryParse(transaction.customerId) ?? 0),
      amount: Value(transaction.amount),
      type: Value(transaction.type.name),
      remarks: Value(transaction.remarks),
      companyId: Value(ServiceLocator.instance.sessionService.companyId),
      syncStatus: Value(SyncStatus.pending.value),
    );
    await _dao.insert(companion);
    await syncEngine.logOperation(
      entity: 'customer_transactions',
      entityId: transaction.id,
      opType: 1,
      data: {
        'customer_id': int.tryParse(transaction.customerId) ?? 0,
        'amount': transaction.amount,
        'type': transaction.type.name,
        'remarks': transaction.remarks,
        'is_deleted': false,
      },
    );
  }

  @override
  Future<void> updateTransaction(CustomerTransaction transaction) async {
    final syncEngine = ServiceLocator.instance.syncEngine;
    final entityId = transaction.id;
    final entity = await _dao.getById(int.tryParse(transaction.id) ?? 0);
    if (entity != null) {
      final updated = entity.copyWith(
        amount: transaction.amount,
        type: transaction.type.name,
        remarks: Value(transaction.remarks),
        syncStatus: SyncStatus.pending.value,
        updatedAt: DateTime.now(),
      );
      await _dao.update_(updated);
      await syncEngine.logOperation(
        entity: 'customer_transactions',
        entityId: entityId,
        opType: 2,
        data: {
          'customer_id': int.tryParse(transaction.customerId) ?? 0,
          'amount': transaction.amount,
          'type': transaction.type.name,
          'remarks': transaction.remarks,
        },
      );
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final syncEngine = ServiceLocator.instance.syncEngine;
    final entity = await _dao.getById(int.tryParse(id) ?? 0);
    await _dao.softDelete(int.tryParse(id) ?? 0);
    if (entity != null) {
      await syncEngine.logOperation(
        entity: 'customer_transactions',
        entityId: entity.uuid,
        opType: 3,
        data: {
          'customer_id': entity.customerId,
          'amount': entity.amount,
          'type': entity.type,
          'remarks': entity.remarks,
          'is_deleted': true,
        },
      );
    }
  }

  @override
  Future<double> getCustomerBalance(String customerId) async {
    return _dao.getBalance(int.tryParse(customerId) ?? 0);
  }

  @override
  Future<void> syncPendingTransactions() async {
    await _dao.getPendingSync();
  }

  Future<CustomerTransaction> _mapToDomain(
    CustomerTransactionEntity entity,
  ) async {
    final customer = await _getCustomerById(entity.customerId);
    return CustomerTransaction(
      id: entity.id.toString(),
      customerId: entity.customerId.toString(),
      customerName: customer?.name ?? 'Unknown',
      amount: entity.amount,
      type: entity.type == 'credit'
          ? TransactionType.credit
          : TransactionType.debit,
      remarks: entity.remarks,
      createdAt: entity.createdAt,
      syncStatus: SyncStatus.fromValue(entity.syncStatus),
    );
  }

  Future<CustomerEntity?> _getCustomerById(int customerId) async {
    final customers = await (db.select(
      db.customers,
    )..where((t) => t.id.equals(customerId) & t.isDeleted.equals(false))).get();
    return customers.isNotEmpty ? customers.first : null;
  }
}
