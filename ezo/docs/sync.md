# Ezo Sync System — Complete Low-Level Implementation Plan

## 0. Current State (baseline before this plan)

```
Device A                 Server                  Device B
   │  POST /api/sync ──→  │                         │
   │  ← operations        │                         │
   │                      │                         │
   │    [10 seconds pass]  │    [10 seconds pass]    │
   │                      │  ← POST /api/sync ───── │
   │                      │    operations ──────── → │
```

Problems:
- Up to 10-second latency between Device A writing and Device B seeing the data.
- 10 req/user/minute is wasted load when nothing has changed.
- All devices poll regardless of whether there is new data.

---

## 1. Target Architecture

```
Device A                 Server                  Device B
   │  POST /api/sync ──→  │                         │
   │                      │── NOTIFY company_42 ───→│  (via SSE, <200ms)
   │                      │                         │── syncNow() →  │
   │                      │  ← POST /api/sync ──────│
   │                      │    operations ─────────→│
```

What changes:
1. `POST /api/sync` stays exactly as-is (single endpoint for push + pull).
2. A new `GET /api/sync/events` endpoint streams SSE events.
3. PostgreSQL fires `NOTIFY` every time a row is inserted into `sync_operations_log`.
4. A singleton `NotificationBroadcaster` in Node.js listens once and fans out to all connected SSE clients.
5. Flutter holds one open `GET /api/sync/events` connection per device.
6. On receiving `data: ping`, Flutter calls `syncNow()` immediately.
7. A 60-second fallback poll runs as a safety net when SSE is disconnected.

---

## 2. Invariants — Rules That Must Never Break

1. `POST /api/sync` is the **only** path for data changes. SSE is notification-only — it carries no data.
2. Every write that goes through the sync push processor **must** land in `sync_operations_log`. No write bypasses this.
3. The `lastPulledAt` cursor is always a UTC ISO-8601 timestamp. Flutter saves the `nextCursor` returned in the pull response after every successful sync.
4. If SSE is disconnected, the 60-second fallback `Timer.periodic` **must** still fire.
5. A device that has not synced in more than 30 days receives a `FULL_RESYNC_REQUIRED` signal and clears its local DB.
6. `company_id` from the JWT **must** match the `X-Company-Id` header. Every sync request (push, pull, SSE) validates this.
7. The `NotificationBroadcaster` uses exactly **one** extra pg connection regardless of how many SSE clients are connected.

---

## 3. Why SSE Over WebSockets

