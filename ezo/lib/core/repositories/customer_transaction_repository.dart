import '../models/customer_transaction.dart';

abstract class CustomerTransactionRepository {
  Future<List<CustomerTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? customerId,
    TransactionType? type,
  });

  Future<void> addTransaction(CustomerTransaction transaction);
  Future<void> updateTransaction(CustomerTransaction transaction);
  Future<void> deleteTransaction(String id);
  Future<double> getCustomerBalance(String customerId);
  Future<void> syncPendingTransactions();
}
