# Ezo POS Sync API Specification

**Version:** 1.0  
**Status:** Implementation Ready  
**Date:** 2026-04-11

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     FLUTTER APP (Drift)                   │
├─────────────────────────────────────────────────────────────┤
│  Domain Tables                                             │
│    - products, invoices, customers, suppliers, etc.          │
├─────────────────────────────────────────────────────────────┤
│  sync_outbox          ← Local pending operations             │
│    - idempotency_key (UUID)                                │
│    - operation (INSERT/UPDATE/DELETE)                       │
│    - table_name                                         │
│    - record_key (UUID)                                   │
│    - payload (JSON: {old, new})                         │
│    - version (client-assigned, will be overridden)           │
│    - client_generated_at (untrusted)                      │
│    - status (pending/acked/rejected)                     │
├─────────────────────────────────────────────────────────────┤
│  sync_inbox          ← Applied remote operations            │
│    - server_operation_id                                 │
│    - operation, table_name, record_key, payload, version     │
├─────────────────────────────────────────────────────────────┤
│  sync_state         ← Cursors & sync state              │
│    - tenant_id                                         │
│    - local_version                                     │
│    - remote_version                                    │
│    - last_ack_version                                  │
├─────────────────────────────────────────────────────────────┤
│  stock_outbox        ← Inventory deltas (separate)       │
│    - product_key                                       │
│    - operation (STOCK_IN/STOCK_OUT/ADJUSTMENT)         │
│    - quantity (signed delta)                             │
│    - reference_type/key                               │
└─────────────────────────────────────────────────────────────┘
                              ↓
                   ┌───────────────┐
                   │  2 ENDPOINTS │
                   └───────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                Node.js Sync API (Stateless)                │
├─────────────────────────────────────────────────────────────┤
│  POST /api/sync              ← Main operations             │
│  POST /api/sync/stock       ← Inventory deltas            │
├─────────────────────────────────────────────────────────────┤
│  PostgreSQL (Source of Truth)                            │
│    - operations_log                                        │
│    - sync_cursors                                      │
│    - stock_ledger                                      │
│    - stock_snapshot                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Hard Limits (Non-Negotiable)

| Limit | Value | Rationale |
|-------|-------|----------|
| Max ops per batch | 500 | Network reliability, retry safety |
| Max compressed payload | ~2MB | Timeout & memory safety |
| Timeout per request | 5 seconds | Mobile network tolerance |
| Inventory batch | 200 ops | Higher frequency, lower risk |
| Compression threshold | 10KB | Gzip benefit vs CPU cost |

**Rule:** If pending > 500 ops → client loops batches until empty.

---

## 1. PostgreSQL Schema

### 1.1 Core Tables

