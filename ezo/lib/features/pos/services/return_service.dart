import 'package:drift/drift.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/models/invoice_audit_log.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/models/enums/sync_status.dart';
import 'dart:convert' as convert;

class ReturnService {
  final AppDatabase _db = ServiceLocator.instance.database;

  static const String _genesisHash = 'GENESIS';

  String _generateUUID() =>
      '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

  String _generateTransactionId() =>
      'txn_${DateTime.now().millisecondsSinceEpoch}';

  String _generateIdempotencyKey(String transactionId, String suffix) =>
      '${transactionId}_$suffix';

  String _generateHashValue(String previousHash, Map<String, dynamic> changes) {
    final content = previousHash + convert.jsonEncode(changes);
    var hash = 0;
    for (var i = 0; i < content.length; i++) {
      hash = ((hash << 5) - hash) + content.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  Future<InvoiceEntity?> getInvoice(int invoiceId) async {
    return (_db.select(
      _db.invoices,
    )..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
  }

  Future<List<InvoiceItemEntity>> getInvoiceItems(int invoiceId) async {
    return (_db.select(_db.invoiceItems)..where(
          (t) => t.invoiceId.equals(invoiceId) & t.isDeleted.equals(false),
        ))
        .get();
  }

  String _calculateInvoiceStatus(List<InvoiceItemEntity> items) {
    bool allFullyReturned = true;
    bool anyReturned = false;

    for (final item in items) {
      final soldQty = item.quantity.toDouble();
      final returnedQty = item.returnedQuantity;

      if (returnedQty == 0) {
        allFullyReturned = false;
      } else if (returnedQty < soldQty) {
        anyReturned = true;
        allFullyReturned = false;
      }
    }

    if (allFullyReturned) return 'fully_returned';
    if (anyReturned) return 'partially_returned';
    return 'active';
  }

  String calculateInvoiceStatus(int invoiceId, List<InvoiceItemEntity> items) {
    return _calculateInvoiceStatus(items);
  }

  Future<Map<String, dynamic>> getInvoiceWithStatus(int invoiceId) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) return {};

    final items = await getInvoiceItems(invoiceId);
    final status = _calculateInvoiceStatus(items);
    final totalSold = items.fold(0.0, (sum, i) => sum + i.quantity);
    final totalReturned = items.fold(0.0, (sum, i) => sum + i.returnedQuantity);

    return {
      'invoice': invoice,
      'status': status,
      'totalSold': totalSold,
      'totalReturned': totalReturned,
      'itemsSold': items.length,
    };
  }

  double _getRemainingQuantity(InvoiceItemEntity item) {
    return item.quantity.toDouble() - item.returnedQuantity;
  }

  Future<int> processReturn({
    required int invoiceId,
    required int userId,
    required int tenantId,
    required List<ReturnItemRequest> returnItems,
    required String refundMethod,
    String? notes,
    bool restock = true,
  }) async {
    final transactionId = _generateTransactionId();

    return await _db.transaction(() async {
      final invoice = await getInvoice(invoiceId);
      if (invoice == null) {
        throw Exception('Invoice not found');
      }

      if (invoice.isDeleted) {
        throw Exception('Invoice is deleted');
      }

      final allItems = await getInvoiceItems(invoiceId);
      final invoiceStatus = _calculateInvoiceStatus(allItems);
      if (invoiceStatus == 'fully_returned') {
        throw Exception('Invoice is fully returned');
      }

      for (final req in returnItems) {
        final item = await (_db.select(
          _db.invoiceItems,
        )..where((t) => t.id.equals(req.invoiceItemId))).getSingleOrNull();

        if (item == null) {
          throw Exception('Invoice item not found');
        }

        final remainingQty = _getRemainingQuantity(item);
        if (req.quantity > remainingQty) {
          throw Exception(
            'Return quantity (${req.quantity}) exceeds remaining quantity ($remainingQty)',
          );
        }
      }

      double totalRefund = 0;

      final returnIdempotencyKey = _generateIdempotencyKey(
        transactionId,
        'return',
      );

      final existsReturn =
          await (_db.select(_db.returns)
                ..where((t) => t.idempotencyKey.equals(returnIdempotencyKey)))
              .getSingleOrNull();
      if (existsReturn != null) {
        return existsReturn.id;
      }

      final returnId = await _db
          .into(_db.returns)
          .insert(
            ReturnsCompanion.insert(
              uuid: _generateUUID(),
              originalInvoiceId: invoiceId,
              createdBy: userId,
              refundMethod: Value(refundMethod),
              notes: Value(notes),
              restock: Value(restock),
              tenantId: tenantId,
              syncStatus: const Value(1),
              transactionId: transactionId,
              idempotencyKey: returnIdempotencyKey,
            ),
          );

      for (int i = 0; i < returnItems.length; i++) {
        final req = returnItems[i];
        final itemRefund = req.quantity * req.unitPrice;
        totalRefund += itemRefund;

        final itemIdempotencyKey = _generateIdempotencyKey(
          transactionId,
          'item_$i',
        );

        final existsItem =
            await (_db.select(_db.returnItems)
                  ..where((t) => t.idempotencyKey.equals(itemIdempotencyKey)))
                .getSingleOrNull();
        if (existsItem != null) continue;

        await _db
            .into(_db.returnItems)
            .insert(
              ReturnItemsCompanion.insert(
                uuid: _generateUUID(),
                returnId: returnId,
                productId: req.productId,
                quantity: req.quantity,
                unitPrice: req.unitPrice,
                condition: Value(req.condition),
                restock: Value(req.restock),
                originalInvoiceItemId: Value(req.invoiceItemId),
                tenantId: tenantId,
                syncStatus: const Value(1),
                transactionId: transactionId,
                idempotencyKey: itemIdempotencyKey,
              ),
            );

        if (req.restock && req.condition == 'good') {
          final product = await (_db.select(
            _db.products,
          )..where((t) => t.id.equals(req.productId))).getSingleOrNull();

          if (product != null) {
            final stockIdempotencyKey = _generateIdempotencyKey(
              transactionId,
              'stock_$i',
            );

            final existsStock =
                await (_db.select(_db.inventoryMovements)..where(
                      (t) => t.idempotencyKey.equals(stockIdempotencyKey),
                    ))
                    .getSingleOrNull();
            if (existsStock == null) {
              await _db
                  .into(_db.inventoryMovements)
                  .insert(
                    InventoryMovementsCompanion.insert(
                      uuid: _generateUUID(),
                      productId: req.productId,
                      quantity: req.quantity,
                      type: 'RETURN',
                      referenceId: Value(returnId),
                      performedBy: Value(userId),
                      tenantId: tenantId,
                      syncStatus: const Value(1),
                      transactionId: transactionId,
                      idempotencyKey: stockIdempotencyKey,
                    ),
                  );

              final newStock = product.stockQuantity + req.quantity;
              await (_db.update(
                _db.products,
              )..where((t) => t.id.equals(req.productId))).write(
                ProductsCompanion(stockQuantity: Value(newStock.toInt())),
              );
            }
          }
        }
      }

      if (refundMethod == 'wallet' && invoice.customerId != null) {
        final walletIdempotencyKey = _generateIdempotencyKey(
          transactionId,
          'wallet',
        );

        final existsWallet =
            await (_db.select(_db.walletTransactions)
                  ..where((t) => t.idempotencyKey.equals(walletIdempotencyKey)))
                .getSingleOrNull();
        if (existsWallet == null) {
          await _db
              .into(_db.walletTransactions)
              .insert(
                WalletTransactionsCompanion.insert(
                  uuid: _generateUUID(),
                  customerId: invoice.customerId!,
                  amount: totalRefund,
                  type: 'credit',
                  referenceType: 'RETURN',
                  referenceId: Value(returnId),
                  tenantId: tenantId,
                  syncStatus: const Value(1),
                  transactionId: transactionId,
                  idempotencyKey: walletIdempotencyKey,
                ),
              );
        }
      }

      final invoiceItems = await getInvoiceItems(invoiceId);
      for (final item in invoiceItems) {
        final returnItem = returnItems.firstWhere(
          (r) => r.invoiceItemId == item.id,
          orElse: () => ReturnItemRequest(
            productId: item.productId,
            invoiceItemId: item.id,
            quantity: 0,
            unitPrice: item.unitPrice.toDouble(),
          ),
        );

        if (returnItem.quantity > 0) {
          final newReturnedQty = item.returnedQuantity + returnItem.quantity;
          await (_db.update(
            _db.invoiceItems,
          )..where((t) => t.id.equals(item.id))).write(
            InvoiceItemsCompanion(returnedQuantity: Value(newReturnedQty)),
          );
        }
      }

      final newStatus = _calculateInvoiceStatus(
        await getInvoiceItems(invoiceId),
      );
      final currentVersion = invoice.version;
      final newVersion = currentVersion + 1;

      await (_db.update(
        _db.invoices,
      )..where((t) => t.id.equals(invoiceId))).write(
        InvoicesCompanion(
          version: Value(newVersion),
          transactionId: Value(transactionId),
        ),
      );

      final previousLogs =
          await (_db.select(_db.invoiceAuditLogs)
                ..where((t) => t.invoiceId.equals(invoiceId))
                ..orderBy([(t) => OrderingTerm.desc(t.versionNumber)])
                ..limit(1))
              .get();

      final previousLog = previousLogs.isNotEmpty ? previousLogs.first : null;
      final previousHashValue = previousLog?.hash ?? _genesisHash;

      final now = DateTime.now();
      final changes = {
        'status': {'from': invoiceStatus, 'to': newStatus},
        'return_id': returnId,
        'refund_amount': totalRefund,
        'refund_method': refundMethod,
      };

      final newHash = _generateHashValue(previousHashValue, changes);

      final auditIdempotencyKey = _generateIdempotencyKey(
        transactionId,
        'audit',
      );

      final existsAudit =
          await (_db.select(_db.invoiceAuditLogs)
                ..where((t) => t.idempotencyKey.equals(auditIdempotencyKey)))
              .getSingleOrNull();
      if (existsAudit == null) {
        await _db
            .into(_db.invoiceAuditLogs)
            .insert(
              InvoiceAuditLogsCompanion.insert(
                uuid: _generateUUID(),
                invoiceId: invoiceId,
                actionType: 'RETURN',
                performedBy: userId,
                performedAt: Value(now),
                versionNumber: newVersion,
                changes: convert.jsonEncode(changes),
                reason: Value(notes),
                metadata: Value(
                  convert.jsonEncode({
                    'refund_method': refundMethod,
                    'total_refund': totalRefund,
                    'item_count': returnItems.length,
                  }),
                ),
                tenantId: tenantId,
                syncStatus: const Value(1),
                transactionId: transactionId,
                idempotencyKey: auditIdempotencyKey,
                previousHash: previousHashValue,
                hash: newHash,
              ),
            );
      }

      return returnId;
    });
  }

  Future<void> deleteInvoice({
    required int invoiceId,
    required int userId,
    required int tenantId,
    required String reason,
  }) async {
    final transactionId = _generateTransactionId();

    return await _db.transaction(() async {
      final invoice = await getInvoice(invoiceId);
      if (invoice == null) {
        throw Exception('Invoice not found');
      }

      if (invoice.isDeleted) {
        throw Exception('Invoice is already deleted');
      }

      final transactionIdempotencyKey = _generateIdempotencyKey(
        transactionId,
        'delete',
      );

      final existsDelete =
          await (_db.select(_db.invoiceAuditLogs)..where(
                (t) => t.idempotencyKey.equals(transactionIdempotencyKey),
              ))
              .getSingleOrNull();
      if (existsDelete != null) return;

      final now = DateTime.now();
      final currentVersion = invoice.version;
      final newVersion = currentVersion + 1;

      await (_db.update(
        _db.invoices,
      )..where((t) => t.id.equals(invoiceId))).write(
        InvoicesCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          deletedBy: Value(userId),
          deleteReason: Value(reason),
          version: Value(newVersion),
          transactionId: Value(transactionId),
        ),
      );

      final previousLogs =
          await (_db.select(_db.invoiceAuditLogs)
                ..where((t) => t.invoiceId.equals(invoiceId))
                ..orderBy([(t) => OrderingTerm.desc(t.versionNumber)])
                ..limit(1))
              .get();

      final previousLog = previousLogs.isNotEmpty ? previousLogs.first : null;
      final previousHashValue = previousLog?.hash ?? _genesisHash;

      final changes = {'is_deleted': true};
      final newHash = _generateHashValue(previousHashValue, changes);

      await _db
          .into(_db.invoiceAuditLogs)
          .insert(
            InvoiceAuditLogsCompanion.insert(
              uuid: _generateUUID(),
              invoiceId: invoiceId,
              actionType: 'DELETE',
              performedBy: userId,
              performedAt: Value(now),
              versionNumber: newVersion,
              changes: convert.jsonEncode(changes),
              reason: Value(reason),
              tenantId: tenantId,
              syncStatus: const Value(1),
              transactionId: transactionId,
              idempotencyKey: transactionIdempotencyKey,
              previousHash: previousHashValue,
              hash: newHash,
            ),
          );
    });
  }

