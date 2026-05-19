import '../models/supplier_transaction.dart';

abstract class SupplierTransactionRepository {
  Future<List<SupplierTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? supplierId,
    TransactionType? type,
  });

  Future<void> addTransaction(SupplierTransaction transaction);
  Future<void> updateTransaction(SupplierTransaction transaction);
  Future<void> deleteTransaction(String id);
  Future<double> getSupplierBalance(String supplierId);
  Future<void> syncPendingTransactions();
}