```sql
-- =====================================================
-- OPERATION-BASED SYNC DATABASE SCHEMA
-- =====================================================

-- Extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- CORE: Operations Log (Source of Truth)
-- =====================================================
CREATE TABLE operations_log (
    id BIGSERIAL PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    table_name VARCHAR(50) NOT NULL,
    record_key UUID NOT NULL,
    payload JSONB NOT NULL,
    version BIGINT NOT NULL,
    idempotency_key UUID,
    client_generated_at TIMESTAMPTZ,
    server_generated_at TIMESTAMPTZ DEFAULT NOW(),
    client_id VARCHAR(100),
    
    CONSTRAINT uq_tenant_idem UNIQUE (tenant_id, idempotency_key)
);

-- Indexes for efficient sync queries
CREATE INDEX idx_ops_tenant_version ON operations_log(tenant_id, version);
CREATE INDEX idx_ops_tenant_record ON operations_log(tenant_id, table_name, record_key);

CREATE INDEX idx_ops_version ON operations_log(tenant_id, version);

-- =====================================================
-- Sync Cursors (Per Tenant)
-- =====================================================
CREATE TABLE sync_cursors (
    tenant_id VARCHAR(50) PRIMARY KEY,
    client_id VARCHAR(100),
    last_version_synced BIGINT NOT NULL DEFAULT 0,
    last_ack_version BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INVENTORY: Stock Ledger (Delta-Based, NOT LWW!)
-- =====================================================
CREATE TABLE stock_ledger (
    id BIGSERIAL PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    product_key UUID NOT NULL,
    operation VARCHAR(20) NOT NULL CHECK (operation IN ('STOCK_IN', 'STOCK_OUT', 'ADJUSTMENT', 'TRANSFER')),
    quantity DECIMAL(10, 3) NOT NULL,
    reference_type VARCHAR(50),
    reference_key UUID,
    version BIGINT NOT NULL,
    idempotency_key UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_stock_idem UNIQUE (tenant_id, idempotency_key)
);

CREATE INDEX idx_stock_tenant_product ON stock_ledger(tenant_id, product_key, id);
CREATE INDEX idx_stock_ledger_version ON stock_ledger(tenant_id, version);

-- Materialized snapshot for fast stock queries
CREATE TABLE stock_snapshot (
    tenant_id VARCHAR(50) NOT NULL,
    product_key UUID NOT NULL,
    quantity DECIMAL(10, 3) NOT NULL DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (tenant_id, product_key)
);

-- =====================================================
-- Domain Tables (simplified, tenant_id everywhere)
-- =====================================================

-- Products
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(50) UNIQUE,
    category_key UUID,
    unit_key UUID,
    brand_key UUID,
    price DECIMAL(10, 2) NOT NULL,
    cost DECIMAL(10, 2),
    gst_type VARCHAR(20),
    gst_rate VARCHAR(10),
    stock_quantity INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Categories
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    subcategory VARCHAR(100),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Units
CREATE TABLE units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(50) NOT NULL,
    name VARCHAR(50) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Brands
CREATE TABLE brands (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Customers
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    credit_limit DECIMAL(10, 2) DEFAULT 0,
    current_balance DECIMAL(10, 2) DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Suppliers
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Invoices
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(50) NOT NULL,
    invoice_number VARCHAR(50) NOT NULL,
    customer_key UUID,
    date TIMESTAMPTZ NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    tax DECIMAL(10, 2) NOT NULL,
    discount DECIMAL(10, 2) DEFAULT 0,
    total DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(20),
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Invoice Items
CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(50) NOT NULL,
    invoice_key UUID NOT NULL,
    product_key UUID NOT NULL,
    quantity DECIMAL(10, 3) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    bonus DECIMAL(10, 3) DEFAULT 0,
    discount DECIMAL(10, 2) DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Employees
CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    role VARCHAR(20) DEFAULT 'staff',
    password_hash VARCHAR(255),
    google_auth BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tenant Settings
CREATE TABLE tenant_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    custom_config JSONB,
    footer_message TEXT,
    accent_color VARCHAR(10),
    font_family VARCHAR(50),
    font_size_multiplier DECIMAL(3, 2) DEFAULT 1.0,
    logo_path TEXT,
    thermal_width INTEGER DEFAULT 80,
    show_logo BOOLEAN DEFAULT TRUE,
    show_tax_breakdown BOOLEAN DEFAULT TRUE,
    show_address BOOLEAN DEFAULT TRUE,
    show_customer_details BOOLEAN DEFAULT TRUE,
    show_footer BOOLEAN DEFAULT TRUE,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 1.2 Tenant Isolation Indexes

```sql
-- Create index on tenant_id for all domain tables
CREATE INDEX idx_products_tenant ON products(tenant_id);
CREATE INDEX idx_categories_tenant ON categories(tenant_id);
CREATE INDEX idx_units_tenant ON units(tenant_id);
CREATE INDEX idx_brands_tenant ON brands(tenant_id);
CREATE INDEX idx_customers_tenant ON customers(tenant_id);
CREATE INDEX idx_suppliers_tenant ON suppliers(tenant_id);
CREATE INDEX idx_invoices_tenant ON invoices(tenant_id);
CREATE INDEX idx_invoice_items_tenant ON invoice_items(tenant_id);
CREATE INDEX idx_employees_tenant ON employees(tenant_id);
CREATE INDEX idx_tenant_settings_tenant ON tenant_settings(tenant_id);
```

---

## 2. API Endpoints

### 2.1 Main Sync (PUSH + PULL)

```
POST /api/sync
```

**Authentication:** Bearer token (JWT)  
**Content-Type:** application/json  
**Compression:** gzip (if payload > 10KB)

#### PUSH (Client → Server)

**Request:**
```json
{
  "tenant_id": "t_123",
  "client_id": "device_abc",
  "cursor": 1200,
  "operations": [
    {
      "idempotency_key": "uuid-op-001",
      "operation": "INSERT",
      "table": "products",
      "record_key": "uuid-prod-123",
      "payload": {
        "old": null,
        "new": {
          "id": "uuid-prod-123",
          "name": "Test Product",
          "price": 100.00,
          "sku": "SKU001"
        }
      },
      "version": 1,
      "client_generated_at": "2026-04-11T09:32:21Z"
    }
  ]
}
```

**Response:**
```json
{
  "cursor": 1240,
  "acked": ["uuid-op-001"],
  "rejected": [
    {
      "idempotency_key": "uuid-op-002",
      "reason": "VERSION_CONFLICT",
      "server_version": 1241,
      "current_state": {
        "name": "Updated Name",
        "price": 150.00
      }
    }
  ],
  "server_changes": [
    {
      "id": 1241,
      "operation": "UPDATE",
      "table": "products",
      "record_key": "uuid-prod-456",
      "payload": {
        "old": {"name": "Old"},
        "new": {"name": "New"}
      },
      "version": 1241,
      "server_generated_at": "2026-04-11T10:00:00Z"
    }
  ]
}
```

#### PULL (Server → Client)

**Request:**
```json
{
  "tenant_id": "t_123",
  "cursor": 1200
}
```

**Response:**
```json
{
  "cursor": 1240,
  "operations": [
    {
      "id": 1241,
      "operation": "UPDATE",
      "table": "products",
      "record_key": "uuid-prod-456",
      "payload": {
        "old": {"name": "Old", "price": 100},
        "new": {"name": "New", "price": 150}
      },
      "version": 1241,
      "server_generated_at": "2026-04-11T10:00:00Z"
    }
  ]
}
```

### 2.2 Inventory Sync (Separate)

```
POST /api/sync/stock
```

**Authentication:** Bearer token (JWT)  
**Batch size:** 200 operations (max)

#### PUSH (Stock Deltas)

**Request:**
```json
{
  "tenant_id": "t_123",
  "client_id": "device_abc",
  "operations": [
    {
      "idempotency_key": "uuid-stock-001",
      "operation": "STOCK_OUT",
      "product_key": "uuid-prod-123",
      "quantity": -5,
      "reference_type": "invoice",
      "reference_key": "uuid-inv-456",
      "client_generated_at": "2026-04-11T09:32:21Z"
    }
  ]
}
```

**Response:**
```json
{
  "acked": ["uuid-stock-001"],
  "rejected": [],
  "current_stock": {
    "uuid-prod-123": 95
  }
}
```

#### PULL (Stock Changes)

**Request:**
```json
{
  "tenant_id": "t_123",
  "last_ledger_id": 5000
}
```

**Response:**
```json
{
  "last_ledger_id": 5100,
  "operations": [
    {
      "id": 5001,
      "operation": "STOCK_OUT",
      "product_key": "uuid-prod-123",
      "quantity": -5,
      "reference_type": "invoice",
      "reference_key": "uuid-inv-456",
      "version": 1241,
      "server_generated_at": "2026-04-11T10:00:00Z"
    }
  ]
}
```

---

## 3. Conflict Resolution Policy

### 3.1 Main Data: Server Wins (LWW)

```
Client edits offline (version: 1)
↓
Server has newer version (version: 3)
↓
Client push → VERSION_CONFLICT
↓
Server pushes current state on next pull
↓
Client receives and updates local
```

**Response Code:** 409 Conflict (with current_state)

### 3.2 Inventory: Delta-Based (No Overwrite)

```
Stock = SUM(all deltas for product)
NEVER overwrite stock directly
Only append STOCK_IN/STOCK_OUT/ADJUSTMENT
```

---

## 4. Retry & Idempotency Rules

### 4.1 Client-Side

| Retry Scenario | Action |
|--------------|-------|
| Network timeout | Retry with exponential backoff (1s, 2s, 4s, 8s... max 60s) |
| 5xx Server Error | Retry after delay |
| 429 Rate Limit | Respect Retry-After header |
| VERSION_CONFLICT | Apply server state, retry with new data |

### 4.2 Idempotency

- Every operation has `idempotency_key` (client-generated UUID)
- Server stores (tenant_id, idempotency_key) unique constraint
- Duplicate pushes are safely ignored
- ACKed operations can be safely deleted from local outbox

### 4.3 Hard Limits Enforcement

```javascript
// Server-side validation
const MAX_BATCH_SIZE = 500;
const MAX_STOCK_BATCH = 200;
const MAX_PAYLOAD_SIZE = 2 * 1024 * 1024; // 2MB
const REQUEST_TIMEOUT = 5000; // 5 seconds
```

---

## 5. File Structure (Recommended)

```
pos-sync-server/
├── package.json
├── .env.example
├── src/
│   ├── index.js              # Entry point
│   ├── config/
│   │   └── index.js        # Environment config
│   ├── db/
│   │   ├── index.js        # PostgreSQL connection
│   │   └── migrations/     # SQL migration files
│   ├── middleware/
│   │   └── auth.js        # JWT authentication
│   ├── routes/
│   │   ├── sync.js        # /api/sync
│   │   └── stock.js      # /api/sync/stock
│   └── services/
│       ├── operations.js    # Operations logic
│       └── stock.js     # Stock ledger logic
├── migrations/
│   └── 001_initial.sql
└── docker-compose.yml     # For local dev
```

---

## 6. Implementation Checklist

- [ ] PostgreSQL Schema (operations_log, sync_cursors, stock_ledger, stock_snapshot)
- [ ] PostgreSQL Schema (domain tables with tenant_id)
- [ ] Database indexes for tenant isolation
- [ ] Node.js server setup (Express + pg)
- [ ] JWT authentication middleware
- [ ] POST /api/sync - PUSH handler
- [ ] POST /api/sync - PULL handler
- [ ] POST /api/sync/stock - PUSH handler
- [ ] POST /api/sync/stock - PULL handler
- [ ] Gzip compression (request/response)
- [ ] Batch size validation
- [ ] Idempotency deduplication
- [ ] VERSION_CONFLICT handling
- [ ] Stock ledger aggregation
- [ ] Error responses (4xx, 5xx)
- [ ] Logging & monitoring

---

## 7. Environment Variables

```bash
# .env.example
PORT=5002
NODE_ENV=development

