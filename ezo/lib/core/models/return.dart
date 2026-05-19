import 'enums/sync_status.dart';

class Return {
  final int? id;
  final String uuid;
  final int originalInvoiceId;
  final DateTime createdAt;
  final int createdBy;
  final double refundAmount;
  final String refundMethod;
  final String? notes;
  final int? newSaleId;
  final bool restock;
  final int tenantId;
  final SyncStatus syncStatus;
  final String transactionId;
  final String idempotencyKey;
  final List<ReturnItem> items;

  Return({
    this.id,
    required this.uuid,
    required this.originalInvoiceId,
    required this.createdAt,
    required this.createdBy,
    this.refundAmount = 0.0,
    this.refundMethod = 'wallet',
    this.notes,
    this.newSaleId,
    this.restock = true,
    required this.tenantId,
    this.syncStatus = SyncStatus.synced,
    required this.transactionId,
    required this.idempotencyKey,
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'original_invoice_id': originalInvoiceId,
    'created_at': createdAt.toIso8601String(),
    'created_by': createdBy,
    'refund_amount': refundAmount,
    'refund_method': refundMethod,
    'notes': notes,
    'new_sale_id': newSaleId,
    'restock': restock,
    'tenant_id': tenantId,
    'sync_status': syncStatus.index,
    'transaction_id': transactionId,
    'idempotency_key': idempotencyKey,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class ReturnItem {
  final int? id;
  final String uuid;
  final int returnId;
  final int productId;
  final double quantity;
  final double unitPrice;
  final String condition;
  final bool restock;
  final int? originalInvoiceItemId;
  final int tenantId;
  final SyncStatus syncStatus;
  final String transactionId;
  final String idempotencyKey;

  ReturnItem({
    this.id,
    required this.uuid,
    this.returnId = 0,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.condition = 'good',
    this.restock = true,
    this.originalInvoiceItemId,
    required this.tenantId,
    this.syncStatus = SyncStatus.synced,
    required this.transactionId,
    required this.idempotencyKey,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'return_id': returnId,
    'product_id': productId,
    'quantity': quantity,
    'unit_price': unitPrice,
    'condition': condition,
    'restock': restock,
    'original_invoice_item_id': originalInvoiceItemId,
    'tenant_id': tenantId,
    'sync_status': syncStatus.index,
    'transaction_id': transactionId,
    'idempotency_key': idempotencyKey,
  };
}
