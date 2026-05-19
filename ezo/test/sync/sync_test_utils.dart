import 'dart:math';

class MockSyncServer {
  int _lastCursor = 0;
  final Map<String, Map<String, dynamic>> _serverState = {};
  final Map<String, int> _idempotencyIndex = {};
  final List<Map<String, dynamic>> _operations = [];
  bool _shouldFail = false;
  int _failAfter = -1;
  int _requestCount = 0;

  void setFailMode(bool fail, {int failAfter = -1}) {
    _shouldFail = fail;
    _failAfter = failAfter;
    _requestCount = 0;
  }

  Map<String, dynamic> handlePush(Map<String, dynamic> request) {
    _requestCount++;

    if (_shouldFail && (_failAfter < 0 || _requestCount >= _failAfter)) {
      throw Exception('Server temporarily unavailable');
    }

    final operations = request['operations'] as List? ?? [];
    final acked = <String>[];
    final rejected = <Map<String, dynamic>>[];

    for (final op in operations) {
      final idempotencyKey = op['idempotencyKey'] as String?;
      if (idempotencyKey == null) continue;

      // Check idempotency - reject if already processed
      if (_idempotencyIndex.containsKey(idempotencyKey)) {
        final existing = _idempotencyIndex[idempotencyKey]!;
        rejected.add({
          'idempotency_key': idempotencyKey,
          'reason': 'ALREADY_PROCESSED',
          'server_version': existing,
        });
        continue;
      }

      // Check version conflict
      final key = '${op['entity']}_${op['entityId']}';
      if (_serverState.containsKey(key)) {
        final existing = _serverState[key]!;
        final existingVersion = existing['version'] as int? ?? 0;
        final clientVersion = op['version'] as int? ?? 0;
        if (existingVersion > clientVersion) {
          rejected.add({
            'idempotency_key': idempotencyKey,
            'reason': 'VERSION_CONFLICT',
            'server_version': existingVersion,
            'current_state': existing['data'],
          });
          continue;
        }
      }

      _lastCursor++;
      _idempotencyIndex[idempotencyKey] = _lastCursor;
      _operations.add({
        'id': _lastCursor,
        ...op,
        'server_version': _lastCursor,
      });
      _serverState[key] = {'version': _lastCursor, 'data': op['data']};
      acked.add(idempotencyKey);
    }

    final cursor = request['cursor'] as int? ?? 0;
    final newOps = _operations
        .where((o) => (o['server_version'] as int) > cursor)
        .toList();

    return {
      'cursor': _lastCursor,
      'acked': acked,
      'rejected': rejected,
      'server_changes': newOps,
    };
  }

  Map<String, dynamic> handlePull(Map<String, dynamic> request) {
    if (_shouldFail && (_failAfter < 0 || _requestCount >= _failAfter)) {
      throw Exception('Server temporarily unavailable');
    }

    final cursor = request['cursor'] as int? ?? 0;
    final newOps = _operations
        .where((o) => (o['server_version'] as int) > cursor)
        .toList();

    return {'cursor': _lastCursor, 'operations': newOps};
  }

  void reset() {
    _lastCursor = 0;
    _serverState.clear();
    _idempotencyIndex.clear();
    _operations.clear();
    _shouldFail = false;
    _failAfter = -1;
    _requestCount = 0;
  }

  int get operationCount => _operations.length;
}

class ConflictSimulator {
  final Random _random = Random();

  Map<String, dynamic> generateConflict(
    String entity,
    String entityId,
    Map<String, dynamic> serverData,
  ) {
    return {
      'idempotency_key': '${entityId}_conflict',
      'reason': 'VERSION_CONFLICT',
      'server_version': serverData['version'] ?? 1,
      'current_state': {...serverData, 'modified_by': 'other_device'},
    };
  }

  Map<String, dynamic> simulateServerEdit(
    String entity,
    String entityId,
    Map<String, dynamic> data,
  ) {
    return {
      'version': (_random.nextInt(1000) + 100),
      'entity': entity,
      'entity_id': entityId,
      'data': {
        ...data,
        'modified_at': DateTime.now().toIso8601String(),
        'modified_by': 'device_${_random.nextInt(10)}',
      },
    };
  }
}
