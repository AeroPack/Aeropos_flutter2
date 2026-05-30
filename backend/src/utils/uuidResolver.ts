import { PoolClient } from 'pg';
import { ValidTable } from '../validators/sync.validator';
import { TABLE_UUID_REFS } from '../services/entityApplier';

export interface ResolveResult {
  resolved: Record<string, unknown>;
  missingRef?: { clientField: string; uuid: string; targetTable: string };
}

/**
 * Resolves all UUID reference fields in `data` to internal integer IDs.
 * Scoped to companyId for tenant isolation.
 *
 * Optional refs: if the client omits the field or sends null → skip silently.
 * Required refs: if the client sends a value that can't be resolved → FAIL.
 */
export async function resolveUuidRefs(
  client: PoolClient,
  table: ValidTable,
  data: Record<string, unknown>,
  companyId: number,
): Promise<ResolveResult> {
  const refs = TABLE_UUID_REFS[table];
  if (!refs) return { resolved: { ...data } };

  const resolved: Record<string, unknown> = { ...data };

  for (const ref of refs.uuidFields) {
    const { clientField, targetTable, resultField, optional } = ref;
    const uuid = data[clientField];

    // Field absent or null
    if (uuid === undefined || uuid === null) {
      if (optional) {
        // Ensure the target ID field is explicitly set to null (don't leave it undefined)
        resolved[resultField] = null;
        delete resolved[clientField];
      }
      // If required and missing, the Zod validator should have caught it already;
      // but if somehow here, just skip and let the DB NOT NULL constraint catch it.
      continue;
    }

    if (typeof uuid !== 'string') {
      return {
        resolved,
        missingRef: { clientField, uuid: String(uuid), targetTable },
      };
    }

    // Validate UUID format before querying PostgreSQL
    // Prevents "invalid input syntax for type uuid" errors from non-UUID strings
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uuid)) {
      if (optional) {
        resolved[resultField] = null;
        delete resolved[clientField];
        continue;
      }
      return {
        resolved,
        missingRef: { clientField, uuid, targetTable },
      };
    }

    const { rows } = await client.query<{ id: number }>(
      `SELECT id FROM ${targetTable}
       WHERE uuid = $1
         AND company_id = $2
         AND is_deleted = false
       LIMIT 1`,
      [uuid, companyId],
    );

    if (rows.length === 0) {
      if (optional) {
        // Ref provided but target deleted or doesn't exist — set to null gracefully
        resolved[resultField] = null;
        delete resolved[clientField];
        continue;
      }
      // Required ref not found
      return {
        resolved,
        missingRef: { clientField, uuid, targetTable },
      };
    }

    delete resolved[clientField];
    resolved[resultField] = rows[0].id;
  }

  return { resolved };
}
