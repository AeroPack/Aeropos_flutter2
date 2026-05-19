import { pool } from '../db/sync-db';
import { OutboundOperation, OperationType } from '../types/sync.types';
import { TABLE_UUID_REFS } from './entityApplier';
import { ValidTable } from '../validators/sync.validator';

const PULL_LIMIT = 500;

// Server-managed columns that must NEVER be sent to the client.
// `id`, `company_id` are server-internal; `deleted_at` mirrors `is_deleted`.
const STRIPPED_COLUMNS = new Set(['id', 'company_id', 'deleted_at']);

/**
 * Replace integer FK ids in a row with the corresponding child uuids,
 * using the precomputed lookup map. Mutates and returns the row.
 *
 * Per the sync contract: clients never see server-side integer ids.
 * They get the uuid (`category_uuid`, `unit_uuid`, …) and resolve it
 * to their own local FK id.
 */
function rewriteFkIdsToUuids(
  row: Record<string, unknown>,
  table: string,
  uuidLookup: Map<string, Map<number, string>>,
): Record<string, unknown> {
  const refs = TABLE_UUID_REFS[table as ValidTable];
  if (!refs) return row;

  for (const ref of refs.uuidFields) {
    const idVal = row[ref.resultField];
    delete row[ref.resultField];

    if (typeof idVal === 'number') {
      const uuid = uuidLookup.get(ref.targetTable)?.get(idVal);
      if (uuid) {
        row[ref.clientField] = uuid;
      } else {
        // Referenced row missing (e.g. hard-deleted) — leave field absent
        // so the client treats it as null rather than carrying a stale id.
      }
    }
  }
  return row;
}

/**
 * Strip server-internal columns from a data row before sending to the client.
 */
function stripServerColumns(row: Record<string, unknown>): Record<string, unknown> {
  for (const col of STRIPPED_COLUMNS) {
    delete row[col];
  }
  return row;
}

/**
 * Build a `targetTable -> Map<id, uuid>` lookup covering every FK id
 * referenced by `rows`. One SELECT per target table; resolves all
 * relevant ids in a single round trip per table.
 */
async function buildUuidLookup(
  rows: PullRow[],
): Promise<Map<string, Map<number, string>>> {
  const idsByTable = new Map<string, Set<number>>();

  for (const row of rows) {
    const refs = TABLE_UUID_REFS[row.table_name as ValidTable];
    if (!refs || !row.data_new) continue;

    for (const ref of refs.uuidFields) {
      const val = row.data_new[ref.resultField];
      if (typeof val === 'number') {
        let set = idsByTable.get(ref.targetTable);
        if (!set) {
          set = new Set<number>();
          idsByTable.set(ref.targetTable, set);
        }
        set.add(val);
      }
    }
  }

  const lookup = new Map<string, Map<number, string>>();

  for (const [targetTable, ids] of idsByTable) {
    if (ids.size === 0) continue;
    const idArray = [...ids];
    // targetTable values come from a hard-coded TABLE_UUID_REFS map,
    // not user input — safe to interpolate.
    const { rows: lookupRows } = await pool.query<{ id: number; uuid: string }>(
      `SELECT id, uuid FROM ${targetTable} WHERE id = ANY($1)`,
      [idArray],
    );
    const m = new Map<number, string>();
    for (const r of lookupRows) m.set(r.id, r.uuid);
    lookup.set(targetTable, m);
  }

  return lookup;
}

interface PullResult {
  operations: OutboundOperation[];
  nextCursor: string;
}

interface PullRow {
  op_id: string;
  operation: OperationType;
  table_name: string;
  record_uuid: string;
  data_new: Record<string, unknown> | null;
  timestamp: Date;
}

/**
 * Production-grade pull processor.
 *
 * Key improvements:
 * 1. Enforced max operations limit (prevent memory issues)
 * 2. Proper cursor-based pagination
 * 3. Scoped to company_id (security)
 * 4. Only returns NEW updates (not already synced)
 * 5. Ordered by timestamp for consistent results
 *
 * BUG FIX: nextCursor now always advances to server's current time
 * even when 0 operations are returned. Previously it echoed back
 * lastPulledAt, causing the Flutter client to re-request from the
 * same epoch on every poll and never make progress.
 */
