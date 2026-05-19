import 'package:flutter/material.dart';
import 'enums/sync_status.dart';

// Domain model
class CustomerTransaction {
  final String id;
  final String customerId;
  final String customerName;
  final double amount;
  final TransactionType type;
  final String? remarks;
  final DateTime createdAt;
  final SyncStatus syncStatus;

  CustomerTransaction({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.type,
    this.remarks,
    required this.createdAt,
    this.syncStatus = SyncStatus.pending,
  });
}

enum TransactionType {
  credit,
  debit;

  String get displayName => name.toUpperCase();
  Color get color => this == credit ? Colors.green : Colors.red;
}