# PostgreSQL
DATABASE_URL=postgresql://user:password@localhost:5432/ezo_sync
DATABASE_POOL_SIZE=10
DATABASE_SSL=false

# Auth
JWT_SECRET=your-secret-key-here

# Limits
MAX_BATCH_SIZE=500
MAX_STOCK_BATCH=200
REQUEST_TIMEOUT=5000
COMPRESSION_THRESHOLD=10240
```

---

## 8. Error Codes

| Code | Meaning | Client Action |
|------|---------|-------------|
| 200 | Success | Apply acked, continue |
| 400 | Bad request | Log error, do not retry |
| 401 | Unauthorized | Re-authenticate |
| 409 | Version conflict | Apply server state |
| 413 | Payload too large | Split batch |
| 429 | Rate limited | Respect Retry-After |
| 500 | Server error | Retry with backoff |

---

## 9. Flutter Integration Points

The Flutter app will need:

1. **New Drift Tables:**
   - `sync_outbox` - pending operations
   - `sync_inbox` - applied operations  
   - `sync_state` - cursors
   - `stock_outbox` - inventory deltas

2. **Sync Service Changes:**
   - Batch operations from outbox
   - Single endpoint calls
   - Exponential backoff retry
   - Gzip compression

3. **Background Sync:**
   - Periodic sync scheduler
   - Network-aware triggering
   - Battery-conscious timing

---

*Last Updated: 2026-04-11*