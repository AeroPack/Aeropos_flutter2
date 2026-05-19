import { pool } from '../db/sync-db';

export async function archiveOldOperations(): Promise<number> {
  try {
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
  } catch (err: any) {
    // Table may not exist if migration 009 hasn't run yet — non-fatal.
    if (err?.code === '42P01') {
      console.warn('[archiver] sync_operations_log_archive table not found — skipping (run migration 009)');
      return 0;
    }
    throw err;
  }
}
