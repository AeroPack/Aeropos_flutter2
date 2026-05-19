-- ============================================================================
-- Migration: 006_tenants_is_deleted.sql
-- Purpose: Add is_deleted flag to tenants; verify seeded owner account
-- Safety: Additive only (no breaking changes)
-- Created: 2026-05-07
-- ============================================================================

-- ============================================================================
-- PHASE A: ADD is_deleted TO tenants
-- ============================================================================
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_tenants_active ON tenants(is_deleted) WHERE is_deleted = false;

-- ============================================================================
-- PHASE B: MARK OWNER ACCOUNT AS EMAIL-VERIFIED
-- ============================================================================
UPDATE employees
SET is_email_verified = true
WHERE email = 'chandanapack@gmail.com';

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 'Migration 006 applied' AS status;
SELECT
    e.email,
    e.is_email_verified,
    t.is_deleted IS NOT NULL AS tenants_has_is_deleted
FROM employees e
CROSS JOIN (SELECT is_deleted FROM tenants LIMIT 1) t
WHERE e.email = 'chandanapack@gmail.com';
