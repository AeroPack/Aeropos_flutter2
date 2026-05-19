# Phase 5.4: Real PostgreSQL Validation Checklist

## Pre-requisites
- [ ] Node.js sync backend running on port 5002
- [ ] PostgreSQL connected with schema deployed
- [ ] Flutter app builds in debug mode

## Test Scenarios

### 1. Cold Start / Initial Sync
- [ ] Fresh device pulls all existing data
- [ ] Pagination works correctly
- [ ] No memory issues
- [ ] Cursor advances

### 2. Weeks-Offline Device  
- [ ] Go offline (airplane mode)
- [ ] Create 10+ products, categories, customers
- [ ] Create 5+ sales
- [ ] Reconnect
- [ ] Outbox drains completely
- [ ] No duplicates on server

### 3. Multi-Device Concurrent Sales (CRITICAL)
- [ ] Device A: Sell product X (qty=5)
- [ ] Device B: Sell product X (qty=3) at same time
- [ ] Verify stock = initial - 8
- [ ] No double-deduction

### 4. Conflict Resolution (LWW)
- [ ] Update product on Device A
- [ ] Update same product on Device B  
- [ ] Sync both devices
- [ ] Server version wins
- [ ] No retry loop

### 5. Crash Recovery
- [ ] Start sale creation
- [ ] Kill app mid-operation
- [ ] Relaunch app
- [ ] Verify no partial invoices
- [ ] Verify no orphan stock

## Expected Log Patterns (Good)

```
SYNC_START device=...
SYNC_PUSH batches=N ops=N
SYNC_PUSH_OK duration=Nms
SYNC_PULL ops=N
SYNC_DONE status=ok
```

## Red Flags (Investigate if seen)
- [ ] same idempotencyKey processed twice
- [ ] retry without backoff
- [ ] stock goes negative without return
- [ ] cursor jumping backwards

## Results
| Test | Passed | Failed | Notes |
|------|--------|--------|-------|
| Cold Start | [] | [] | |
| Weeks-Offline | [] | [] | |
| Multi-Device | [] | [] | |
| Conflict | [] | [] | |
| Crash Recovery | [] | [] | |