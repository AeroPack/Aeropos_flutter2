import 'enums/sync_status.dart';

class WalletTransaction {
  final int? id;
  final String uuid;
  final int customerId;
  final double amount;
  final String type;
  final String referenceType;
  final int? referenceId;
  final DateTime createdAt;
  final int companyId;
  final SyncStatus syncStatus;
  final String transactionId;
  final String idempotencyKey;

  WalletTransaction({
    this.id,
    required this.uuid,
    required this.customerId,
    required this.amount,
    required this.type,
    required this.referenceType,
    this.referenceId,
    required this.createdAt,
    required this.companyId,
    this.syncStatus = SyncStatus.synced,
    required this.transactionId,
    required this.idempotencyKey,
  });

  bool get isCredit => type == 'credit';
  bool get isDebit => type == 'debit';

  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'customer_id': customerId,
    'amount': amount,
    'type': type,
    'reference_type': referenceType,
    'reference_id': referenceId,
    'created_at': createdAt.toIso8601String(),
    'tenant_id': companyId,
    'sync_status': syncStatus.index,
    'transaction_id': transactionId,
    'idempotency_key': idempotencyKey,
  };
}
