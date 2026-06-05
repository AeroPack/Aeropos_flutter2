import 'package:flutter/material.dart';
import 'enums/sync_status.dart';

class SupplierTransaction {
  final String id;
  final String supplierId;
  final String supplierName;
  final String? supplierPhone;
  final double amount;
  final TransactionType type;
  final String? remarks;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final double runningBalance;

  SupplierTransaction({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    this.supplierPhone,
    required this.amount,
    required this.type,
    this.remarks,
    required this.createdAt,
    this.syncStatus = SyncStatus.pending,
    this.runningBalance = 0.0,
  });
}

enum TransactionType {
  credit,
  debit;

  String get displayName => name.toUpperCase();
  Color get color => this == credit ? Colors.green : Colors.red;
}
