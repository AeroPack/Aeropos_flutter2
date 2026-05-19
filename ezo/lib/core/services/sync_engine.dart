import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../config/app_config.dart';
import '../di/service_locator.dart';
import 'i_sync_service.dart';
import 'sse_client.dart';

const int MAX_BATCH_SIZE = 500;
const int COMPRESSION_THRESHOLD = 10240;
const Duration SYNC_INTERVAL = Duration(seconds: 10);
const int MAX_RETRY_ATTEMPTS = 3;
const Duration BASE_RETRY_DELAY = Duration(seconds: 2);

void _log(String event, Map<String, dynamic> fields) {
  final fieldsStr = fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
  print('SYNC_$event $fieldsStr');
}

class SyncOpType {
  static const int insert = 1;
  static const int update = 2;
  static const int delete = 3;
}

class SyncEngineResult {
  final bool success;
  final int pushed;
  final int acked;
  final int rejected;
  final int pulled;
  final List<String> errors;

  SyncEngineResult({
    required this.success,
    this.pushed = 0,
    this.acked = 0,
    this.rejected = 0,
    this.pulled = 0,
    this.errors = const [],
  });
}

// CHANGE: implements ISyncService so ViewModels that type-hint
// ISyncService (or SyncService) can receive a SyncEngine instead.
class SyncEngine implements ISyncService {
  final AppDatabase db;
  final Dio dio;
  // CHANGE: fields are now non-final so reinitialize() can update them
  // after a confirmed login / company switch without rebuilding the whole
  // object (which would invalidate all existing ViewModel references).
  String tenantId;
  String companyId;
  String deviceId;

  final _uuid = const Uuid();
  final _sseClient = SseClient();
  Timer? _syncTimer;
  Timer? _debounceTimer;
  bool _isSyncing = false;
  final _postSyncCallbacks = <Future<void> Function()>[];

  void registerPostSyncCallback(Future<void> Function() callback) {
    _postSyncCallbacks.add(callback);
  }

  void clearPostSyncCallbacks() {
    _postSyncCallbacks.clear();
  }

  SyncEngine({
    required this.db,
    required this.dio,
    required this.tenantId,
    required this.companyId,
    required this.deviceId,
  }) {
    dio.options.baseUrl = AppConfig.apiBaseUrl;
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  // CHANGE: called by ServiceLocator.activateSyncEngine() to update
  // credentials in-place after login, without recreating the object.
  void reinitialize({
    required String tenantId,
    required String companyId,
    required String deviceId,
  }) {
    this.tenantId = tenantId;
    this.companyId = companyId;
    this.deviceId = deviceId;
    // Reset the in-flight flag in case a hot reload interrupted _doSync,
    // leaving _isSyncing stuck at true and blocking all future syncs.
    _isSyncing = false;
    print(
      '[SyncEngine] reinitialized: tenantId=$tenantId companyId=$companyId',
    );
  }

  void startAutoSync({Duration interval = const Duration(seconds: 60)}) {
    _syncTimer?.cancel();
    // 60-second fallback poll fires even when SSE is active (safety net).
    _syncTimer = Timer.periodic(interval, (_) => sync());
    // Initial pull after 2s — lets auth settle before first request.
    Future.delayed(const Duration(seconds: 2), syncNow);
    // Open SSE stream for real-time push notifications.
    _connectSse();
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
    _sseClient.disconnect();
  }

  Future<void> _connectSse() async {
    // dart:io HttpClient is not available on web — rely on the 60s fallback.
    if (kIsWeb) {
      print('[SyncEngine] SSE skipped on web — using polling fallback');
      return;
    }

    final token = await ServiceLocator.instance.secureStorage
        .read(key: 'auth_token')
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    final companyIdStr = await ServiceLocator.instance.secureStorage
        .read(key: 'company_id')
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (token == null || companyIdStr == null) {
      print('[SyncEngine] SSE skipped — no token or company_id in storage');
      return;
    }

    _sseClient.resetForReconnect();

    final url = '${AppConfig.apiBaseUrl}api/sync/events';
    await _sseClient.connect(
      url: url,
      token: token,
      companyId: companyIdStr,
      onEvent: () {
        print('[SyncEngine] SSE ping — pulling now');
        syncNow();
      },
      onLog: (msg) => print(msg),
    );
  }

  // CHANGE: ISyncService.push() — runs a full sync cycle (push+pull).
  // ViewModels that called _syncService.push() get the same behaviour.
  @override
  Future<void> push() async {
    await sync();
  }

  // CHANGE: ISyncService.pull() — runs a full sync cycle so the local DB
  // is up to date. ViewModels that called _syncService.pull() get the same
  // behaviour. If you want a pull-only path (no outbox flush), extract
  // _pullOnce() into its own public method.
  @override
  Future<void> pull() async {
    await sync();
  }

  Future<void> sync() async {
    if (_isSyncing) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () => _doSync());
  }

