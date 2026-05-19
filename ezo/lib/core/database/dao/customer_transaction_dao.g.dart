// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_transaction_dao.dart';

// ignore_for_file: type=lint
mixin _$CustomerTransactionDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomerTransactionsTable get customerTransactions =>
      attachedDatabase.customerTransactions;
  CustomerTransactionDaoManager get managers =>
      CustomerTransactionDaoManager(this);
}

class CustomerTransactionDaoManager {
  final _$CustomerTransactionDaoMixin _db;
  CustomerTransactionDaoManager(this._db);
  $$CustomerTransactionsTableTableManager get customerTransactions =>
      $$CustomerTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.customerTransactions,
      );
}
