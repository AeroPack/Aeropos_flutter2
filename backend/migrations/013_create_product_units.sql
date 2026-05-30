-- ============================================================
--  Migration 013: Add product_units table for multi-unit barcode
--  sync support
-- ============================================================

CREATE TABLE IF NOT EXISTS product_units (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    unit_id INTEGER NOT NULL REFERENCES units(id),
    conversion_factor DOUBLE PRECISION DEFAULT 1.0 NOT NULL,
    selling_price DOUBLE PRECISION,
    barcode TEXT,
    is_default BOOLEAN DEFAULT false NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);