| Concern | SSE | WebSocket |
|---------|-----|-----------|
| Complexity | Low — plain HTTP GET with streaming body | High — HTTP upgrade, custom framing, ping-pong |
| Flutter client | `dart:io` HttpClient (no extra package) | Needs ws package + reconnect management |
| Server → client messages | ✅ (that's all we need) | ✅ (overkill, we never need client→server push) |
| Auto-reconnect spec | Built into EventSource spec | Manual implementation required |
| Load balancer / proxy | Works with `proxy_buffering off` | Needs `Upgrade: websocket` passthrough |
| PG connections for pub/sub | 1 LISTEN client for all SSE connections | Same (if you use PG NOTIFY) |
| Scales to 100 users | ✅ trivially | ✅ but more complexity |

For a POS app where the server only needs to say "hey, go pull now", SSE is the correct choice.

---

## 4. Backend Implementation

### Step B-1 — PostgreSQL trigger for NOTIFY

**File to create**: `backend/migrations/008_sync_notify_trigger.sql`

Every INSERT into `sync_operations_log` fires `pg_notify('sync_company_<id>', '')`.
This is the only DB-level change needed.

```sql
-- Function called by trigger
CREATE OR REPLACE FUNCTION notify_sync_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('sync_company_' || NEW.company_id::text, '');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to the operations log
DROP TRIGGER IF EXISTS sync_operations_log_notify ON sync_operations_log;
CREATE TRIGGER sync_operations_log_notify
  AFTER INSERT ON sync_operations_log
  FOR EACH ROW
  EXECUTE FUNCTION notify_sync_change();
```

Run it:
```bash
psql $DATABASE_URL -f backend/migrations/008_sync_notify_trigger.sql
```

**Verification test B-1**
Open two terminals.

Terminal 1 — listen:
```bash
psql $DATABASE_URL
LISTEN "sync_company_1";
-- Stay connected and wait
```

Terminal 2 — insert:
```bash
psql $DATABASE_URL -c "
  INSERT INTO sync_operations_log
    (op_id, company_id, device_id, table_name, record_uuid, operation, data_new, timestamp)
  VALUES
    (gen_random_uuid(), 1, 'test', 'categories', gen_random_uuid(), 'INSERT', '{}', NOW());
"
```

Expected in Terminal 1 within 500ms:
```
Asynchronous notification "sync_company_1" received from server process with PID XXXXX.
```

If you do NOT see this: the trigger is not installed. Re-run the migration and check `\df notify_sync_change` and `\d sync_operations_log` in psql.

---

### Step B-2 — NotificationBroadcaster singleton

**File to create**: `backend/src/services/notificationBroadcaster.ts`

This is the most important piece of the backend. One dedicated `pg.Client` connects to PostgreSQL and `LISTEN`s. When a notification arrives, it fans out to all in-memory handlers (one per connected SSE client). This costs exactly ONE extra PostgreSQL connection regardless of how many SSE clients exist.

```typescript
import pg from 'pg';
import { config } from '../config';

type Handler = () => void;

class NotificationBroadcaster {
  private client: pg.Client | null = null;
  private listeners = new Map<string, Set<Handler>>();
  private connected = false;

  async initialize(): Promise<void> {
    this.client = new pg.Client({ connectionString: config.database.url });
    await this.client.connect();
    this.connected = true;

    this.client.on('notification', (msg) => {
      const set = this.listeners.get(msg.channel);
      if (set) set.forEach(fn => fn());
    });

    this.client.on('error', (err) => {
      console.error('[Broadcaster] pg error:', err.message);
      this.connected = false;
      setTimeout(() => this._reconnect(), 5000);
    });

    this.client.on('end', () => {
      if (this.connected) {
        this.connected = false;
        setTimeout(() => this._reconnect(), 5000);
      }
    });

    console.log('[Broadcaster] initialized');
  }

  private async _reconnect(): Promise<void> {
    try {
      const activeChannels = [...this.listeners.keys()];
      await this.initialize();
      for (const ch of activeChannels) {
        await this.client!.query(`LISTEN "${ch}"`);
      }
      console.log(`[Broadcaster] reconnected, re-listened to ${activeChannels.length} channels`);
    } catch (err) {
      console.error('[Broadcaster] reconnect failed — retrying in 5s');
      setTimeout(() => this._reconnect(), 5000);
    }
  }

  async subscribe(channel: string, handler: Handler): Promise<() => void> {
    if (!this.listeners.has(channel)) {
      this.listeners.set(channel, new Set());
      if (this.connected) {
        await this.client!.query(`LISTEN "${channel}"`);
      }
    }
    this.listeners.get(channel)!.add(handler);

    return async () => {
      const set = this.listeners.get(channel);
      if (!set) return;
      set.delete(handler);
      if (set.size === 0) {
        this.listeners.delete(channel);
        if (this.connected) {
          await this.client!.query(`UNLISTEN "${channel}"`);
        }
      }
    };
  }

  totalConnections(): number {
    let n = 0;
    this.listeners.forEach(s => (n += s.size));
    return n;
  }
}

export const broadcaster = new NotificationBroadcaster();
```

**Wire into `backend/src/index.ts`**:

Find the startup block (where you call `app.listen(...)`) and add BEFORE it:

```typescript
import { broadcaster } from './services/notificationBroadcaster';

// initialize broadcaster before any route handler can use it
await broadcaster.initialize();
```

**Verification test B-2**

Add a temporary test route anywhere in your Express app:

```typescript
app.get('/test/broadcaster', async (req, res) => {
  const unsub = await broadcaster.subscribe('sync_company_1', () => {
    console.log('[TEST broadcaster] notification received!');
  });
  setTimeout(unsub, 15_000); // cleanup after 15s
  res.json({ connections: broadcaster.totalConnections() });
});
```

1. `GET http://localhost:5004/test/broadcaster` → should return `{ connections: 1 }`
2. In psql: insert a row into `sync_operations_log` with `company_id=1`
3. Check server console: must print `[TEST broadcaster] notification received!` within 1 second.

Delete the test route before moving on.

---

### Step B-3 — SSE route `GET /api/sync/events`

**File to create**: `backend/src/routes/syncEvents.ts`

Behavior:
- Authenticate exactly like `/api/sync` (Bearer token + X-Company-Id header).
- Open `text/event-stream` response.
- Subscribe to `sync_company_<companyId>` via `broadcaster`.
- Send `data: connected\n\n` immediately so the client knows the connection is live.
- Send `data: ping\n\n` on each PG notification.
- Send `: heartbeat\n\n` every 25 seconds (prevents proxy/load-balancer timeouts).
- On client disconnect: unsubscribe and release resources.

```typescript
import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth.middleware';
import { broadcaster } from '../services/notificationBroadcaster';

const router = Router();
const MAX_SSE_CONNECTIONS = 500;
let activeConnections = 0;

router.get('/', authMiddleware, async (req: Request, res: Response): Promise<void> => {
  if (activeConnections >= MAX_SSE_CONNECTIONS) {
    res.status(503).json({ error: 'SSE_CAPACITY_REACHED' });
    return;
  }

  // ── SSE response headers ─────────────────────────────────────
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no'); // disable nginx buffering
  res.flushHeaders();                        // send headers immediately, before any data

  activeConnections++;
  const companyId = (req as any).companyId as number;
  const channel = `sync_company_${companyId}`;

  // ── Heartbeat to keep TCP alive through proxies ──────────────
  const heartbeat = setInterval(() => {
    if (!res.writableEnded) res.write(': heartbeat\n\n');
  }, 25_000);

  // ── Subscribe to PG notifications ────────────────────────────
  const unsubscribe = await broadcaster.subscribe(channel, () => {
    if (!res.writableEnded) res.write('data: ping\n\n');
  });

  // ── Initial connected event ───────────────────────────────────
  res.write('data: connected\n\n');

  console.log(`[SSE] connect company=${companyId} total=${activeConnections}`);

  // ── Cleanup when client disconnects ──────────────────────────
  req.on('close', () => {
    clearInterval(heartbeat);
    unsubscribe();
    activeConnections--;
    console.log(`[SSE] disconnect company=${companyId} total=${activeConnections}`);
  });
});

export { router as syncEventsRouter };
```

**Register in `backend/src/index.ts`**:

IMPORTANT: register `/api/sync/events` BEFORE `/api/sync`, otherwise Express may match the wrong route.

```typescript
import { syncEventsRouter } from './routes/syncEvents';
import { syncRouter } from './routes/sync';

// /events must come before /sync
app.use('/api/sync/events', syncEventsRouter);
app.use('/api/sync', syncRouter);
```

**Nginx config** (if you put Nginx in front of Node.js):

```nginx
location /api/sync/events {
  proxy_pass         http://localhost:5004;
  proxy_buffering    off;
  proxy_cache        off;
  proxy_read_timeout 3600s;
  proxy_http_version 1.1;
  proxy_set_header   Connection '';
  chunked_transfer_encoding on;
}
```

**Verification test B-3**

Get a real JWT by logging into your app and copying it from the debug logs (look for `[AUTH][STORE]`).

```bash
TOKEN="paste_your_jwt_here"
COMPANY_ID="1"

curl -N \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Company-Id: $COMPANY_ID" \
  -H "Accept: text/event-stream" \
  http://localhost:5004/api/sync/events
```

Expected immediately:
```
data: connected

```

Expected every 25 seconds:
```
: heartbeat

```

Now in a second terminal insert a row:
```bash
psql $DATABASE_URL -c "
  INSERT INTO sync_operations_log
    (op_id, company_id, device_id, table_name, record_uuid, operation, data_new, timestamp)
  VALUES
    (gen_random_uuid(), 1, 'test', 'categories', gen_random_uuid(), 'INSERT', '{}', NOW());
"
```

Expected in the curl terminal within 500ms:
```
data: ping

```

If `ping` does not appear within 2 seconds → broadcaster is not wired to the SSE route. Check that `broadcaster.initialize()` was called at startup and that `broadcaster.subscribe()` is being called inside the route handler.

---

### Step B-4 — Archive old operations (prevent table bloat)

Operations older than 30 days are dead weight. No active client needs them (clients that haven't synced in >30 days get a full re-sync instead). Archive them to keep the hot query fast.

**File to create**: `backend/migrations/009_ops_log_archive.sql`

```sql
CREATE TABLE IF NOT EXISTS sync_operations_log_archive
  (LIKE sync_operations_log INCLUDING ALL);
```

**File to create**: `backend/src/services/opsLogArchiver.ts`

```typescript
import { pool } from '../db/sync-db';

export async function archiveOldOperations(): Promise<number> {
  const { rowCount } = await pool.query(`
    WITH archived AS (
      DELETE FROM sync_operations_log
      WHERE timestamp < NOW() - INTERVAL '30 days'
      RETURNING *
    )
    INSERT INTO sync_operations_log_archive SELECT * FROM archived
  `);
  const count = rowCount ?? 0;
  if (count > 0) console.log(`[archiver] archived ${count} old operations`);
  return count;
}
```

Call it in `index.ts` once per day (use `node-cron` or a system cron):

```typescript
import cron from 'node-cron';
import { archiveOldOperations } from './services/opsLogArchiver';

cron.schedule('0 3 * * *', archiveOldOperations); // 3am every day
```

**Handle clients behind by more than 30 days**

In `backend/src/services/pullProcessor.ts`, at the very start of `fetchPullOperations()`, add:

```typescript
const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
if (cursor < thirtyDaysAgo) {
  console.warn(`[pullProcessor] companyId=${companyId} cursor too old (${cursor.toISOString()}) — sending FULL_RESYNC_REQUIRED`);
  return {
    operations: [{
      opId: 'system',
      type: 'FULL_RESYNC_REQUIRED' as any,
      table: 'system' as any,
      recordId: 'system',
      data: null,
      timestamp: new Date().toISOString(),
    }],
    nextCursor: new Date(0).toISOString(),
  };
}
```

In Flutter's `SyncEngine._sync()`, add at the start of the operation-apply loop:

```dart
// Check for full resync signal before processing any operations
if (operations.isNotEmpty && operations.first['type'] == 'FULL_RESYNC_REQUIRED') {
  print('[SyncEngine] Server requested full re-sync — clearing local DB');
  await db.clearAllData();
  await _updateLastSyncTime(DateTime.fromMillisecondsSinceEpoch(0));
  // Recursive call with reset cursor will get all data from epoch
  return await _sync();
}
```

Place this check BEFORE the `for (final op in operations)` loop.

**Verification test B-4**

1. Temporarily change `INTERVAL '30 days'` to `INTERVAL '1 second'` in the archiver.
2. Insert 5 rows into `sync_operations_log`.
3. `await new Promise(r => setTimeout(r, 2000))` — wait 2 seconds.
4. Run `await archiveOldOperations()` — should log `archived 5 old operations`.
5. `SELECT COUNT(*) FROM sync_operations_log` → should return 0.
6. `SELECT COUNT(*) FROM sync_operations_log_archive` → should return 5.
7. Restore the interval to `30 days`.

---

## 5. Flutter Implementation

### Step F-1 — SseClient class

**File to create**: `lib/core/services/sse_client.dart`

This class uses `dart:io` HttpClient (not Dio) to stream the SSE response line by line. Dio is not used here because SSE requires low-level streaming control.

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SseClient {
  HttpClient? _httpClient;
  StreamSubscription<String>? _lineSubscription;
  bool _disposed = false;
  int _reconnectDelay = 2;
  Timer? _reconnectTimer;

  static const int _maxReconnectDelay = 60;

  Future<void> connect({
    required String url,
    required String token,
    required String companyId,
    required void Function() onEvent,
    required void Function(String) onLog,
  }) async {
    if (_disposed) return;
    _cancel();

    try {
      _httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);

      final uri = Uri.parse(url);
      final request = await _httpClient!.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('X-Company-Id', companyId);
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');

      final response = await request.close();

      if (response.statusCode != 200) {
        onLog('[SSE] HTTP ${response.statusCode} — will retry');
        _scheduleReconnect(url: url, token: token, companyId: companyId,
            onEvent: onEvent, onLog: onLog);
        return;
      }

      _reconnectDelay = 2;
      onLog('[SSE] Connected');

      _lineSubscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.startsWith('data:')) {
            final payload = line.substring(5).trim();
            onLog('[SSE] event=$payload');
            if (payload == 'ping') onEvent();
          }
        },
        onError: (Object e) {
          onLog('[SSE] error: $e');
          _scheduleReconnect(url: url, token: token, companyId: companyId,
              onEvent: onEvent, onLog: onLog);
        },
        onDone: () {
          if (!_disposed) {
            onLog('[SSE] stream ended — reconnecting');
            _scheduleReconnect(url: url, token: token, companyId: companyId,
                onEvent: onEvent, onLog: onLog);
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      onLog('[SSE] connect failed: $e');
      _scheduleReconnect(url: url, token: token, companyId: companyId,
          onEvent: onEvent, onLog: onLog);
    }
  }

  void _scheduleReconnect({
    required String url,
    required String token,
    required String companyId,
    required void Function() onEvent,
    required void Function(String) onLog,
  }) {
    if (_disposed) return;
    _cancel();
    onLog('[SSE] retry in ${_reconnectDelay}s');
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _reconnectDelay = (_reconnectDelay * 2).clamp(2, _maxReconnectDelay);
      connect(url: url, token: token, companyId: companyId,
          onEvent: onEvent, onLog: onLog);
    });
  }

  void _cancel() {
    _lineSubscription?.cancel();
    _lineSubscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void disconnect() {
    _disposed = true;
    _cancel();
  }

  // Call this before re-connecting after a deliberate disconnect (e.g., re-login).
  void resetForReconnect() {
    _disposed = false;
    _reconnectDelay = 2;
  }
}
```

**Verification test F-1** (manual integration test)

Create a temporary Dart file `test_sse.dart` at the project root:

```dart
import 'dart:io';
import 'lib/core/services/sse_client.dart';

