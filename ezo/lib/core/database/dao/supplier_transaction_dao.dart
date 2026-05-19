import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/supplier_transactions_table.dart';

part 'supplier_transaction_dao.g.dart';

@DriftAccessor(tables: [SupplierTransactions])
class SupplierTransactionDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierTransactionDaoMixin {
  SupplierTransactionDao(super.db);

  Future<List<SupplierTransactionEntity>> getAll() =>
      (select(supplierTransactions)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<SupplierTransactionEntity>> watchAll() =>
      (select(supplierTransactions)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<List<SupplierTransactionEntity>> getBySupplierId(int supplierId) =>
      (select(supplierTransactions)
            ..where(
              (t) =>
                  t.supplierId.equals(supplierId) & t.isDeleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<SupplierTransactionEntity>> watchBySupplierId(int supplierId) =>
      (select(supplierTransactions)
            ..where(
              (t) =>
                  t.supplierId.equals(supplierId) & t.isDeleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<SupplierTransactionEntity?> getById(int id) => (select(
    supplierTransactions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<double> getBalance(int supplierId) async {
    final transactions = await getBySupplierId(supplierId);
    double balance = 0;
    for (final t in transactions) {
      if (t.type == 'credit') {
        balance += t.amount;
      } else {
        balance -= t.amount;
      }
    }
    return balance;
  }

  Future<int> insert(SupplierTransactionsCompanion entry) =>
      into(supplierTransactions).insert(entry);

  Future<bool> update_(SupplierTransactionEntity entry) =>
      update(supplierTransactions).replace(entry);

  Future<int> softDelete(int id) async {
    final item = await getById(id);
    if (item == null) return 0;
    final updated = item.copyWith(
      isDeleted: true,
      syncStatus: 1,
      updatedAt: DateTime.now(),
    );
    return (await update(supplierTransactions).replace(updated)) ? 1 : 0;
  }

  Future<List<SupplierTransactionEntity>> getPendingSync() => (select(
    supplierTransactions,
  )..where((t) => t.syncStatus.equals(1))).get();
}