  Future<List<InvoiceAuditLog>> getAuditHistory(int invoiceId) async {
    final logs =
        await (_db.select(_db.invoiceAuditLogs)
              ..where((t) => t.invoiceId.equals(invoiceId))
              ..orderBy([(t) => OrderingTerm.asc(t.versionNumber)]))
            .get();

    return logs
        .map(
          (log) => InvoiceAuditLog(
            id: log.id,
            uuid: log.uuid,
            invoiceId: log.invoiceId,
            actionType: log.actionType,
            performedBy: log.performedBy,
            performedAt: log.performedAt,
            versionNumber: log.versionNumber,
            changes: convert.jsonDecode(log.changes),
            summarySnapshot: log.summarySnapshot != null
                ? convert.jsonDecode(log.summarySnapshot!)
                : null,
            reason: log.reason,
            metadata: log.metadata != null
                ? convert.jsonDecode(log.metadata!)
                : null,
            tenantId: log.tenantId,
            syncStatus: SyncStatus.values[log.syncStatus],
            transactionId: log.transactionId,
            idempotencyKey: log.idempotencyKey,
            previousHash: log.previousHash,
            hash: log.hash,
          ),
        )
        .toList();
  }
}

class ReturnItemRequest {
  final int productId;
  final int invoiceItemId;
  final double quantity;
  final double unitPrice;
  final String condition;
  final bool restock;

  ReturnItemRequest({
    required this.productId,
    required this.invoiceItemId,
    required this.quantity,
    required this.unitPrice,
    this.condition = 'good',
    this.restock = true,
  });
}
