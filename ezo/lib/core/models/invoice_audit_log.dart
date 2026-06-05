import 'dart:convert';
import 'enums/sync_status.dart';

class InvoiceAuditLog {
  final int? id;
  final String uuid;
  final int invoiceId;
  final String actionType;
  final int performedBy;
  final DateTime performedAt;
  final int versionNumber;
  final Map<String, dynamic> changes;
  final Map<String, dynamic>? summarySnapshot;
  final String? reason;
  final Map<String, dynamic>? metadata;
  final int companyId;
  final SyncStatus syncStatus;
  final String transactionId;
  final String idempotencyKey;
  final String previousHash;
  final String hash;

  InvoiceAuditLog({
    this.id,
    required this.uuid,
    required this.invoiceId,
    required this.actionType,
    required this.performedBy,
    required this.performedAt,
    required this.versionNumber,
    required this.changes,
    this.summarySnapshot,
    this.reason,
    this.metadata,
    required this.companyId,
    this.syncStatus = SyncStatus.synced,
    required this.transactionId,
    required this.idempotencyKey,
    required this.previousHash,
    required this.hash,
  });

  bool get isReturn => actionType == 'RETURN';
  bool get isExchange => actionType == 'EXCHANGE';
  bool get isDelete => actionType == 'DELETE';
  bool get isNoteUpdate => actionType == 'NOTE_UPDATE';

  String get changesJson => jsonEncode(changes);
  String? get summarySnapshotJson =>
      summarySnapshot != null ? jsonEncode(summarySnapshot) : null;
  String? get metadataJson => metadata != null ? jsonEncode(metadata) : null;

  factory InvoiceAuditLog.fromJson(Map<String, dynamic> json) {
    return InvoiceAuditLog(
      id: json['id'],
      uuid: json['uuid'],
      invoiceId: json['invoice_id'],
      actionType: json['action_type'],
      performedBy: json['performed_by'],
      performedAt: DateTime.parse(json['performed_at']),
      versionNumber: json['version_number'],
      changes: jsonDecode(json['changes']),
      summarySnapshot: json['summary_snapshot'] != null
          ? jsonDecode(json['summary_snapshot'])
          : null,
      reason: json['reason'],
      metadata: json['metadata'] != null ? jsonDecode(json['metadata']) : null,
      companyId: json['tenant_id'],
      syncStatus: SyncStatus.values[json['sync_status'] ?? 0],
      transactionId: json['transaction_id'],
      idempotencyKey: json['idempotency_key'],
      previousHash: json['previous_hash'],
      hash: json['hash'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'invoice_id': invoiceId,
    'action_type': actionType,
    'performed_by': performedBy,
    'performed_at': performedAt.toIso8601String(),
    'version_number': versionNumber,
    'changes': changesJson,
    'summary_snapshot': summarySnapshotJson,
    'reason': reason,
    'metadata': metadataJson,
    'tenant_id': companyId,
    'sync_status': syncStatus.index,
    'transaction_id': transactionId,
    'idempotency_key': idempotencyKey,
    'previous_hash': previousHash,
    'hash': hash,
  };
}
