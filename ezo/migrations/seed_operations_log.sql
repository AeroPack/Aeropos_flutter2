-- Seed operations_log from existing data
-- This populates the operations_log for initial sync

-- Invoices
INSERT INTO operations_log (tenant_id, operation, table_name, record_key, payload, version, company_id, client_generated_at, server_generated_at)
SELECT 
  '7' as tenant_id,
  'INSERT' as operation,
  'invoices' as table_name,
  uuid as record_key,
  jsonb_build_object(
    'id', id,
    'invoice_number', invoice_number,
    'company_id', company_id
  ) as payload,
  1 as version,
  company_id,
  created_at as client_generated_at,
  created_at as server_generated_at
FROM invoices 
WHERE company_id = 7
ON CONFLICT DO NOTHING;

-- Products
INSERT INTO operations_log (tenant_id, operation, table_name, record_key, payload, version, company_id, client_generated_at, server_generated_at)
SELECT 
  '7' as tenant_id,
  'INSERT' as operation,
  'products' as table_name,
  uuid as record_key,
  jsonb_build_object(
    'id', id,
    'name', name,
    'company_id', company_id
  ) as payload,
  1 as version,
  company_id,
  created_at as client_generated_at,
  created_at as server_generated_at
FROM products 
WHERE company_id = 7
ON CONFLICT DO NOTHING;

-- Customers
INSERT INTO operations_log (tenant_id, operation, table_name, record_key, payload, version, company_id, client_generated_at, server_generated_at)
SELECT 
  '7' as tenant_id,
  'INSERT' as operation,
  'customers' as table_name,
  uuid as record_key,
  jsonb_build_object(
    'id', id,
    'name', name,
    'company_id', company_id
  ) as payload,
  1 as version,
  company_id,
  created_at as client_generated_at,
  created_at as server_generated_at
FROM customers 
WHERE company_id = 7
ON CONFLICT DO NOTHING;

-- Verify
SELECT table_name, company_id, COUNT(*) 
FROM operations_log 
GROUP BY table_name, company_id
ORDER BY table_name;