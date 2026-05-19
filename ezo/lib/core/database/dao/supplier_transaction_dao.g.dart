// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_transaction_dao.dart';

// ignore_for_file: type=lint
mixin _$SupplierTransactionDaoMixin on DatabaseAccessor<AppDatabase> {
  $SupplierTransactionsTable get supplierTransactions =>
      attachedDatabase.supplierTransactions;
  SupplierTransactionDaoManager get managers =>
      SupplierTransactionDaoManager(this);
}

class SupplierTransactionDaoManager {
  final _$SupplierTransactionDaoMixin _db;
  SupplierTransactionDaoManager(this._db);
  $$SupplierTransactionsTableTableManager get supplierTransactions =>
      $$SupplierTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.supplierTransactions,
      );
}
