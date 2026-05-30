-- ============================================================================
-- Migration: 015_full_schema_sync_alignment.sql
-- Purpose: Add all missing columns and tables for Flutter ↔ Backend sync alignment
-- Safety: Additive only (no breaking changes for live production)
-- ============================================================================

-- ============================================================================
-- TENANTS: Add business-info columns from Flutter
-- ============================================================================
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS business_name TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS business_address TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS tax_id TEXT;

-- ============================================================================
-- INVOICES: Add missing columns from Flutter
-- ============================================================================
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'PENDING';
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS transaction_id TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS deleted_by INTEGER;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS delete_reason TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_invoices_is_deleted ON invoices(is_deleted) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_invoices_payment_status ON invoices(payment_status);

-- ============================================================================
-- INVOICE_ITEMS: Add missing columns from Flutter
-- ============================================================================
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS returned_quantity DOUBLE PRECISION NOT NULL DEFAULT 0.0;
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW() NOT NULL;

CREATE INDEX IF NOT EXISTS idx_invoice_items_is_deleted ON invoice_items(is_deleted) WHERE is_deleted = false;

-- ============================================================================
-- PRODUCTS: Add missing columns from Flutter
-- ============================================================================
ALTER TABLE products ADD COLUMN IF NOT EXISTS base_unit_id INTEGER;
ALTER TABLE products ADD COLUMN IF NOT EXISTS allow_loose_sale BOOLEAN NOT NULL DEFAULT true;

-- ============================================================================
-- CATEGORIES: Add missing columns from Flutter
-- ============================================================================
ALTER TABLE categories ADD COLUMN IF NOT EXISTS description TEXT;

-- ============================================================================
-- CUSTOMERS: Add missing columns from Flutter
-- ============================================================================
ALTER TABLE customers ADD COLUMN IF NOT EXISTS gstin TEXT;

-- ============================================================================
-- INVOICE_SETTINGS: Add all missing customization columns from Flutter
-- ============================================================================
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS logo_path TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS logo_local_path TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS logo_bytes TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS thermal_width INTEGER NOT NULL DEFAULT 80;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS show_logo BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS show_tax_breakdown BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS show_bank_details BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS show_upi_qr BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS bank_name TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS bank_account_no TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS bank_ifsc TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS upi_id TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS custom_config TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS tax_label TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS tax_rate DOUBLE PRECISION;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS terms_and_conditions TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS authorized_signatory TEXT;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS invoice_counter INTEGER NOT NULL DEFAULT 0;
ALTER TABLE invoice_settings ADD COLUMN IF NOT EXISTS invoice_prefix TEXT NOT NULL DEFAULT 'INV';

-- ============================================================================
-- NEW TABLES
-- ============================================================================

-- Purchase Receipt Items
CREATE TABLE IF NOT EXISTS purchase_receipt_items (
    id SERIAL PRIMARY KEY,
    receipt_id INTEGER NOT NULL REFERENCES purchase_receipts(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity DOUBLE PRECISION NOT NULL,
    unit_id INTEGER NOT NULL REFERENCES units(id),
    price DOUBLE PRECISION NOT NULL,
    total_price DOUBLE PRECISION NOT NULL,
    discount_per_item DOUBLE PRECISION,
    tax_per_item DOUBLE PRECISION,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_pr_items_receipt ON purchase_receipt_items(receipt_id);

-- Returns
CREATE TABLE IF NOT EXISTS returns (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    original_invoice_id INTEGER NOT NULL REFERENCES invoices(id),
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    created_by INTEGER NOT NULL,
    refund_amount DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    refund_method TEXT DEFAULT 'wallet' NOT NULL,
    notes TEXT,
    new_sale_id INTEGER,
    restock BOOLEAN DEFAULT true NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_returns_company ON returns(company_id) WHERE is_deleted = false;

-- Return Items
CREATE TABLE IF NOT EXISTS return_items (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    return_id INTEGER NOT NULL REFERENCES returns(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity DOUBLE PRECISION NOT NULL,
    unit_price DOUBLE PRECISION NOT NULL,
    condition TEXT DEFAULT 'good' NOT NULL,
    restock BOOLEAN DEFAULT true NOT NULL,
    original_invoice_item_id INTEGER,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_return_items_return ON return_items(return_id);

-- Wallet Transactions
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    amount DOUBLE PRECISION NOT NULL,
    type TEXT NOT NULL,
    reference_type TEXT NOT NULL,
    reference_id INTEGER,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_wallet_customer ON wallet_transactions(customer_id);

-- Invoice Audit Logs
CREATE TABLE IF NOT EXISTS invoice_audit_logs (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    invoice_id INTEGER NOT NULL REFERENCES invoices(id),
    action_type TEXT NOT NULL,
    performed_by INTEGER NOT NULL,
    performed_at TIMESTAMP DEFAULT NOW() NOT NULL,
    version_number INTEGER NOT NULL,
    changes TEXT NOT NULL,
    summary_snapshot TEXT,
    reason TEXT,
    metadata TEXT,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_log_invoice ON invoice_audit_logs(invoice_id);

-- Inventory Movements
CREATE TABLE IF NOT EXISTS inventory_movements (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity DOUBLE PRECISION NOT NULL,
    type TEXT NOT NULL,
    reference_id INTEGER,
    performed_by INTEGER,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_inv_movements_product ON inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_inv_movements_type ON inventory_movements(type);

-- Reserved SKUs
CREATE TABLE IF NOT EXISTS reserved_skus (
    id SERIAL PRIMARY KEY,
    sku TEXT NOT NULL UNIQUE,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_used BOOLEAN DEFAULT false NOT NULL,
    reserved_at TIMESTAMP DEFAULT NOW() NOT NULL,
    used_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_reserved_skus_company ON reserved_skus(company_id);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 'Migration 015 applied' AS status;
