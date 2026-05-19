-- ============================================================
--  Migration 011: Add purchase_receipts, customer_transactions,
--  supplier_transactions tables for sync support
-- ============================================================

CREATE TABLE IF NOT EXISTS purchase_receipts (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    invoice_number TEXT NOT NULL,
    supplier_invoice_number TEXT,
    supplier_id INTEGER REFERENCES suppliers(id),
    subtotal DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    tax DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    discount DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    total_amount DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    notes TEXT,
    status TEXT DEFAULT 'COMPLETED' NOT NULL,
    created_by TEXT,
    date TIMESTAMP DEFAULT NOW() NOT NULL,
    items JSONB DEFAULT '[]'::jsonb NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS customer_transactions (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    amount DOUBLE PRECISION NOT NULL,
    type TEXT NOT NULL,
    remarks TEXT,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS supplier_transactions (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
    amount DOUBLE PRECISION NOT NULL,
    type TEXT NOT NULL,
    remarks TEXT,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);
