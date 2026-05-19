import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

enum SyncOpType { insert, update, delete }

class SyncRepository {
  final AppDatabase db;
  final String tenantId;
  final String companyId;
  final String deviceId;
  static final _uuid = Uuid();

  SyncRepository({
    required this.db,
    required this.tenantId,
    required this.companyId,
    required this.deviceId,
  });

  String _generateKey() => _uuid.v4();

  Future<int> logOperation({
    required String entity,
    required String entityId,
    required SyncOpType opType,
    Map<String, dynamic>? data,
  }) {
    final dataStr = data != null ? jsonEncode(data) : '{}';
    return db
        .into(db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            idempotencyKey: _generateKey(),
            tenantId: tenantId,
            companyId: companyId,
            deviceId: deviceId,
            entity: entity,
            entityId: entityId,
            opType: opType.index + 1,
            data: dataStr,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<int> logStockDelta({
    required String productId,
    required double delta,
    required String reason,
    String? refId,
  }) {
    final rid = refId ?? '';
    return db
        .into(db.stockOutbox)
        .insert(
          StockOutboxCompanion.insert(
            idempotencyKey: _generateKey(),
            tenantId: tenantId,
            companyId: companyId,
            deviceId: deviceId,
            productId: productId,
            delta: delta,
            reason: reason,
            refId: rid.isEmpty ? const Value.absent() : Value(rid),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<int> pendingCount() {
    final c = db.syncOutbox.id.count();
    final q = db.selectOnly(db.syncOutbox)..addColumns([c]);
    return q.getSingle().then((r) => r.read(c) ?? 0);
  }

  Future<int> pendingStockCount() {
    final c = db.stockOutbox.id.count();
    final q = db.selectOnly(db.stockOutbox)..addColumns([c]);
    return q.getSingle().then((r) => r.read(c) ?? 0);
  }
}