void main() async {
  final client = SseClient();
  var eventCount = 0;

  await client.connect(
    url: 'http://localhost:5004/api/sync/events',
    token: 'REPLACE_WITH_VALID_JWT',
    companyId: '1',
    onEvent: () {
      eventCount++;
      print('>>> EVENT RECEIVED total=$eventCount');
    },
    onLog: print,
  );

  print('Waiting 60s...');
  await Future.delayed(const Duration(seconds: 60));
  client.disconnect();
  print('Done. Total events: $eventCount');
  exit(0);
}
```

Run: `dart test_sse.dart`

Expected:
- Prints `[SSE] Connected` immediately.
- Every time you insert into `sync_operations_log` (company_id=1) in psql, prints `>>> EVENT RECEIVED`.
- Every 25 seconds, nothing visible (heartbeat lines are ignored).
- After ~5s of no inserts, prints nothing (quiet).
- Deletes the file when done.

---

### Step F-2 — Update SyncEngine

**File to modify**: `lib/core/services/sync_engine.dart`

#### 2a. Add the import at the top

```dart
import 'sse_client.dart';
```

#### 2b. Add fields to the SyncEngine class (after `final _uuid`)

```dart
final _sseClient = SseClient();
```

#### 2c. Replace `startAutoSync()` entirely

```dart
void startAutoSync({Duration interval = const Duration(seconds: 60)}) {
  _syncTimer?.cancel();
  // 60-second fallback poll — fires even when SSE is active for safety
  _syncTimer = Timer.periodic(interval, (_) => sync());
  // Initial pull after 2 seconds (lets auth settle)
  Future.delayed(const Duration(seconds: 2), syncNow);
  // Open SSE stream for real-time notifications
  _connectSse();
}
```

#### 2d. Add `_connectSse()` method

```dart
Future<void> _connectSse() async {
  final token = await ServiceLocator.instance.secureStorage.read(
    key: 'auth_token',
  );
  final companyIdStr = await ServiceLocator.instance.secureStorage.read(
    key: 'company_id',
  );
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
```

#### 2e. Update `stopAutoSync()` to also close SSE

```dart
void stopAutoSync() {
  _syncTimer?.cancel();
  _debounceTimer?.cancel();
  _sseClient.disconnect();
}
```

**Verification test F-2**

1. Build and run the Flutter app.
2. Log in as `chandanapack@gmail.com`.
3. Check debug logs. You must see:
   - `[ServiceLocator] SyncEngine activated: tenantId=X companyId=Y`
   - `[SSE] Connected`
   - `[DIAG] _runPostLoginSync: STARTING`
   - `[DIAG] _runPostLoginSync: COMPLETED (pulled=N pushed=0 errors=0)`
4. Navigate to the product list. You should see existing products (pulled from the backfill migration).
5. On a second device logged into the same company, create a new product.
6. On the first device (without touching it), within 3 seconds the product should appear.

If step 6 doesn't work:
- Check that both devices show `[SSE] Connected` in logs.
- Insert directly into `sync_operations_log` from psql with the correct `company_id` and verify the SSE ping arrives.

---

### Step F-3 — SyncStatus Riverpod provider

**File to create**: `lib/core/providers/sync_status_provider.dart`

Exposes a status enum so the UI can show a sync indicator.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncStatus { idle, syncing, error }

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(SyncStatus.idle);

  void setSyncing() => state = SyncStatus.syncing;
  void setIdle() => state = SyncStatus.idle;
  void setError() => state = SyncStatus.error;
}

final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatus>(
  (ref) => SyncStatusNotifier(),
);
```

**Wire SyncEngine → provider**

In `lib/core/services/sync_engine.dart`, add a callback field:

```dart
void Function(SyncEngineResult)? onSyncComplete;
```

At the end of `_doSync()`, just before the final `return result` inside the `try` block:

```dart
onSyncComplete?.call(result);
```

In your app's root widget (wherever you have `ProviderScope`), after the widget tree is built, wire it up. A simple place is the `_completeLogin()` in `auth_controller.dart` after `activateSyncEngine`:

```dart
// In auth_controller.dart, inside _completeLogin(), after activateSyncEngine call:
// (ProviderContainer must be accessible — pass it via constructor or use a global ref)
```

OR, since this is a notification-only UI concern, just watch `salesListStreamProvider` changing as the signal — Drift streams auto-update and the UI rebuilds. The `syncStatusProvider` is optional UI polish.

---

## 6. End-to-End Verification Tests

Run these tests IN ORDER. Each test assumes the previous ones passed.

### Test E2E-1: Backend trigger fires correctly

```bash
# Terminal 1
psql $DATABASE_URL -c "LISTEN \"sync_company_1\"; SELECT pg_sleep(20);"

# Terminal 2 (in parallel)
psql $DATABASE_URL -c "
  INSERT INTO sync_operations_log
    (op_id, company_id, device_id, table_name, record_uuid, operation, data_new, timestamp)
  VALUES (gen_random_uuid(), 1, 'e2e-test', 'products', gen_random_uuid(), 'INSERT', '{}', NOW());
"
```

Pass condition: Terminal 1 prints the NOTIFY message within 1 second.

---

### Test E2E-2: SSE endpoint delivers ping

```bash
TOKEN="your_valid_token"
COMPANY_ID="1"

# Terminal 1
curl -N -H "Authorization: Bearer $TOKEN" \
  -H "X-Company-Id: $COMPANY_ID" \
  http://localhost:5004/api/sync/events &
CURL_PID=$!

sleep 2

# Terminal 2
psql $DATABASE_URL -c "
  INSERT INTO sync_operations_log
    (op_id, company_id, device_id, table_name, record_uuid, operation, data_new, timestamp)
  VALUES (gen_random_uuid(), 1, 'e2e-test', 'products', gen_random_uuid(), 'INSERT', '{}', NOW());
"

sleep 2
kill $CURL_PID
```

Pass condition: `data: ping` appears in the curl output within 2 seconds of the insert.

---

### Test E2E-3: Flutter pull on login shows existing data

This requires the backfill migration (007) to have been run first.

1. Log out of the Flutter app (clears local DB including syncState).
2. Log in as `chandanapack@gmail.com`.
3. Navigate to Products, Categories, Customers, Invoices.

Pass condition: All entities that exist in the backend DB are visible without any manual refresh.
Failure diagnosis: Check logs for `[DIAG] _runPostLoginSync: COMPLETED (pulled=N ...)`. If N=0, the backfill migration is not installed or sync_operations_log is empty. Run `SELECT COUNT(*) FROM sync_operations_log` in psql.

---

### Test E2E-4: Real-time sync across two devices

Setup: Two running instances of the app, both logged in as the same company.

1. On Device B: navigate to Products. Note count = N. Verify `[SSE] Connected` in logs.
2. On Device A: create a new product named `RealTimeTest-1`.
3. Device A pushes via `syncNow()`. Server logs the INSERT to `sync_operations_log`. PG NOTIFY fires. SSE delivers `ping` to Device B. Device B calls `syncNow()`.
4. Observe Device B.

Pass condition: Device B shows `RealTimeTest-1` within 3 seconds WITHOUT any user action on Device B.

Timing breakdown:
- Device A push → server: ~100ms
- Server write to ops log → NOTIFY: ~5ms
- NOTIFY → broadcaster handler: ~1ms
- SSE write to Device B: ~50ms (network)
- Device B SSE handler → `syncNow()`: ~1ms
- `syncNow()` pull request round trip: ~200ms
- Drift stream emits new row: ~10ms
- Flutter rebuilds UI: ~16ms

Total: typically ~400ms in LAN, ~1-2s over internet.

---

### Test E2E-5: SSE reconnection after backend restart

1. Verify Device A shows `[SSE] Connected` in logs.
2. Stop the backend server (`Ctrl+C`).
3. Watch Device A logs.

Expected sequence:
```
[SSE] stream ended — reconnecting
[SSE] retry in 2s
[SSE] connect failed: ...  (backend is down)
[SSE] retry in 4s
```

4. Restart the backend server.

Expected within 5 seconds of restart:
```
[SSE] Connected
```

5. Insert a row into `sync_operations_log`. Device A should receive the ping.

Pass condition: Full reconnect + delivery working within 10 seconds of backend restart.

---

### Test E2E-6: Conflict resolution (LWW — last write wins)

1. Both devices have product `P` with price=`80`.
2. Put Device B offline (airplane mode).
3. On Device B: change price to `50`. (Goes into local syncOutbox, NOT yet pushed.)
4. On Device A: change price to `100`. Push succeeds immediately. `sync_operations_log` has price=`100`.
5. Bring Device B back online.
6. Device B syncs: pushes price=`50`. Server rejects with `TIMESTAMP_CONFLICT` because Device B's timestamp < server's timestamp for this record.
7. Device B pulls: receives price=`100` from ops log.

Pass condition: Both devices show price=`100` after Device B comes back online.
Check Device B's logs for `TIMESTAMP_CONFLICT` in the push response.

---

### Test E2E-7: 100 concurrent SSE connections (load test)

Save as `backend/test/load-sse.js`:

```javascript
// Run: node backend/test/load-sse.js
// Requires: npm install eventsource in backend/

const EventSource = require('eventsource');

const TOKEN = process.env.TEST_TOKEN;
const COMPANY_ID = process.env.TEST_COMPANY_ID || '1';
const COUNT = parseInt(process.env.COUNT || '100');

if (!TOKEN) { console.error('Set TEST_TOKEN env var'); process.exit(1); }

const sources = [];
let connected = 0;
let pings = 0;

for (let i = 0; i < COUNT; i++) {
  const es = new EventSource(`http://localhost:5004/api/sync/events`, {
    headers: {
      'Authorization': `Bearer ${TOKEN}`,
      'X-Company-Id': COMPANY_ID,
    },
  });
  es.onmessage = (e) => {
    if (e.data === 'connected') { connected++; process.stdout.write(`\rConnected: ${connected}/${COUNT}`); }
    if (e.data === 'ping') { pings++; }
  };
  es.onerror = (e) => console.error(`[${i}] error:`, e.status);
  sources.push(es);
}

