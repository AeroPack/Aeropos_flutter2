/// Abstract sync interface shared by SyncService (legacy) and SyncEngine.
///
/// ViewModels depend only on this type — they don't care which
/// implementation is injected. This lets us swap SyncService out for
/// SyncEngine without touching any ViewModel constructor.
///
/// Place this file at:
///   lib/core/services/i_sync_service.dart
abstract class ISyncService {
  /// Push any locally-pending operations to the server.
  Future<void> push();

  /// Pull new operations from the server and apply them locally.
  Future<void> pull();

  /// Write a single mutation to the local sync outbox so it gets pushed
  /// on the next sync cycle. opType: 1=INSERT, 2=UPDATE, 3=DELETE.
  Future<void> logOperation({
    required String entity,
    required String entityId,
    required int opType,
    required Map<String, dynamic> data,
  });
}
