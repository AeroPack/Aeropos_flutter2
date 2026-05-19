---
name: sync-service
description: Generate or update the sync service for an entity. Use when wiring an entity
  to pull/push with the backend API. Reads existing SyncService pattern and follows it.
allowed-tools: Read, Write, Bash
---

## Context
@lib/core/network/api_client.dart
@lib/core/sync/

## Existing sync services
!`ls lib/core/sync/ 2>/dev/null || echo "no sync dir yet"`

## Task
Generate sync service for entity: $ARGUMENTS

The sync service must:
1. Pull (backend → local):
   - GET /api/v1/<entities>?since=<last_sync_timestamp>
   - Deserialize array → call repository.syncFromRemote()
   - Update last_sync_timestamp in SharedPreferences

2. Push (local → backend):
   - Call repository.getUnsyncedUuids()
   - GET full records for those UUIDs
   - POST /api/v1/<entities>/sync with array payload
   - On success: call repository.markSynced(uuids)
   - On 409 conflict: log, skip, do not crash

3. Error handling:
   - Wrap in try/catch
   - On DioException: check connectivity_plus first — if offline, queue for later
   - Never throw from sync — log and return SyncResult(synced: n, failed: m)

4. Expose via Riverpod: syncProvider that returns AsyncNotifier<SyncResult>