-- ============================================================
--  Backfill sync_operations_log with all existing entity data.
--
--  WHY: The sync pull processor only reads from sync_operations_log.
--  Data added via REST API routes or direct DB seeding is never
--  written to this log, so Flutter clients receive 0 operations
--  on their first pull and see empty screens after login.
--
--  HOW: For each entity table, insert one INSERT operation per
--  existing row that does not yet have an entry in the log.
--  The pullProcessor will strip server-internal columns (id,
--  company_id, deleted_at) and rewrite integer FK ids to UUIDs
--  before sending the data to the Flutter client — so we store
--  the raw row data here (same format as pushProcessor does).
--
--  SAFE TO RE-RUN: WHERE NOT EXISTS guards prevent duplicates.
-- ============================================================

-- ── categories ────────────────────────────────────────────────
INSERT INTO sync_operations_log
  (op_id, company_id, device_id, table_name, record_uuid, operation, data_old, data_new, timestamp)
SELECT
  gen_random_uuid(),
  c.company_id,
  'system-backfill',
  'categories',
  c.uuid,
  'INSERT',
  NULL,
  to_jsonb(c),
  COALESCE(c.updated_at, c.created_at, NOW())
FROM categories c
WHERE NOT EXISTS (
  SELECT 1 FROM sync_operations_log sol
  WHERE sol.table_name = 'categories'
    AND sol.record_uuid = c.uuid
    AND sol.company_id  = c.company_id
);

-- ── units ─────────────────────────────────────────────────────
INSERT INTO sync_operations_log
  (op_id, company_id, device_id, table_name, record_uuid, operation, data_old, data_new, timestamp)
SELECT
  gen_random_uuid(),
  u.company_id,
  'system-backfill',
  'units',
  u.uuid,
  'INSERT',
  NULL,
  to_jsonb(u),
  COALESCE(u.updated_at, u.created_at, NOW())
FROM units u
WHERE NOT EXISTS (
  SELECT 1 FROM sync_operations_log sol
  WHERE sol.table_name = 'units'
    AND sol.record_uuid = u.uuid
    AND sol.company_id  = u.company_id
);

-- ── brands ────────────────────────────────────────────────────
INSERT INTO sync_operations_log
  (op_id, company_id, device_id, table_name, record_uuid, operation, data_old, data_new, timestamp)
SELECT
  gen_random_uuid(),
  b.company_id,
  'system-backfill',
  'brands',
  b.uuid,
  'INSERT',
  NULL,
  to_jsonb(b),
  COALESCE(b.updated_at, b.created_at, NOW())
FROM brands b
WHERE NOT EXISTS (
  SELECT 1 FROM sync_operations_log sol
  WHERE sol.table_name = 'brands'
    AND sol.record_uuid = b.uuid
    AND sol.company_id  = b.company_id
);

-- ── products (has FK refs: category_id, unit_id, brand_id) ───
INSERT INTO sync_operations_log
  (op_id, company_id, device_id, table_name, record_uuid, operation, data_old, data_new, timestamp)
SELECT
  gen_random_uuid(),
  p.company_id,
  'system-backfill',
  'products',
  p.uuid,
  'INSERT',
  NULL,
  to_jsonb(p),
  COALESCE(p.updated_at, p.created_at, NOW())
FROM products p
WHERE NOT EXISTS (
  SELECT 1 FROM sync_operations_log sol
  WHERE sol.table_name = 'products'
    AND sol.record_uuid = p.uuid
    AND sol.company_id  = p.company_id
);

-- ── customers ─────────────────────────────────────────────────
INSERT INTO sync_operations_log
  (op_id, company_id, device_id, table_name, record_uuid, operation, data_old, data_new, timestamp)
SELECT
  gen_random_uuid(),
  c.company_id,
  'system-backfill',
  'customers',
  c.uuid,
  'INSERT',
  NULL,
  to_jsonb(c),
  COALESCE(c.updated_at, c.created_at, NOW())
FROM customers c
WHERE NOT EXISTS (
  SELECT 1 FROM sync_operations_log sol
  WHERE sol.table_name = 'customers'
    AND sol.record_uuid = c.uuid
    AND sol.company_id  = c.company_id
);

-- ── suppliers ─────────────────────────────────────────────────
INSERT INTO sync_operations_log
  (op_id, company_id, device_id, table_name, record_uuid, operation, data_old, data_new, timestamp)
SELECT
  gen_random_uuid(),
  s.company_id,
  'system-backfill',
  'suppliers',
  s.uuid,
  'INSERT',
  NULL,
  to_jsonb(s),
  COALESCE(s.updated_at, s.created_at, NOW())
FROM suppliers s
WHERE NOT EXISTS (
  SELECT 1 FROM sync_operations_log sol
  WHERE sol.table_name = 'suppliers'
    AND sol.record_uuid = s.uuid
    AND sol.company_id  = s.company_id
);

-- ── employees ─────────────────────────────────────────────────
INSERT INTO sync_operations_log
  (op_id, company_id, device_id, table_name, record_uuid, operation, data_old, data_new, timestamp)
SELECT
  gen_random_uuid(),
  e.company_id,
  'system-backfill',
  'employees',
  e.uuid,
  'INSERT',
  NULL,
  to_jsonb(e),
  COALESCE(e.updated_at, e.created_at, NOW())
FROM employees e
WHERE NOT EXISTS (
  SELECT 1 FROM sync_operations_log sol
  WHERE sol.table_name = 'employees'
    AND sol.record_uuid = e.uuid
    AND sol.company_id  = e.company_id
);

-- ── invoices (has FK ref: customer_id) ────────────────────────
INSERT INTO sync_operations_log
  (op_id, company_id, device_id, table_name, record_uuid, operation, data_old, data_new, timestamp)
SELECT
  gen_random_uuid(),
  i.company_id,
  'system-backfill',
  'invoices',
  i.uuid,
  'INSERT',
  NULL,
  to_jsonb(i),
  COALESCE(i.updated_at, i.created_at, NOW())
FROM invoices i
WHERE NOT EXISTS (
  SELECT 1 FROM sync_operations_log sol
  WHERE sol.table_name = 'invoices'
    AND sol.record_uuid = i.uuid
    AND sol.company_id  = i.company_id
);