export async function fetchPullOperations(
  companyId: number,
  lastPulledAt: string,
): Promise<PullResult> {
  // Validate inputs
  if (!companyId || companyId <= 0) {
    console.error(`[pullProcessor] Invalid companyId: ${companyId}`);
    return { operations: [], nextCursor: new Date().toISOString() };
  }

  // Parse cursor
  let cursor: Date;
  try {
    cursor = lastPulledAt ? new Date(lastPulledAt) : new Date(0);
    if (isNaN(cursor.getTime())) {
      cursor = new Date(0);
    }
  } catch {
    cursor = new Date(0);
  }

  // Clients more than 30 days behind have missed archived rows.
  // Tell them to wipe local state and re-sync from scratch.
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  if (cursor < thirtyDaysAgo && cursor.getTime() !== 0) {
    console.warn(
      `[pullProcessor] companyId=${companyId} cursor too old ` +
        `(${cursor.toISOString()}) — sending FULL_RESYNC_REQUIRED`,
    );
    return {
      operations: [
        {
          opId: 'system',
          type: 'FULL_RESYNC_REQUIRED' as any,
          table: 'system' as any,
          recordId: 'system',
          data: null,
          timestamp: new Date().toISOString(),
        },
      ],
      nextCursor: new Date().toISOString(),
    };
  }

  // Capture server time BEFORE query so the cursor is consistent
  // with what was visible in the DB at query time. Any write that
  // lands after this moment will have a timestamp > serverNow and
  // will be picked up on the next pull.
  const serverNow = new Date().toISOString();

  // Query for operations after cursor
  const { rows } = await pool.query<PullRow>(
    `SELECT
      op_id,
      operation,
      table_name,
      record_uuid,
      data_new,
      timestamp
    FROM sync_operations_log
    WHERE company_id = $1
      AND timestamp > $2
    ORDER BY timestamp ASC
    LIMIT $3`,
    [companyId, cursor, PULL_LIMIT],
  );

  // Build FK id -> uuid lookup so we can rewrite each operation's
  // `data` to use uuids instead of server-internal integer ids.
  const uuidLookup = await buildUuidLookup(rows);

  // Map to outbound operations.
  // Each row's `data_new` is sanitized: FK integer ids become child uuids,
  // server-internal columns (`id`, `company_id`, `deleted_at`) are stripped.
  const operations: OutboundOperation[] = rows.map((row) => {
    let data: Record<string, unknown> | null = null;
    if (row.data_new) {
      // Clone so we don't mutate the row reference (PG rows are reused).
      data = { ...row.data_new };
      data = rewriteFkIdsToUuids(data, row.table_name, uuidLookup);
      data = stripServerColumns(data);
    }
    return {
      opId: row.op_id,
      type: row.operation,
      table: row.table_name,
      recordId: row.record_uuid,
      data,
      timestamp: row.timestamp.toISOString(),
    };
  });

  // BUG FIX: Always advance the cursor.
  //
  // Old behaviour:
  //   let nextCursor = lastPulledAt;          // ← echoes back the OLD value
  //   if (operations.length > 0) {
  //     nextCursor = operations[...].timestamp;
  //   }
  //
  // When operations.length === 0 the client received the same cursor
  // it sent, saved it, and repeated the same request forever.
  //
  // New behaviour:
  //   - If we got rows, use the last row's timestamp (safe — we've
  //     already read everything up to that point).
  //   - If we got zero rows, use serverNow (captured before the query).
  //     The client will next ask for anything after serverNow, which is
  //     correct: there was nothing between the old cursor and now.
  let nextCursor: string;
  if (operations.length > 0) {
    nextCursor = operations[operations.length - 1].timestamp;
  } else {
    nextCursor = serverNow;
  }

  console.log(
    `[pullProcessor] companyId=${companyId} pulled=${operations.length} ` +
    `from=${cursor.toISOString()} nextCursor=${nextCursor}`,
  );

  return { operations, nextCursor };
}