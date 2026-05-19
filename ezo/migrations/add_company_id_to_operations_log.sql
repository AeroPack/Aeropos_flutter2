-- Migration: Add company_id to operations_log for multi-tenant filtering
-- Run this on your PostgreSQL database

-- 1. Add company_id column if it doesn't exist
ALTER TABLE operations_log 
ADD COLUMN IF NOT EXISTS company_id INTEGER;

-- 2. Create index for fast filtering
CREATE INDEX IF NOT EXISTS idx_ops_company_id ON operations_log(company_id);

-- 3. Backfill existing data (if there's historical data)
-- This updates existing operations_log rows with company_id from their related tables

-- For invoices:
UPDATE operations_log op
SET company_id = inv.company_id
FROM invoices inv
WHERE op.entity = 'invoice'
  AND op.entity_id = inv.id
  AND op.company_id IS NULL;

-- For products:
UPDATE operations_log op
SET company_id = p.company_id
FROM products p
WHERE op.entity = 'product'
  AND op.entity_id = p.id
  AND op.company_id IS NULL;

-- For customers:
UPDATE operations_log op
SET company_id = c.company_id
FROM customers c
WHERE op.entity = 'customer'
  AND op.entity_id = c.id
  AND op.company_id IS NULL;

-- For categories:
UPDATE operations_log op
SET company_id = cat.company_id
FROM categories cat
WHERE op.entity = 'category'
  AND op.entity_id = cat.id
  AND op.company_id IS NULL;

-- For units:
UPDATE operations_log op
SET company_id = u.company_id
FROM units u
WHERE op.entity = 'unit'
  AND op.entity_id = u.id
  AND op.company_id IS NULL;

-- For brands:
UPDATE operations_log op
SET company_id = b.company_id
FROM brands b
WHERE op.entity = 'brand'
  AND op.entity_id = b.id
  AND op.company_id IS NULL;

-- 4. Verify
SELECT entity, company_id, COUNT(*) 
FROM operations_log 
WHERE company_id IS NOT NULL 
GROUP BY entity, company_id;