setTimeout(() => {
  console.log(`\nAll connected: ${connected}/${COUNT}`);
  console.log('Insert a row into sync_operations_log now, then wait 5s...');

  setTimeout(() => {
    console.log(`Pings received: ${pings}/${COUNT}`);
    sources.forEach(s => s.close());
    process.exit(pings >= COUNT * 0.95 ? 0 : 1); // pass if 95%+ received ping
  }, 5000);
}, 8000);
```

Run:
```bash
TEST_TOKEN="your_token" node backend/test/load-sse.js
```

Pass condition:
- All 100 connections show `connected` within 8 seconds.
- After inserting a row, at least 95 of 100 connections receive `data: ping` within 5 seconds.
- PostgreSQL `SELECT count(*) FROM pg_stat_activity WHERE query LIKE '%LISTEN%'` shows exactly 1 extra connection (the broadcaster), not 100.

---

## 7. Operations Log Maintenance Plan

### Why this matters
`sync_operations_log` is an append-only table. Every push writes N rows. A company making 200 transactions per day creates ~200+ rows/day. After 1 year = ~70,000 rows/company. With 100 companies = 7 million rows. The index `(company_id, timestamp)` handles this, but the table still takes disk space and slightly slows backups.

### 30-day window
- Keep the last 30 days hot in `sync_operations_log`.
- Archive older rows to `sync_operations_log_archive` (cold storage, not queried).
- Clients not seen in 30 days get `FULL_RESYNC_REQUIRED`.

### Archive schedule
Run the archiver daily at 3am. It moves rows in one `WITH ... DELETE ... INSERT` transaction.
Expected runtime: < 1 second for typical data volumes.

### When to trigger full re-sync on Flutter
`SyncEngine._sync()` already handles this if you added the check as shown in Step B-4.
When full re-sync is triggered:
1. `db.clearAllData()` — wipes all entity tables, syncState, syncOutbox.
2. `_updateLastSyncTime(DateTime.fromMillisecondsSinceEpoch(0))` — resets cursor to epoch.
3. Recursive `_sync()` call — pulls everything from epoch (backfill migration ensures all data is in ops log).

---

## 8. File Checklist

### Backend — Files to create

| File | Purpose |
|------|---------|
| `migrations/007_backfill_sync_operations.sql` | Backfill existing DB data into ops log (already done) |
| `migrations/008_sync_notify_trigger.sql` | PG trigger: NOTIFY on ops log INSERT |
| `migrations/009_ops_log_archive.sql` | Archive table for old operations |
| `src/services/notificationBroadcaster.ts` | Single pg LISTEN client, fan-out to SSE handlers |
| `src/routes/syncEvents.ts` | `GET /api/sync/events` SSE endpoint |
| `src/services/opsLogArchiver.ts` | Moves ops older than 30 days to archive |
| `test/load-sse.js` | 100-connection load test |

### Backend — Files to modify

| File | What changes |
|------|--------------|
| `src/index.ts` | Call `broadcaster.initialize()` at startup; register `syncEventsRouter` before `syncRouter` |
| `src/services/pullProcessor.ts` | Check for cursor >30 days old, return `FULL_RESYNC_REQUIRED` |

### Flutter — Files to create

| File | Purpose |
|------|---------|
| `lib/core/services/sse_client.dart` | SSE streaming client with exponential-backoff reconnect |
| `lib/core/providers/sync_status_provider.dart` | Riverpod state for sync indicator (optional) |

### Flutter — Files to modify

| File | What changes |
|------|--------------|
| `lib/core/services/sync_engine.dart` | Add `SseClient`, `_connectSse()`, `syncNow()`, fix `startAutoSync()` interval to 60s, fix `stopAutoSync()` to close SSE |
| `lib/core/database/app_database.dart` | `clearAllData()` now clears `syncState` + `syncOutbox` (already done) |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | `googleLogin` + `switchCompany` store `company_id` (already done) |

---

## 9. Acceptance Criteria (Definition of Done)

The sync system is complete when ALL of the following are true:

- [ ] E2E-1 passes: PG NOTIFY fires within 1 second of ops log INSERT.
- [ ] E2E-2 passes: `curl` receives `data: ping` within 2 seconds of insert.
- [ ] E2E-3 passes: Login shows all existing data without manual refresh.
- [ ] E2E-4 passes: Product created on Device A appears on Device B within 3 seconds.
- [ ] E2E-5 passes: SSE reconnects within 10 seconds of backend restart.
- [ ] E2E-6 passes: Conflict resolves to last-write-wins, both devices converge.
- [ ] E2E-7 passes: 100 concurrent SSE connections, all receive ping, PG uses only 1 extra LISTEN connection.
- [ ] Server does not crash or leak memory during E2E-7.
- [ ] Flutter app does not crash or freeze during any test.
- [ ] `syncState` and `syncOutbox` are both empty after logout (verified in local SQLite via DB browser or debug log).