  /// Bypass the debounce timer and run a full sync immediately.
  /// Use this for post-login initial pulls where data must arrive
  /// before the caller considers the operation complete.
  Future<SyncEngineResult> syncNow() async {
    _debounceTimer?.cancel();
    return _doSync();
  }

  Future<SyncEngineResult> _doSync() async {
    if (_isSyncing) {
      _log('SKIP', {'reason': 'already_syncing', 'device': deviceId});
      return SyncEngineResult(success: false, errors: ['Already syncing']);
    }

    try {
      // 5-second timeout prevents GNOME keyring deadlock on Linux.
      final token = await ServiceLocator.instance.secureStorage
          .read(key: 'auth_token')
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (token == null || token.isEmpty) {
        _log('SKIP', {'reason': 'not_authenticated', 'device': deviceId});
        return SyncEngineResult(success: false, errors: ['Not authenticated']);
      }
    } catch (e) {
      _log('SKIP', {
        'reason': 'not_authenticated',
        'device': deviceId,
        'error': e.toString(),
      });
      return SyncEngineResult(success: false, errors: ['Not authenticated']);
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      _log('SKIP', {'reason': 'offline', 'device': deviceId});
      return SyncEngineResult(success: false, errors: ['Offline']);
    }

    _isSyncing = true;
    _log('START', {'device': deviceId, 'tenant': tenantId});

    try {
      final sw = Stopwatch()..start();
      final result = await _sync();
      sw.stop();

      if (result.pushed > 0 || result.pulled > 0) {
        _log('SYNC', {
          'device': deviceId,
          'pushed': result.pushed,
          'pulled': result.pulled,
          'duration': '${sw.elapsedMilliseconds}ms',
        });
      }

      _log(result.success ? 'DONE' : 'ERROR', {
        'device': deviceId,
        'status': result.success ? 'ok' : 'error',
        if (!result.success) 'errors': result.errors.length,
      });

      if (result.success) {
        for (final cb in _postSyncCallbacks) {
          try { await cb(); } catch (e) { _log('POST_SYNC_CB_ERROR', {'error': e.toString()}); }
        }
      }

      return result;
    } catch (e) {
      _log('ERROR', {'device': deviceId, 'error': e.toString()});
      return SyncEngineResult(success: false, errors: [e.toString()]);
    } finally {
      _isSyncing = false;
    }
  }

  Map<String, dynamic> _mapToApiFormat(Map<String, dynamic> op) {
    String type;
    switch (op['opType'] as int) {
      case 1:
        type = 'INSERT';
        break;
      case 2:
        type = 'UPDATE';
        break;
      case 3:
        type = 'DELETE';
        break;
      default:
        type = 'INSERT';
    }

    String table = op['entity'].toString().toLowerCase();
    if (table == 'invoiceitems') table = 'invoice_items';
    if (table == 'invoicesettings') table = 'invoice_settings';

    String timestamp =
        op['createdAt']?.toString() ?? DateTime.now().toUtc().toIso8601String();
    if (timestamp.isNotEmpty && !timestamp.endsWith('Z')) {
      timestamp = DateTime.parse(timestamp).toUtc().toIso8601String();
    } else if (!timestamp.endsWith('Z') && !timestamp.contains('Z')) {
      timestamp = DateTime.now().toUtc().toIso8601String();
    }

    return {
      'opId': op['idempotencyKey'],
      'type': type,
      'table': table,
      'recordId': op['entityId'],
      'data': op['data'],
      'timestamp': timestamp,
    };
  }

