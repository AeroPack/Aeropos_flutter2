# Flutter POS - Complete Sync Architecture

This document shows the complete picture of how sync works (and why it's not working).

---

## 1. Service Locator - Which Sync is Active?

**File:** `lib/core/di/service_locator.dart:164-180`

```dart
// Start background sync (only once)
// DISABLED - Using new SyncService instead, old SyncEngine causes conflicts
// syncEngine.startAutoSync();  ← COMMENTED OUT!

// Keep old sync service for backward compatibility during migration
syncService = SyncService(
  db: database,
  dio: dio,
  productRepo: productRepository,
  // ... other repos
);
```

**Current active:** `SyncService` (the OLD one)
**Disabled (commented):** `SyncEngine` (the NEW one with sync_outbox)

---

## 2. Sync_outbox Table Definition

**File:** `lib/core/database/tables/sync_outbox.dart`

```dart
@DataClassName('SyncOutboxEntity')
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get tenantId => text()();
  TextColumn get companyId => text()();
  TextColumn get deviceId => text()();
  TextColumn get entity => text()();           // "products", "categories", etc.
  TextColumn get entityId => text()();          // UUID of the record
  IntColumn get opType => integer()();         // 1=insert, 2=update, 3=delete
  TextColumn get data => text()();           // JSON string of the record data
  DateTimeColumn get createdAt => dateTime()();
  
  // Status tracking
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
}
```

---

## 3. SyncEngine push() Method (NEW - NOT ACTIVE)

**File:** `lib/core/services/sync_engine.dart:380-402`

```dart
Future<List<Map<String, dynamic>>> _getPendingOutbox(int limit) async {
  final rows =
      await (db.select(db.syncOutbox)
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
```

**How it works:**
1. Reads ALL pending operations from `sync_outbox` table
2. Formats them for API
3. Sends to server via `_pushBatch()`
4. On success, DELETES from sync_outbox:
```dart
if ((normalized == 'success' || normalized == 'duplicate') && opId != null) {
  await (db.delete(db.syncOutbox)
        ..where((t) => t.idempotencyKey.equals(opId)))
      .go();
  acked++;
}
```

---

## 4. SyncEngine pull() Method (NEW - NOT ACTIVE)

**File:** `lib/core/services/sync_engine.dart:342-378`

```dart
Future<Map<String, dynamic>> _pullOnce(DateTime? lastPulledAt) async {
  try {
    final body = {
      'deviceId': deviceId,
      'lastPulledAt': lastPulledAt?.toIso8601String() ?? '2026-01-01T00:00:00.000Z',
      'operations': [],
    };

    final response = await dio.post(
      'api/sync',
      data: body,
      // ... headers
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final operations = (data['operations'] as List?) ?? [];
      final nextCursor = data['nextCursor'] as String?;

      return {
        'success': true,
        'operations': operations,
        'nextCursor': nextCursor,
      };
    }

    return {'success': false, 'operations': [], 'errors': ['HTTP ${response.statusCode}']};
  } catch (e) {
    return {'success': false, 'operations': [], 'errors': [e.toString()]};
  }
}
```

---

## 5. SyncRepository.logOperation() (Writes to sync_outbox)

**File:** `lib/core/repositories/sync_repository.dart:24-46`

```dart
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
          opType: opType.index + 1,    // convert enum to 1,2,3
          data: dataStr,
          createdAt: DateTime.now(),
        ),
      );
}
```

**What it writes to sync_outbox:**
- `idempotencyKey` - unique key for idempotency
- `tenantId`, `companyId`, `deviceId` - context
- `entity` - "products", "categories", etc.
- `entityId` - UUID of the record
- `opType` - 1=insert, 2=update, 3=delete
- `data` - JSON string with all record fields
- `createdAt` - timestamp

---

## 6. Server-Side pushProcessor.ts

**File:** `backend/src/services/pushProcessor.ts:32-175`

### What it does:

```typescript
export async function processPushOperations(
  operations: ValidatedOperation[],
  ctx: SyncContext,
): Promise<AcknowledgedOp[]> {
  // 1. Validate operation count
  // 2. Process ALL in single transaction
  //    - Batch idempotency check
  //    - For each op: validate → resolve refs → apply to entity table
  //    - Write to sync_operations_log  ← FOR OTHER DEVICES TO PULL
  //    - Return acknowledgment (success/failed)
  // 3. COMMIT or ROLLBACK
}
```

### Key Step - Line 155-167: Write to sync_operations_log

```typescript
// ── Step 5: Write to operations_log ─────────────────────
await writeOperationLog({
  client,
  opId: op.opId,
  companyId: ctx.companyId,
  deviceId: ctx.deviceId,
  tableName: op.table,
  recordUuid: op.recordId,
  operation: op.type,         // INSERT, UPDATE, DELETE
  dataOld,
  dataNew,
  timestamp: incomingTimestamp,
});
```

**This is what makes data available to OTHER devices via pull!**

---

## THE ROOT CAUSE ANALYSIS

### Architecture Confusion

There are TWO separate sync systems:

| Component | SyncService (OLD/Active) | SyncEngine (NEW/Disabled) |
|----------|----------------------|----------------------|
| Push source | Entity tables (products etc) with syncStatus=1 | sync_outbox table |
| Status field | `syncStatus` on each entity | `status` on syncOutbox |
| Starts auto | ✅ Yes (service_locator:224) | ❌ Disabled (commented out) |
| Used by | Currently in production | Not used |

### What's Happening Now

1. ✅ Product created → repository calls `syncRepo.logOperation()` → writes to **sync_outbox**
2. ❌ SyncEngine is DISABLED → never reads from sync_outbox
3. ✅ SyncService runs auto-sync every 5 minutes
4. ❌ SyncService.push() looks for `syncStatus = 1` on entity tables → finds NOTHING
5. ❌ "[SYNC][PUSH] No local changes to push."

### Why SyncEngine is Disabled

In `service_locator.dart:166`:
```dart
// DISABLED - Using new SyncService instead, old SyncEngine causes conflicts
// syncEngine.startAutoSync();
```

The comment says "old SyncEngine causes conflicts" - but actually it's the Sync SERVICE that's broken, not SyncEngine!

### The Fix Required

Either:
1. **Enable SyncEngine** and use it properly, OR
2. **Fix SyncService** to use sync_outbox (not syncStatus on entities)

Option 1 is cleaner - enable SyncEngine which already has proper push/pull that writes to sync_outbox.

### What Was Actually Written

Looking at `product_repository.dart:40`:
```dart
await syncRepo.logOperation(
  entity: 'products',
  entityId: product.uuid,
  opType: SyncOpType.insert,
  data: product.toJson(),
);
```

This DOES write to sync_outbox! But SyncEngine which reads from it is disabled.

---

## Summary Diagram

```
Flutter Web App                           Server (VPS)
=================                       =============
                                       
1. Create Product                      
   ↓                                   
2. repo.createProduct()              
   → syncRepo.logOperation()         
   → writes to sync_outbox ✅       
                                    
   ❌ SYNCENGINE DISABLED!           
   (not reading sync_outbox)         
                                    
3. SyncService auto-runs (5 min)     
   → push() looks for: syncStatus=1  
   → finds 0 records ❌             
                                    
4. "[SYNC][PUSH] No local changes" 
                                       

ALTERNATIVE (IF ENABLED):
Flutter            →    sync_outbox    →    Server API
                             ↑             
                        SyncEngine        
                       (reads and        
                        pushes)         
                              ↓
                         server writes to
                         sync_operations_log
                              ↓
                         Other devices
                         can pull
```

---

## The Fix Options

### Option A: Enable SyncEngine (Clean)
```dart
// In service_locator.dart, UNCOMMENT:
syncEngine.startAutoSync();
```

SyncEngine already reads from sync_outbox and has proper push/pull logic.

### Option B: Fix SyncService to use sync_outbox
Make `SyncService.push()` read from `sync_outbox` instead of checking `syncStatus = 1` on entity tables.

Option A is recommended - less code change, SyncEngine is already implemented correctly.