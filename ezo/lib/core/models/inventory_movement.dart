import 'enums/sync_status.dart';

class InventoryMovement {
  final int? id;
  final String uuid;
  final int productId;
  final double quantity;
  final String type;
  final int? referenceId;
  final int? performedBy;
  final DateTime createdAt;
  final int companyId;
  final SyncStatus syncStatus;
  final String transactionId;
  final String idempotencyKey;

  InventoryMovement({
    this.id,
    required this.uuid,
    required this.productId,
    required this.quantity,
    required this.type,
    this.referenceId,
    this.performedBy,
    required this.createdAt,
    required this.companyId,
    this.syncStatus = SyncStatus.synced,
    required this.transactionId,
    required this.idempotencyKey,
  });

  bool get isSale => type == 'SALE';
  bool get isReturn => type == 'RETURN';
  bool get isAdjustment => type == 'ADJUSTMENT';

  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'product_id': productId,
    'quantity': quantity,
    'type': type,
    'reference_id': referenceId,
    'performed_by': performedBy,
    'created_at': createdAt.toIso8601String(),
    'tenant_id': companyId,
    'sync_status': syncStatus.index,
    'transaction_id': transactionId,
    'idempotency_key': idempotencyKey,
  };
}
