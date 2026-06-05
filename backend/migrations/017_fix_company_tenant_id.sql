-- 017_fix_company_tenant_id.sql
-- Ensure every non-deleted company has a tenant_id assigned.
-- 
-- Priority 1: Inherit from the creator employee's original company
-- Priority 2: Find via shared employee email across companies
-- Priority 3: Create a new tenant for truly orphaned companies

-- Priority 1: Inherit from creator employee's company tenant
UPDATE companies c
SET tenant_id = subq.tenant_id
FROM (
    SELECT c.id AS company_id, c2.tenant_id
    FROM companies c
    JOIN employees e ON e.id = c.created_by_employee_id
    JOIN companies c2 ON c2.id = e.company_id
    WHERE c.tenant_id IS NULL
    AND c.is_deleted = false
    AND c2.tenant_id IS NOT NULL
) subq
WHERE c.id = subq.company_id
AND c.tenant_id IS NULL;

-- Priority 2: For remaining companies, find via shared employee email
UPDATE companies c
SET tenant_id = subq.tenant_id
FROM (
    SELECT DISTINCT ON (c.id) c.id AS company_id, c2.tenant_id
    FROM companies c
    JOIN employees e ON e.company_id = c.id AND e.is_deleted = false
    JOIN employees e2 ON e2.email = e.email AND e2.company_id != c.id AND e2.is_deleted = false
    JOIN companies c2 ON c2.id = e2.company_id
    WHERE c.tenant_id IS NULL
    AND c.is_deleted = false
    AND c2.tenant_id IS NOT NULL
    AND c2.is_deleted = false
) subq
WHERE c.id = subq.company_id
AND c.tenant_id IS NULL;

-- Priority 3: Create new tenants for remaining orphan companies
DO $$
DECLARE
    rec RECORD;
    new_tenant_id INTEGER;
    slug_base TEXT;
BEGIN
    FOR rec IN 
        SELECT id, COALESCE(NULLIF(business_name, ''), 'Company') AS biz_name, uuid 
        FROM companies 
        WHERE tenant_id IS NULL AND is_deleted = false
    LOOP
        slug_base := LOWER(REGEXP_REPLACE(rec.biz_name, '[^a-z0-9]+', '-', 'g'));
        slug_base := REGEXP_REPLACE(slug_base, '(^-|-$)', '', 'g');
        IF slug_base = '' THEN slug_base := 'company'; END IF;

        INSERT INTO tenants (
            external_key, name, slug, status, plan,
            business_name, created_at, updated_at
        )
        VALUES (
            'tenant_' || rec.uuid,
            rec.biz_name,
            slug_base || '-' || EXTRACT(EPOCH FROM NOW()),
            'active',
            'free',
            rec.biz_name,
            NOW(),
            NOW()
        )
        RETURNING id INTO new_tenant_id;

        UPDATE companies 
        SET tenant_id = new_tenant_id 
        WHERE id = rec.id;
    END LOOP;
END $$;