  Future<T> _withRetry<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxAttempts = MAX_RETRY_ATTEMPTS,
    Duration baseDelay = BASE_RETRY_DELAY,
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        _log('RETRY', {
          'op': operationName,
          'attempt': attempts,
          'max': maxAttempts,
          'error': e.toString(),
        });
        if (attempts >= maxAttempts) {
          _log('RETRY_FAILED', {
            'op': operationName,
            'attempts': attempts,
            'error': e.toString(),
          });
          rethrow;
        }
        final delay = baseDelay * (1 << (attempts - 1));
        await Future.delayed(delay);
      }
    }
    throw Exception('Retry logic exhausted for: $operationName');
  }

  Future<SyncEngineResult> _sync() async {
    _log('SYNC_START', {'device': deviceId, 'tenant': tenantId});

    int totalAcked = 0;
    int totalRejected = 0;
    final errors = <String>[];

    final outboxCheck = await _getPendingOutbox(100);
    print('[ENGINE][OUTBOX] ${outboxCheck.length} items in outbox before sync');
    for (final item in outboxCheck.take(5)) {
      print(
        '[ENGINE][OUTBOX] ${item['entity']}:${item['entityId']} '
        'opType=${item['opType']}',
      );
    }

    // Retry stale failed entries before processing pending ones.
    // Entries with retryCount >= 10 are left as 'failed' for manual review.
    await _retryFailedOutbox();

    while (true) {
      final pending = await _getPendingOutbox(MAX_BATCH_SIZE);
      print('[ENGINE][PUSH] Reading from sync_outbox...');
      print('[ENGINE][PUSH] Found ${pending.length} pending operations');
      if (pending.isEmpty) break;

      final mappedOps = pending.map(_mapToApiFormat).toList();
      final body = {'deviceId': deviceId, 'operations': mappedOps};

      try {
        final pushResult = await _withRetry(
          operation: () => _pushBatch(body),
          operationName: 'push',
        );
        totalAcked += (pushResult['acked'] as int?) ?? 0;
        totalRejected += (pushResult['rejected'] as int?) ?? 0;
        print(
          '[ENGINE][PUSH] Sent batch, server acknowledged '
          '${pushResult['acked'] ?? 0} ops, rejected ${pushResult['rejected'] ?? 0}',
        );
      } catch (e) {
        errors.add('Push failed: ${e.toString()}');
      }

      if (pending.length < MAX_BATCH_SIZE) break;
    }

    final lastPulledAt = await _getLastSyncTime();
    Map<String, dynamic> pullResponse;

    try {
      pullResponse = await _withRetry(
        operation: () => _pullOnce(lastPulledAt),
        operationName: 'pull',
      );
    } catch (e) {
      _log('SYNC_FAIL', {'device': deviceId, 'error': e.toString()});
      return SyncEngineResult(
        success: false,
        errors: [...errors, 'Pull failed: ${e.toString()}'],
      );
    }

    if (!pullResponse['success']) {
      return SyncEngineResult(
        success: false,
        errors: (pullResponse['errors'] as List?)?.cast<String>() ?? [],
      );
    }

    final operations =
        (pullResponse['operations'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
    int pulled = 0;

    try {
      for (final op in operations) {
        try {
          print(
            '[ENGINE][PULL_APPLY] ${op['table']}:${op['recordId']} '
            'type=${op['type']}',
          );
          await _applyOperation(op);
          pulled++;
          print(
            '[ENGINE][PULL_APPLY] ✅ ${op['table']}:${op['recordId']} success',
          );
        } catch (e) {
          print(
            '[ENGINE][PULL_APPLY] ❌ ${op['table']}:${op['recordId']} '
            'error=$e',
          );
        }
      }

      // When the response contains FULL_RESYNC_REQUIRED, the handler
      // inside _applyOperation already resets the cursor to epoch 0
      // (via _updateLastSyncTime). Do NOT override it with the
      // server's nextCursor (which is the current server time) —
      // we need the next pull to use epoch 0 so it fetches everything.
      final hasFullResync =
          operations.any((op) => op['type'] == 'FULL_RESYNC_REQUIRED');
      if (!hasFullResync) {
        final nextCursor = pullResponse['nextCursor'] as String?;
        if (nextCursor != null) {
          await _updateLastSyncTime(DateTime.parse(nextCursor));
        }
      }
    } catch (e) {
      errors.add('Apply failed: ${e.toString()}');
    }

    _log('SYNC_DONE', {
      'device': deviceId,
      'acked': totalAcked,
      'rejected': totalRejected,
      'pulled': pulled,
    });

    return SyncEngineResult(
      success: errors.isEmpty,
      pushed: totalAcked + totalRejected,
      acked: totalAcked,
      rejected: totalRejected,
      pulled: pulled,
      errors: errors,
    );
  }

  Future<Map<String, dynamic>> _pushBatch(Map<String, dynamic> body) async {
    try {
      // AuthInterceptor injects Authorization, X-Company-Id, X-Tenant-Id.
      // No manual header reads here — they deadlock GNOME keyring on Linux.
      final response = await dio.post('api/sync', data: body);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        int acked = 0;
        int rejected = 0;

        final acknowledged =
            (data['acknowledged'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        for (final ack in acknowledged) {
          final opId = ack['opId'] as String?;
          final status = ack['status'] as String?;
          final normalized = status?.toLowerCase();
          final error = ack['error'] as Map<String, dynamic>?;

          if ((normalized == 'success' || normalized == 'duplicate') &&
              opId != null) {
            await (db.delete(
              db.syncOutbox,
            )..where((t) => t.idempotencyKey.equals(opId))).go();
            acked++;
          } else if (normalized == 'failed' && opId != null) {
            rejected++;
            await _markOutboxFailed(opId, error?['code'], error?['message']);
          }
        }

        return {'success': true, 'acked': acked, 'rejected': rejected};
      }

      print('[PUSH] non-200 status=${response.statusCode} body=${response.data}');
      return {'success': false, 'acked': 0, 'rejected': 0};
    } on DioException catch (e) {
      print(
        '[PUSH] DioException status=${e.response?.statusCode} '
        'body=${e.response?.data}',
      );
      return {
        'success': false,
        'acked': 0,
        'rejected': 0,
        'error': e.toString(),
      };
    } catch (e) {
      print('[PUSH] unexpected error: $e');
      return {
        'success': false,
        'acked': 0,
        'rejected': 0,
        'error': e.toString(),
      };
    }
  }

  Future<void> _markOutboxFailed(
    String opId,
    String? code,
    String? message,
  ) async {
    final errorMsg = '${code ?? 'UNKNOWN'}: ${message ?? 'Unknown error'}';
    await (db.update(
      db.syncOutbox,
    )..where((t) => t.idempotencyKey.equals(opId))).write(
      SyncOutboxCompanion(
        status: const Value('failed'),
        lastError: Value(errorMsg),
      ),
    );
  }

  /// Dart's toIso8601String() emits 6 decimal places (microseconds).
  /// Node.js silently drops digits past the 3rd, so "12:18:40.160000Z"
  /// is parsed as "12:18:40.000Z" — the cursor never advances.
  /// This method strips microseconds, producing exactly 3 decimal places.
  String _toMillisIso(DateTime dt) {
    return dt.toUtc().toIso8601String().replaceFirst(
      RegExp(r'\.(\d{3})\d+Z$'),
      r'.$1Z',
    );
  }

  Future<Map<String, dynamic>> _pullOnce(DateTime? lastPulledAt) async {
    try {
      final body = {
        'deviceId': deviceId,
        'lastPulledAt':
            lastPulledAt != null
                ? _toMillisIso(lastPulledAt)
                : DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String(),
        'operations': [],
      };

      print('[ENGINE][PULL] Requesting since: ${body['lastPulledAt']}');

      // AuthInterceptor injects Authorization, X-Company-Id, X-Tenant-Id.
      final response = await dio.post('api/sync', data: body);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final operations =
            (data['operations'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        final nextCursor = data['nextCursor'] as String?;

        print(
          '[ENGINE][PULL] Received ${operations.length} operations from server',
        );

        return {
          'success': true,
          'operations': operations,
          'nextCursor': nextCursor,
        };
      }

      return {
        'success': false,
        'operations': [],
        'errors': ['HTTP ${response.statusCode}'],
      };
    } catch (e) {
      return {
        'success': false,
        'operations': [],
        'errors': [e.toString()],
      };
    }
  }

  /// Reset stale failed outbox entries back to pending so they are retried.
  /// Uses exponential backoff: each retry doubles the wait (30s, 1m, 2m, …).
  /// Entries with retryCount >= 10 are left as 'failed' for manual review.
  Future<void> _retryFailedOutbox() async {
    const int maxRetries = 10;
    final now = DateTime.now();

    final staleEntries = await (db.select(db.syncOutbox)
          ..where((t) => t.status.equals('failed'))
          ..where((t) => t.retryCount.isSmallerThan(Constant(maxRetries))))
        .get();

    for (final entry in staleEntries) {
      // If a nextRetryAt is set and it hasn't arrived yet, skip.
      if (entry.nextRetryAt != null && entry.nextRetryAt!.isAfter(now)) {
        continue;
      }

      final nextRetry = Duration(seconds: 30 * (1 << entry.retryCount));
      await (db.update(db.syncOutbox)
            ..where((t) => t.idempotencyKey.equals(entry.idempotencyKey)))
          .write(
        SyncOutboxCompanion(
          status: const Value('pending'),
          retryCount: Value(entry.retryCount + 1),
          nextRetryAt: Value(now.add(nextRetry)),
          lastError: const Value(null),
        ),
      );
      print(
        '[ENGINE][RETRY] ${entry.entity}:${entry.entityId} '
        'retry=${entry.retryCount + 1}/$maxRetries',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingOutbox(int limit) async {
    final rows =
        await (db.select(db.syncOutbox)
              ..where((t) => t.status.equals('pending'))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(limit))
            .get();

    return rows
        .map(
          (row) => {
            'idempotencyKey': row.idempotencyKey,
            'tenantId': row.tenantId,
            'companyId': row.companyId,
            'deviceId': row.deviceId,
            'entity': row.entity,
            'entityId': row.entityId,
            'opType': row.opType,
            'data': jsonDecode(row.data),
            'createdAt': row.createdAt.toIso8601String(),
          },
        )
        .toList();
  }

  Future<DateTime?> _getLastSyncTime() async {
    final state =
        await (db.select(db.syncState)..where(
              (t) =>
                  t.tenantId.equals(tenantId) &
                  t.companyId.equals(companyId) &
                  t.deviceId.equals(deviceId),
            ))
            .getSingleOrNull();
    return state?.lastSyncAt;
  }

  Future<void> _updateLastSyncTime(DateTime time) async {
    await db
        .into(db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion(
            tenantId: Value(tenantId),
            companyId: Value(companyId),
            deviceId: Value(deviceId),
            lastServerVersion: Value(time.millisecondsSinceEpoch),
            lastSyncAt: Value(time),
          ),
        );
  }

  Future<void> _applyOperation(Map<String, dynamic> op) async {
    final entity = op['table'] as String?;
    final recordId = op['recordId'] as String?;
    final operation = op['type'] as String?;
    final data = op['data'] as Map<String, dynamic>?;

    // Server asks for a full re-sync (client cursor is too old).
    if (operation == 'FULL_RESYNC_REQUIRED') {
      print('[SyncEngine] FULL_RESYNC_REQUIRED — clearing local DB');
      await db.clearAllData();
      await _updateLastSyncTime(DateTime.fromMillisecondsSinceEpoch(0));
      return;
    }

    if (entity == null || recordId == null) return;

    if (operation == 'DELETE') {
      await _deleteEntity(entity, recordId);
      return;
    }

    // Skip INSERT/UPDATE ops where the server sent no data payload.
    if (data == null || data.isEmpty) {
      print('[SyncEngine] SKIP $entity:$recordId — empty data payload');
      return;
    }

    await _upsertEntity(entity, recordId, data);
  }

  Future<void> _deleteEntity(String entity, String uuid) async {
    switch (entity) {
      case 'products':
        await (db.delete(db.products)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'categories':
        await (db.delete(
          db.categories,
        )..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'units':
        await (db.delete(db.units)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'brands':
        await (db.delete(db.brands)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'customers':
        await (db.delete(db.customers)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'suppliers':
        await (db.delete(db.suppliers)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'employees':
        await (db.delete(db.employees)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'invoices':
        await (db.delete(db.invoices)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'purchase_receipts':
        await (db.delete(db.purchaseReceipts)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'customer_transactions':
        await (db.delete(db.customerTransactions)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'supplier_transactions':
        await (db.delete(db.supplierTransactions)..where((t) => t.uuid.equals(uuid))).go();
        break;
    }
  }

  Future<void> _upsertEntity(
    String entity,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    switch (entity) {
      case 'products':
        await _upsertProduct(recordId, data);
        break;
      case 'categories':
        await _upsertCategory(recordId, data);
        break;
      case 'units':
        await _upsertUnit(recordId, data);
        break;
      case 'brands':
        await _upsertBrand(recordId, data);
        break;
      case 'customers':
        await _upsertCustomer(recordId, data);
        break;
      case 'suppliers':
        await _upsertSupplier(recordId, data);
        break;
      case 'employees':
        await _upsertEmployee(recordId, data);
        break;
      case 'invoices':
        await _upsertInvoice(recordId, data);
        break;
      case 'purchase_receipts':
        await _upsertPurchaseReceipt(recordId, data);
        break;
      case 'customer_transactions':
        await _upsertCustomerTransaction(recordId, data);
        break;
      case 'supplier_transactions':
        await _upsertSupplierTransaction(recordId, data);
        break;
    }
  }

  // ── FK uuid → local Drift id resolvers ────────────────────────────
  // Backend sends `<table>_uuid` per the sync contract; resolve to local
  // autoincrement ids for Drift FK columns. Returns null if missing.
  Future<int?> _categoryIdForUuid(String? uuid) async {
    if (uuid == null) return null;
    final row = await (db.select(
      db.categories,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    return row?.id;
  }

  Future<int?> _unitIdForUuid(String? uuid) async {
    if (uuid == null) return null;
    final row = await (db.select(
      db.units,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    return row?.id;
  }

  Future<int?> _brandIdForUuid(String? uuid) async {
    if (uuid == null) return null;
    final row = await (db.select(
      db.brands,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    return row?.id;
  }

  Future<int?> _customerIdForUuid(String? uuid) async {
    if (uuid == null) return null;
    final row = await (db.select(
      db.customers,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    return row?.id;
  }

  Future<void> _upsertProduct(String uuid, Map<String, dynamic> data) async {
    final categoryId = await _categoryIdForUuid(data['category_uuid'] as String?);
    final unitId = await _unitIdForUuid(data['unit_uuid'] as String?);
    final brandId = await _brandIdForUuid(data['brand_uuid'] as String?);

    final existing = await (db.select(
      db.products,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.products)..where((t) => t.uuid.equals(uuid))).write(
        ProductsCompanion(
          name: Value(data['name'] as String? ?? ''),
          sku: Value(data['sku'] as String?),
          price: Value((data['price'] as num?)?.toDouble() ?? 0.0),
          cost: Value((data['cost'] as num?)?.toDouble()),
          categoryId: Value(categoryId),
          unitId: Value(unitId),
          brandId: Value(brandId),
          stockQuantity: Value((data['stock_quantity'] as num?)?.toInt() ?? 0),
          isActive: Value(data['is_active'] as bool? ?? true),
          imageUrl: Value(data['image_url'] as String?),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
await db
          .into(db.products)
          .insert(
            ProductsCompanion(
              uuid: Value(uuid),
              name: Value(data['name'] as String? ?? ''),
              sku: Value(data['sku'] as String?),
              price: Value((data['price'] as num?)?.toDouble() ?? 0.0),
              cost: Value((data['cost'] as num?)?.toDouble()),
              categoryId: Value(categoryId),
              unitId: Value(unitId),
              brandId: Value(brandId),
              stockQuantity: Value((data['stock_quantity'] as num?)?.toInt() ?? 0),
              isActive: Value(data['is_active'] as bool? ?? true),
              imageUrl: Value(data['image_url'] as String?),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
      }
    }

  Future<void> _upsertCategory(String uuid, Map<String, dynamic> data) async {
    final name = data['name'] as String?;
    if (name == null || name.isEmpty) {
      print('[SyncEngine] SKIP category:$uuid — missing name field');
      return;
    }
    final existing = await (db.select(
      db.categories,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.categories)..where((t) => t.uuid.equals(uuid))).write(
        CategoriesCompanion(
          name: Value(data['name'] as String? ?? ''),
          subcategory: Value(data['subcategory'] as String?),
          description: Value(data['description'] as String?),
          isActive: Value(data['is_active'] as bool? ?? true),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion(
              uuid: Value(uuid),
              name: Value(data['name'] as String? ?? ''),
              subcategory: Value(data['subcategory'] as String?),
              description: Value(data['description'] as String?),
              isActive: Value(data['is_active'] as bool? ?? true),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    }
  }

  Future<void> _upsertUnit(String uuid, Map<String, dynamic> data) async {
    final existing = await (db.select(
      db.units,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.units)..where((t) => t.uuid.equals(uuid))).write(
        UnitsCompanion(
          name: Value(data['name'] as String? ?? ''),
          symbol: Value(data['symbol'] as String? ?? ''),
          isActive: Value(data['is_active'] as bool? ?? true),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
      await db
          .into(db.units)
          .insert(
            UnitsCompanion(
              uuid: Value(uuid),
              name: Value(data['name'] as String? ?? ''),
              symbol: Value(data['symbol'] as String? ?? ''),
              isActive: Value(data['is_active'] as bool? ?? true),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    }
  }

  Future<void> _upsertBrand(String uuid, Map<String, dynamic> data) async {
    final existing = await (db.select(
      db.brands,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.brands)..where((t) => t.uuid.equals(uuid))).write(
        BrandsCompanion(
          name: Value(data['name'] as String? ?? ''),
          description: Value(data['description'] as String?),
          isActive: Value(data['is_active'] as bool? ?? true),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
      await db
          .into(db.brands)
          .insert(
            BrandsCompanion(
              uuid: Value(uuid),
              name: Value(data['name'] as String? ?? ''),
              description: Value(data['description'] as String?),
              isActive: Value(data['is_active'] as bool? ?? true),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    }
  }

  Future<void> _upsertCustomer(String uuid, Map<String, dynamic> data) async {
    final existing = await (db.select(
      db.customers,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.customers)..where((t) => t.uuid.equals(uuid))).write(
        CustomersCompanion(
          name: Value(data['name'] as String? ?? ''),
          phone: Value(data['phone'] as String?),
          email: Value(data['email'] as String?),
          address: Value(data['address'] as String?),
          creditLimit: Value(
            (data['credit_limit'] as num?)?.toDouble() ?? 0.0,
          ),
          currentBalance: Value(
            (data['current_balance'] as num?)?.toDouble() ?? 0.0,
          ),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
      await db
          .into(db.customers)
          .insert(
            CustomersCompanion(
              uuid: Value(uuid),
              name: Value(data['name'] as String? ?? ''),
              phone: Value(data['phone'] as String?),
              email: Value(data['email'] as String?),
              address: Value(data['address'] as String?),
              creditLimit: Value(
                (data['credit_limit'] as num?)?.toDouble() ?? 0.0,
              ),
              currentBalance: Value(
                (data['current_balance'] as num?)?.toDouble() ?? 0.0,
              ),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    }
  }

  Future<void> _upsertSupplier(String uuid, Map<String, dynamic> data) async {
    final existing = await (db.select(
      db.suppliers,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.suppliers)..where((t) => t.uuid.equals(uuid))).write(
        SuppliersCompanion(
          name: Value(data['name'] as String? ?? ''),
          phone: Value(data['phone'] as String?),
          email: Value(data['email'] as String?),
          address: Value(data['address'] as String?),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
      await db
          .into(db.suppliers)
          .insert(
            SuppliersCompanion(
              uuid: Value(uuid),
              name: Value(data['name'] as String? ?? ''),
              phone: Value(data['phone'] as String?),
              email: Value(data['email'] as String?),
              address: Value(data['address'] as String?),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    }
  }

  Future<void> _upsertEmployee(String uuid, Map<String, dynamic> data) async {
    final existing = await (db.select(
      db.employees,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.employees)..where((t) => t.uuid.equals(uuid))).write(
        EmployeesCompanion(
          name: Value(data['name'] as String? ?? ''),
          phone: Value(data['phone'] as String?),
          email: Value(data['email'] as String?),
          address: Value(data['address'] as String?),
          role: Value(data['role'] as String? ?? 'employee'),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
      await db
          .into(db.employees)
          .insert(
            EmployeesCompanion(
              uuid: Value(uuid),
              name: Value(data['name'] as String? ?? ''),
              phone: Value(data['phone'] as String?),
              email: Value(data['email'] as String?),
              address: Value(data['address'] as String?),
              role: Value(data['role'] as String? ?? 'employee'),
              password: Value(data['password'] as String?),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    }
  }

  Future<void> _upsertInvoice(String uuid, Map<String, dynamic> data) async {
    final customerId = await _customerIdForUuid(data['customer_uuid'] as String?);
    final existing = await (db.select(
      db.invoices,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.invoices)..where((t) => t.uuid.equals(uuid))).write(
        InvoicesCompanion(
          invoiceNumber: Value(data['invoice_number'] as String? ?? ''),
          customerId: Value(customerId),
          subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0.0),
          tax: Value((data['tax'] as num?)?.toDouble() ?? 0.0),
          discount: Value((data['discount'] as num?)?.toDouble() ?? 0.0),
          total: Value((data['total'] as num?)?.toDouble() ?? 0.0),
          paymentMethod: Value(data['payment_method'] as String?),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
      await db
          .into(db.invoices)
          .insert(
            InvoicesCompanion(
              uuid: Value(uuid),
              invoiceNumber: Value(data['invoice_number'] as String? ?? ''),
              customerId: Value(customerId),
              date: Value(
                data['date'] != null
                    ? DateTime.parse(data['date'] as String)
                    : DateTime.now(),
              ),
              subtotal: Value(
                (data['subtotal'] as num?)?.toDouble() ?? 0.0,
              ),
              tax: Value((data['tax'] as num?)?.toDouble() ?? 0.0),
              discount: Value(
                (data['discount'] as num?)?.toDouble() ?? 0.0,
              ),
              total: Value((data['total'] as num?)?.toDouble() ?? 0.0),
              paymentMethod: Value(data['payment_method'] as String?),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    }
  }

  Future<void> _upsertPurchaseReceipt(String uuid, Map<String, dynamic> data) async {
    final existing = await (db.select(
      db.purchaseReceipts,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

    final supplierUuid = data['supplier_uuid'] as String?;
    int? supplierId;
    if (supplierUuid != null) {
      final sup = await (db.select(db.suppliers)
            ..where((t) => t.uuid.equals(supplierUuid)))
          .getSingleOrNull();
      supplierId = sup?.id;
    } else {
      supplierId = (data['supplier_id'] as num?)?.toInt();
    }

    final itemsData = data['items'] as List<dynamic>?;

    if (existing != null) {
      await (db.update(db.purchaseReceipts)..where((t) => t.uuid.equals(uuid))).write(
        PurchaseReceiptsCompanion(
          invoiceNumber: Value(data['invoice_number'] as String? ?? existing.invoiceNumber),
          supplierInvoiceNumber: Value(data['supplier_invoice_number'] as String?),
          supplierId: Value(supplierId ?? 0),
          subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? existing.subtotal),
          tax: Value((data['tax'] as num?)?.toDouble() ?? existing.tax),
          discount: Value((data['discount'] as num?)?.toDouble() ?? existing.discount),
          totalAmount: Value((data['total_amount'] as num?)?.toDouble() ?? existing.totalAmount),
          notes: Value(data['notes'] as String?),
          status: Value(data['status'] as String? ?? existing.status),
          createdBy: Value(data['created_by'] as String?),
          date: Value(data['date'] != null ? DateTime.parse(data['date'] as String) : existing.date),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
      await db
          .into(db.purchaseReceipts)
          .insert(
            PurchaseReceiptsCompanion(
              uuid: Value(uuid),
              invoiceNumber: Value(data['invoice_number'] as String? ?? ''),
              supplierInvoiceNumber: Value(data['supplier_invoice_number'] as String?),
              supplierId: Value(supplierId ?? 0),
              subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0.0),
              tax: Value((data['tax'] as num?)?.toDouble() ?? 0.0),
              discount: Value((data['discount'] as num?)?.toDouble() ?? 0.0),
              totalAmount: Value((data['total_amount'] as num?)?.toDouble() ?? 0.0),
              notes: Value(data['notes'] as String?),
              status: Value(data['status'] as String? ?? 'COMPLETED'),
              createdBy: Value(data['created_by'] as String?),
              date: Value(data['date'] != null ? DateTime.parse(data['date'] as String) : DateTime.now()),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    }

    if (itemsData != null && itemsData.isNotEmpty) {
      // Find the local receipt id
      final receipt = await (db.select(db.purchaseReceipts)
            ..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();
      if (receipt != null) {
        await (db.delete(db.purchaseReceiptItems)
              ..where((t) => t.receiptId.equals(receipt.id)))
            .go();
        for (final item in itemsData) {
          final itemMap = item as Map<String, dynamic>;
          final productUuid = itemMap['product_uuid'] as String?;
          int? productId;
          if (productUuid != null) {
            final prod = await (db.select(db.products)
                  ..where((t) => t.uuid.equals(productUuid)))
                .getSingleOrNull();
            productId = prod?.id;
          } else {
            productId = (itemMap['product_id'] as num?)?.toInt();
          }
          await db.into(db.purchaseReceiptItems).insert(
            PurchaseReceiptItemsCompanion(
              receiptId: Value(receipt.id),
              productId: Value(productId ?? 0),
              quantity: Value((itemMap['quantity'] as num?)?.toDouble() ?? 0),
              unitId: Value((itemMap['unit_id'] as num?)?.toInt() ?? 0),
              price: Value((itemMap['price'] as num?)?.toDouble() ?? 0),
              totalPrice: Value((itemMap['total_price'] as num?)?.toDouble() ?? 0),
              discountPerItem: Value((itemMap['discount_per_item'] as num?)?.toDouble()),
              taxPerItem: Value((itemMap['tax_per_item'] as num?)?.toDouble()),
              isDeleted: const Value(false),
            ),
          );
        }
      }
    }
  }

  Future<void> _upsertCustomerTransaction(String uuid, Map<String, dynamic> data) async {
    final existing = await (db.select(
      db.customerTransactions,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

    final customerUuid = data['customer_uuid'] as String?;
    int? customerId;
    if (customerUuid != null) {
      final cust = await (db.select(db.customers)
            ..where((t) => t.uuid.equals(customerUuid)))
          .getSingleOrNull();
      customerId = cust?.id;
    } else {
      customerId = (data['customer_id'] as num?)?.toInt();
    }

    if (existing != null) {
      await (db.update(db.customerTransactions)..where((t) => t.uuid.equals(uuid))).write(
        CustomerTransactionsCompanion(
          customerId: Value(customerId ?? existing.customerId),
          amount: Value((data['amount'] as num?)?.toDouble() ?? existing.amount),
          type: Value(data['type'] as String? ?? existing.type),
          remarks: Value(data['remarks'] as String?),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
      await db
          .into(db.customerTransactions)
          .insert(
            CustomerTransactionsCompanion(
              uuid: Value(uuid),
              customerId: Value(customerId ?? 0),
              amount: Value((data['amount'] as num?)?.toDouble() ?? 0.0),
              type: Value(data['type'] as String? ?? 'debit'),
              remarks: Value(data['remarks'] as String?),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    }
  }

  Future<void> _upsertSupplierTransaction(String uuid, Map<String, dynamic> data) async {
    final existing = await (db.select(
      db.supplierTransactions,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

    final supplierUuid = data['supplier_uuid'] as String?;
    int? supplierId;
    if (supplierUuid != null) {
      final sup = await (db.select(db.suppliers)
            ..where((t) => t.uuid.equals(supplierUuid)))
          .getSingleOrNull();
      supplierId = sup?.id;
    } else {
      supplierId = (data['supplier_id'] as num?)?.toInt();
    }

    if (existing != null) {
      await (db.update(db.supplierTransactions)..where((t) => t.uuid.equals(uuid))).write(
        SupplierTransactionsCompanion(
          supplierId: Value(supplierId ?? existing.supplierId),
          amount: Value((data['amount'] as num?)?.toDouble() ?? existing.amount),
          type: Value(data['type'] as String? ?? existing.type),
          remarks: Value(data['remarks'] as String?),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    } else {
      await db
          .into(db.supplierTransactions)
          .insert(
            SupplierTransactionsCompanion(
              uuid: Value(uuid),
              supplierId: Value(supplierId ?? 0),
              amount: Value((data['amount'] as num?)?.toDouble() ?? 0.0),
              type: Value(data['type'] as String? ?? 'debit'),
              remarks: Value(data['remarks'] as String?),
              tenantId: Value(int.tryParse(tenantId) ?? 1),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    }
  }

  @override
  Future<void> logOperation({
    required String entity,
    required String entityId,
    required int opType,
    required Map<String, dynamic> data,
  }) async {
    final now = DateTime.now();
    await db
        .into(db.syncOutbox)
        .insertOnConflictUpdate(
          SyncOutboxCompanion(
            idempotencyKey: Value(_uuid.v4()),
            tenantId: Value(tenantId),
            companyId: Value(companyId),
            deviceId: Value(deviceId),
            entity: Value(entity),
            entityId: Value(entityId),
            opType: Value(opType),
            data: Value(jsonEncode(data)),
            createdAt: Value(now),
          ),
        );
    // Flush the outbox within ~2 seconds via the debounce timer.
    // Without this, the periodic 60-second timer is the only trigger.
    unawaited(sync());
  }

  Future<bool> hasPendingOperations() async {
    final count = await (db.select(db.syncOutbox)..limit(1)).get();
    return count.isNotEmpty;
  }

  Future<int> pendingCount() async {
    final countExp = db.syncOutbox.id.count();
    final query = db.selectOnly(db.syncOutbox)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  Future<void> clearOutbox() async {
    await db.delete(db.syncOutbox).go();
  }

  Future<void> clearFailedOutboxEntries() async {
    await (db.delete(db.syncOutbox)
          ..where((t) => t.status.equals('failed')))
        .go();
  }

  Future<void> cleanAndFullSync() async {
    await clearOutbox();
    await _updateLastSyncTime(DateTime.fromMillisecondsSinceEpoch(0));
    await sync();
  }
}
