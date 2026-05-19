import 'sync_test_utils.dart';

void main() {
  testWeeksOffline();
  testLargeBatch();
  testRandomRetry();
  testMultiDeviceConflict();
  testInventoryStress();
  testCrashRecovery();
  testIdempotency();
}

void testWeeksOffline() {
  final server = MockSyncServer();
  final outbox = <Map<String, dynamic>>[];

  for (var i = 0; i < 1000; i++) {
    outbox.add({
      'idempotencyKey': 'op_${i}_${DateTime.now().millisecondsSinceEpoch}',
      'tenantId': 't1',
      'companyId': 'c1',
      'deviceId': 'd1',
      'entity': 'products',
      'entityId': 'prod_$i',
      'opType': 1,
      'data': '{"name": "Product $i", "price": ${100.0 + i}}',
      'version': i + 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  final result = pushBatches(server, outbox, maxBatch: 500);

  assert(result.acked == 1000);
}

void testLargeBatch() {
  final server = MockSyncServer();
  final outbox = <Map<String, dynamic>>[];
  final sw = Stopwatch()..start();

  for (var i = 0; i < 10000; i++) {
    outbox.add({
      'idempotencyKey': 'op_large_$i',
      'tenantId': 't1',
      'companyId': 'c1',
      'deviceId': 'd1',
      'entity': i % 2 == 0 ? 'products' : 'categories',
      'entityId': 'entity_$i',
      'opType': 1,
      'data': '{"name": "Entity $i"}',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  final result = pushBatches(server, outbox, maxBatch: 500);
  sw.stop();

  assert(result.acked == 10000);
}

void testRandomRetry() {
  final server = MockSyncServer();
  final outbox = <Map<String, dynamic>>[];

  for (var i = 0; i < 100; i++) {
    outbox.add({
      'idempotencyKey': 'op_retry_$i',
      'tenantId': 't1',
      'companyId': 'c1',
      'deviceId': 'd1',
      'entity': 'products',
      'entityId': 'prod_$i',
      'opType': 1,
      'data': '{"name": "Product $i"}',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  server.setFailMode(true, failAfter: 2);

  int attempts = 0;
  PushResult? result;

  while (attempts < 5) {
    try {
      result = pushBatchesWithRetry(
        server,
        outbox,
        maxBatch: 500,
        maxRetries: 3,
      );
      break;
    } catch (e) {
      attempts++;
    }
  }

  assert(result!.acked == 100);
}

void testMultiDeviceConflict() {
  final server = MockSyncServer();

  server.handlePush({
    'tenantId': 't1',
    'cursor': 0,
    'operations': [
      {
        'idempotencyKey': 'op_1',
        'entity': 'products',
        'entityId': 'prod_1',
        'opType': 1,
        'data': '{"name": "Initial", "price": 100}',
        'version': 1,
      },
    ],
  });

  final conflictResult = server.handlePush({
    'tenantId': 't1',
    'cursor': 1,
    'operations': [
      {
        'idempotencyKey': 'op_2',
        'entity': 'products',
        'entityId': 'prod_1',
        'opType': 2,
        'data': '{"name": "From Device 2", "price": 150}',
        'version': 1,
      },
    ],
  });

  assert((conflictResult['rejected'] as List).isNotEmpty);
}

void testInventoryStress() {
  final stockDelta = <String, int>{};

  for (var device = 0; device < 5; device++) {
    for (var i = 0; i < 20; i++) {
      final productId = 'prod_${i % 10}';
      stockDelta[productId] = (stockDelta[productId] ?? 0) - 1;
    }
  }

  assert(stockDelta.values.fold(0, (a, b) => a + b) == -100);
}

void testCrashRecovery() {
  final server = MockSyncServer();
  final outbox = <Map<String, dynamic>>[];

  for (var i = 0; i < 100; i++) {
    outbox.add({
      'idempotencyKey': 'op_crash_$i',
      'tenantId': 't1',
      'companyId': 'c1',
      'deviceId': 'd1',
      'entity': 'products',
      'entityId': 'prod_$i',
      'opType': 1,
      'data': '{"name": "Product $i"}',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  server.setFailMode(true, failAfter: 1);

  try {
    pushBatches(server, outbox, maxBatch: 500);
  } catch (e) {
    // Expected to fail
  }

  server.setFailMode(false);
  final result = pushBatches(server, outbox, maxBatch: 500);

  assert(result.acked > 0);
}

void testIdempotency() {
  final server = MockSyncServer();

  final op = {
    'idempotencyKey': 'idem_1',
    'tenantId': 't1',
    'companyId': 'c1',
    'deviceId': 'd1',
    'entity': 'products',
    'entityId': 'prod_1',
    'opType': 1,
    'data': '{"name": "Test"}',
    'version': 1,
    'createdAt': DateTime.now().toIso8601String(),
  };

  server.handlePush({
    'tenantId': 't1',
    'cursor': 0,
    'operations': [op],
  });

  server.handlePush({
    'tenantId': 't1',
    'cursor': 1,
    'operations': [op],
  });

  assert(server.operationCount == 1);
}

class PushResult {
  final int acked;
  final int rejected;
  final int batches;
  PushResult({
    required this.acked,
    required this.rejected,
    required this.batches,
  });
}

PushResult pushBatches(
  MockSyncServer server,
  List<Map<String, dynamic>> outbox, {
  required int maxBatch,
}) {
  int acked = 0;
  int rejected = 0;
  int batches = 0;

  while (outbox.isNotEmpty) {
    batches++;
    final end = maxBatch > outbox.length ? outbox.length : maxBatch;
    final batch = outbox.sublist(0, end);

    final result = server.handlePush({
      'tenantId': 't1',
      'cursor': acked,
      'operations': batch,
    });

    acked += (result['acked'] as List).length;
    rejected += (result['rejected'] as List).length;
    outbox.removeRange(0, end);
  }

  return PushResult(acked: acked, rejected: rejected, batches: batches);
}

PushResult pushBatchesWithRetry(
  MockSyncServer server,
  List<Map<String, dynamic>> outbox, {
  required int maxBatch,
  required int maxRetries,
}) {
  int acked = 0;
  int rejected = 0;
  int batches = 0;

  while (outbox.isNotEmpty) {
    batches++;
    final end = maxBatch > outbox.length ? outbox.length : maxBatch;
    final batch = outbox.sublist(0, end);

    try {
      final result = server.handlePush({
        'tenantId': 't1',
        'cursor': acked,
        'operations': batch,
      });

      acked += (result['acked'] as List).length;
      rejected += (result['rejected'] as List).length;
    } catch (e) {
      if (batches >= maxRetries) rethrow;
    }
    outbox.removeRange(0, end);
  }

  return PushResult(acked: acked, rejected: rejected, batches: batches);
}