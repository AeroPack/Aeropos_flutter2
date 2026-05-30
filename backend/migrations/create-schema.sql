-- Complete schema creation for fresh database
-- This creates all tables from scratch with the multi-company architecture
-- Matches the Drizzle ORM schema definitions in src/db/schema/

CREATE TABLE IF NOT EXISTS companies (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    business_name TEXT NOT NULL,
    business_address TEXT,
    tax_id TEXT,
    phone TEXT,
    email TEXT,
    logo_url TEXT,
    created_by_employee_id INTEGER,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    password TEXT,
    phone TEXT,
    address TEXT,
    position TEXT,
    salary DOUBLE PRECISION,
    role TEXT DEFAULT 'employee' NOT NULL,
    avatar_url TEXT,
    google_auth BOOLEAN DEFAULT false NOT NULL,
    is_owner BOOLEAN DEFAULT false NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_email_verified BOOLEAN DEFAULT false NOT NULL,
    email_verification_token TEXT,
    email_verification_expires TIMESTAMP,
    password_reset_token TEXT,
    password_reset_expires TIMESTAMP,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL,
    UNIQUE(email, company_id)
);

CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL,
    name TEXT NOT NULL,
    subcategory TEXT,
    is_active BOOLEAN DEFAULT true NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS units (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL,
    name TEXT NOT NULL,
    symbol TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS brands (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    name TEXT NOT NULL,
    sku TEXT,
    hsn TEXT,
    category_id INTEGER REFERENCES categories(id),
    unit_id INTEGER REFERENCES units(id),
    brand_id INTEGER REFERENCES brands(id),
    type TEXT,
    pack_size TEXT,
    price DOUBLE PRECISION NOT NULL,
    cost DOUBLE PRECISION,
    stock_quantity INTEGER DEFAULT 0 NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    gst_type TEXT,
    gst_rate TEXT,
    image_url TEXT,
    description TEXT,
    discount DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    is_percent_discount BOOLEAN DEFAULT false NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT,
    credit_limit DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    current_balance DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS suppliers (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_deleted BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS invoices (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    invoice_number TEXT NOT NULL,
    customer_id INTEGER REFERENCES customers(id),
    date TIMESTAMP DEFAULT NOW() NOT NULL,
    subtotal DOUBLE PRECISION NOT NULL,
    tax DOUBLE PRECISION NOT NULL,
    discount DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    total DOUBLE PRECISION NOT NULL,
    sign_url TEXT,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS invoice_items (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    invoice_id INTEGER REFERENCES invoices(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    bonus INTEGER DEFAULT 0 NOT NULL,
    unit_price DOUBLE PRECISION NOT NULL,
    discount DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    total_price DOUBLE PRECISION NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS invoice_settings (
    id SERIAL PRIMARY KEY,
    business_name TEXT NOT NULL,
    layout TEXT NOT NULL,
    footer_message TEXT NOT NULL,
    accent_color TEXT NOT NULL,
    font_family TEXT NOT NULL,
    font_size_multiplier DOUBLE PRECISION NOT NULL,
    show_address BOOLEAN DEFAULT true NOT NULL,
    show_customer_details BOOLEAN DEFAULT true NOT NULL,
    show_footer BOOLEAN DEFAULT true NOT NULL,
    business_phone TEXT,
    business_address TEXT,
    business_gstin TEXT,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    hex_color TEXT NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    due_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS role_permissions (
    id SERIAL PRIMARY KEY,
    role TEXT NOT NULL,
    permission TEXT NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    UNIQUE(role, permission, company_id)
);

-- Ensure missing columns exist in existing tables (for legacy updates)
ALTER TABLE employees ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS created_by_employee_id INTEGER;
ALTER TABLE employees DROP CONSTRAINT IF EXISTS employees_email_unique;

-- Missing columns on tenants
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS business_name TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS business_address TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS tax_id TEXT;

-- Missing columns on invoices
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'PENDING';
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS transaction_id TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS deleted_by INTEGER;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS delete_reason TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

-- Missing columns on invoice_items
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS returned_quantity DOUBLE PRECISION NOT NULL DEFAULT 0.0;
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW() NOT NULL;

-- Missing columns on products
ALTER TABLE products ADD COLUMN IF NOT EXISTS base_unit_id INTEGER;
ALTER TABLE products ADD COLUMN IF NOT EXISTS allow_loose_sale BOOLEAN NOT NULL DEFAULT true;

-- Missing columns on categories
ALTER TABLE categories ADD COLUMN IF NOT EXISTS description TEXT;

-- Missing columns on customers
ALTER TABLE customers ADD COLUMN IF NOT EXISTS gstin TEXT;

-- Missing columns on invoice_settings
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

-- Purchase Receipts
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

-- Customer Transactions
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

-- Supplier Transactions
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

-- =====================================================
-- New Tables for Full Sync Alignment
-- =====================================================

-- Purchase Receipt Items (separate from JSONB items in purchase_receipts)
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

-- Reserved SKUs
CREATE TABLE IF NOT EXISTS reserved_skus (
    id SERIAL PRIMARY KEY,
    sku TEXT NOT NULL UNIQUE,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_used BOOLEAN DEFAULT false NOT NULL,
    reserved_at TIMESTAMP DEFAULT NOW() NOT NULL,
    used_at TIMESTAMP
);

