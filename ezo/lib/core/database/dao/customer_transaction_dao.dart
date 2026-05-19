import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/customer_transactions_table.dart';

part 'customer_transaction_dao.g.dart';

@DriftAccessor(tables: [CustomerTransactions])
class CustomerTransactionDao extends DatabaseAccessor<AppDatabase>
    with _$CustomerTransactionDaoMixin {
  CustomerTransactionDao(super.db);

  // ── Reads ──────────────────────────────────────────────────────────────────

  Future<List<CustomerTransactionEntity>> getAll() =>
      (select(customerTransactions)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<CustomerTransactionEntity>> watchAll() =>
      (select(customerTransactions)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<List<CustomerTransactionEntity>> getByCustomerId(int customerId) =>
      (select(customerTransactions)
            ..where(
              (t) =>
                  t.customerId.equals(customerId) & t.isDeleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<CustomerTransactionEntity>> watchByCustomerId(int customerId) =>
      (select(customerTransactions)
            ..where(
              (t) =>
                  t.customerId.equals(customerId) & t.isDeleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<CustomerTransactionEntity?> getById(int id) => (select(
    customerTransactions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<double> getBalance(int customerId) async {
    final transactions = await getByCustomerId(customerId);
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

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<int> insert(CustomerTransactionsCompanion entry) =>
      into(customerTransactions).insert(entry);

  Future<bool> update_(CustomerTransactionEntity entry) =>
      update(customerTransactions).replace(entry);

  Future<int> softDelete(int id) async {
    final item = await getById(id);
    if (item == null) return 0;
    final updated = item.copyWith(
      isDeleted: true,
      syncStatus: 1,
      updatedAt: DateTime.now(),
    );
    return (await update(customerTransactions).replace(updated)) ? 1 : 0;
  }

  // ── Sync helpers ───────────────────────────────────────────────────────────

  Future<List<CustomerTransactionEntity>> getPendingSync() => (select(
    customerTransactions,
  )..where((t) => t.syncStatus.equals(1))).get();
}
