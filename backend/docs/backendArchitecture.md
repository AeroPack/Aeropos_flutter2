# Backend Architecture Documentation

## Table of Contents
1. [High-Level Design (System Overview)](#1-high-level-design-system-overview)
2. [Low-Level Design (Component Details)](#2-low-level-design-component-details)
3. [End-to-End User Data Flow](#3-end-to-end-user-data-flow)
4. [Database Schema & Drizzle ORM](#4-database-schema--drizzle-orm)
5. [Sync Mechanism: Push/Pull with SSE](#5-sync-mechanism-pushpull-with-sse)
6. [YouTube Learning Resources](#6-youtube-learning-resources)

---

## 1. High-Level Design (System Overview)

### 1.1 What is this system?

This is an **offline-first POS (Point of Sale) backend** built with:
- **Express.js** - Web framework
- **PostgreSQL** - Database
- **Drizzle ORM** - Type-safe database queries
- **SSE (Server-Sent Events)** - Real-time push notifications
- **JWT** - Authentication

### 1.2 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           FLUTTER CLIENT (Mobile App)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │   POS UI    │  │  Inventory  │  │   Reports   │  │  Sync Manager   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────┘  │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                    ┌───────────┴────────────┐
                    │   HTTPS / WebSocket   │
                    └───────────┬────────────┘
                                │
┌───────────────────────────────┴─────────────────────────────────────────┐
│                         BACKEND (Express.js)                             │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                        API ROUTES                                   │  │
│  │  /api/auth    /api/products   /api/invoices   /api/sync   /events │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                    │                                     │
│  ┌─────────────────────────────────┴─────────────────────────────────┐   │
│  │                      MIDDLEWARE LAYER                            │   │
│  │  Auth (JWT)  │  Permissions (RBAC)  │  Validation (Zod)          │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                    │                                     │
│  ┌─────────────────────────────────┴─────────────────────────────────┐   │
│  │                       SERVICE LAYER                              │   │
│  │  pushProcessor  │  pullProcessor  │  entityApplier  │ Broadcaster│   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                    │                                     │
│  ┌─────────────────────────────────┴─────────────────────────────────┐   │
│  │                    DATA ACCESS LAYER (Drizzle)                   │   │
│  │  products, categories, invoices, employees, companies, etc.      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                    ┌───────────┴────────────┐
                    │   PostgreSQL Database  │
                    │  ┌──────────────────┐  │
                    │  │  sync_operations │  │
                    │  │      _log         │  │
                    │  └──────────────────┘  │
                    └─────────────────────────┘
```

### 1.3 Key Design Principles

| Principle | Description |
|-----------|-------------|
| **Offline-First** | Flutter app works offline; sync happens when online |
| **UUID-Based** | All records identified by UUID, not integer IDs |
| **Company Isolation** | Every query filters by `company_id` for security |
| **Idempotency** | Same operation can be retried safely |
| **Soft Delete** | Records marked `is_deleted = true` not actually deleted |
| **Last-Write-Wins (LWW)** | Timestamp-based conflict detection |

---

## 2. Low-Level Design (Component Details)

### 2.1 Project Structure

```
backend/
├── src/
│   ├── index.ts                 # Express app entry point
│   ├── config/
│   │   ├── index.ts             # Environment variables
│   │   └── rbac.ts              # Role-based access control
│   ├── db/
│   │   ├── index.ts             # Drizzle DB connection
│   │   ├── schema/              # Table definitions (Drizzle)
│   │   │   ├── products.ts
│   │   │   ├── categories.ts
│   │   │   ├── invoices.ts
│   │   │   └── ...
│   │   ├── migrate.ts           # Database migrations
│   │   └── seed.ts              # Initial data
│   ├── routes/                  # Express routers
│   │   ├── products.ts
│   │   ├── invoices.ts
│   │   ├── sync.ts              # Push/Pull sync
│   │   └── syncEvents.ts        # SSE endpoint
│   ├── services/                 # Business logic
│   │   ├── pushProcessor.ts     # Handle incoming sync ops
│   │   ├── pullProcessor.ts     # Fetch ops for client
│   │   ├── entityApplier.ts      # Apply CRUD to tables
│   │   ├── notificationBroadcaster.ts  # SSE pub/sub
│   │   └── uuid-resolver.ts      # UUID → ID conversion
│   ├── middleware/               # Express middleware
│   │   ├── auth.middleware.ts    # JWT verification
│   │   └── checkPermission.ts    # RBAC checks
│   ├── validators/               # Zod schemas
│   │   └── sync.validator.ts     # Sync request validation
│   └── types/                    # TypeScript interfaces
│       └── sync.types.ts
```

### 2.2 Core Components Explained

#### A. Database Connection (`src/db/index.ts`)

```typescript
// Uses Drizzle ORM with PostgreSQL
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export const db = drizzle(pool, { schema });
```

**What it does:** Connects to PostgreSQL and provides type-safe queries through Drizzle ORM.

---

#### B. Database Schema (`src/db/schema/products.ts`)

```typescript
export const products = pgTable("products", {
  id: serial("id").primaryKey(),           // Internal integer ID
  uuid: uuid("uuid").defaultRandom()       // Client-facing UUID
    .notNull().unique(),
  name: text("name").notNull(),
  categoryId: integer("category_id")        // FK to categories.id
    .references(() => categories.id),
  price: doublePrecision("price").notNull(),
  companyId: integer("company_id")          // CRITICAL: company isolation
    .notNull()
    .references(() => companies.id, { onDelete: "cascade" }),
  isDeleted: boolean("is_deleted").default(false),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});
```

**Key concept:** Each table has:
- `id` - Internal integer primary key (never sent to Flutter)
- `uuid` - Public identifier sent to Flutter client
- `companyId` - **Security boundary** - ensures data isolation
- `isDeleted` - Soft delete flag
- `updatedAt` - For conflict detection in sync

---

#### C. Auth Middleware (`src/middleware/auth.middleware.ts`)

```typescript
export function authMiddleware(req, res, next) {
  // 1. Verify JWT token
  const payload = jwt.verify(token, JWT_SECRET);

  // 2. Validate x-company-id header
  const companyId = Number(req.headers['x-company-id']);

  // 3. Ensure token has access to this company
  if (!payload.company_ids.includes(companyId)) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  // 4. Attach to request for downstream use
  req.companyId = companyId;
  req.employeeId = payload.sub;  // employee UUID

  next();
}
```

**What it does:** Every API request must include:
- `Authorization: Bearer <token>` - JWT
- `x-company-id: <number>` - Which company to access

---

#### D. RBAC (Role-Based Access Control) (`src/config/rbac.ts`)

```typescript
export const getDefaultPermissions = (role: string): string[] => {
  switch (role) {
    case 'admin':
      return allPermissions;  // Everything
    case 'manager':
      return allPermissions.filter(k => k !== 'manage_settings');
    case 'cashier':
      return ['pos_access', 'view_transactions', 'view_dashboard'];
    case 'employee':
      return ['view_dashboard', 'manage_products', ...];
  }
};
```

**Permission keys:** `view_dashboard`, `pos_access`, `manage_products`, `view_transactions`, etc.

---

## 3. End-to-End User Data Flow

### 3.1 Scenario: Flutter user creates a product offline, then syncs

```
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 1: Flutter creates product offline (no internet)                  │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Local SQLite: products table                                     │ │
│  │  { uuid: "abc-123", name: "Chips", price: 10, sync_status: 0 }    │ │
│  │  operations_log: [{ opId: "op-001", type: "INSERT", ... }]        │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼ (Internet becomes available)
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 2: Flutter sends sync request to backend                         │
│  POST /api/sync                                                          │
│  {                                                                       │
│    deviceId: "device-xyz",                                              │
│    lastPulledAt: "2024-01-01T00:00:00Z",                               │
│    operations: [                                                        │
│      {                                                                  │
│        opId: "op-001",                                                  │
│        type: "INSERT",                                                  │
│        table: "products",                                              │
│        recordId: "abc-123",                                            │
│        data: { name: "Chips", price: 10, category_uuid: "cat-001" },   │
│        timestamp: "2024-01-02T10:30:00Z"                               │
│      }                                                                  │
│    ]                                                                    │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 3: Backend processes in multiple layers                           │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │  ROUTE LAYER: sync.ts receives request                          │     │
│  └─────────────────────────────────────────────────────────────────┘     │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │  MIDDLEWARE: auth.middleware validates JWT + companyId         │     │
│  └─────────────────────────────────────────────────────────────────┘     │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │  VALIDATOR: sync.validator validates request schema            │     │
│  └─────────────────────────────────────────────────────────────────┘     │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │  PUSH PROCESSOR: processPushOperations()                       │     │
│  │  1. Checks idempotency (has this opId been processed?)        │     │
│  │  2. Resolves UUID references (category_uuid → category_id)     │     │
│  │  3. Applies to entity table (INSERT products)                  │     │
│  │  4. Writes to sync_operations_log                               │     │
│  └─────────────────────────────────────────────────────────────────┘     │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │  PULL PROCESSOR: fetchPullOperations()                          │     │
│  │  Returns all NEW operations since lastPulledAt                  │     │
│  └─────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 4: Backend responds with acknowledgment                           │
│  {                                                                       │
│    serverTime: "2024-01-02T10:30:01Z",                                 │
│    acknowledged: [{ opId: "op-001", status: "SUCCESS" }],             │
│    operations: [...] // Other company's changes for this company       │
│    nextCursor: "2024-01-02T10:30:01Z"                                  │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 5: Flutter updates local database                                 │
│  - Mark op-001 as synced                                                │
│  - Apply incoming operations from other devices                         │
│  - Update lastPulledAt to nextCursor                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### 3.2 Scenario: Real-time notification via SSE

```
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 1: Flutter connects to SSE endpoint                               │
│  GET /api/sync/events (with Authorization + x-company-id header)         │
│                                                                             │
│  Response:                                                                │
│  Content-Type: text/event-stream                                         │
│  Connection: keep-alive                                                  │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 2: Backend maintains SSE connection                               │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  notificationBroadcaster.ts                                      │    │
│  │  - Subscribes to PostgreSQL LISTEN/NOTIFY channel              │    │
│  │  - Channel name: "sync_company_{companyId}"                     │    │
│  │  - When data changes → sends "data: ping\n\n" to client         │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 3: Another user makes a change                                    │
│  User B creates a new product via /api/products POST                    │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 4: Trigger notification                                           │
│                                                                             │
│  DB writes to sync_operations_log                                        │
│         │                                                                │
│         ▼                                                                │
│  PostgreSQL: NOTIFY "sync_company_1", 'change'                           │
│         │                                                                │
│         ▼                                                                │
│  Broadcaster receives notification                                      │
│         │                                                                │
│         ▼                                                                │
│  All SSE connections for company 1 receive:                             │
│  "data: ping\n\n"                                                       │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 5: Flutter receives ping, triggers sync                          │
│                                                                             │
│  on(data: ping) {                                                        │
│    // Immediately call POST /api/sync to pull latest changes           │
│    syncNow();                                                            │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Database Schema & Drizzle ORM

### 4.1 Multi-Tenancy Model

```
┌─────────────────────────────────────────────────────────────────┐
│                        PostgreSQL                                │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  tenants (optional - currently single tenant)            │   │
│  │  id, uuid, name, plan                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│           │                                                        │
│           │ 1:N                                                  │
│           ▼                                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  companies                                               │   │
│  │  id, uuid, tenant_id, business_name, is_deleted          │   │
│  └──────────────────────────────────────────────────────────┘   │
│           │                                                        │
│           │ 1:N                                                  │
│           ▼                                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  employees  ───  role_permissions                        │   │
│  │  customers  ───  invoices  ───  invoice_items           │   │
│  │  products   ───  categories  ───  units  ───  brands      │   │
│  │  suppliers                                               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  sync_operations_log  ◄── CRITICAL for sync               │   │
│  │  id, op_id, company_id, device_id, table_name,          │   │
│  │  record_uuid, operation, data_old, data_new, timestamp   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 sync_operations_log Table (Heart of Sync)

This is THE most important table for understanding sync:

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Internal ID |
| op_id | UUID | **Idempotency key** - prevents duplicate processing |
| company_id | INT | **Security boundary** - filter by this! |
| device_id | STRING | Which device sent the operation |
| table_name | STRING | Which table (products, invoices, etc.) |
| record_uuid | UUID | The record's public UUID |
| operation | STRING | INSERT, UPDATE, or DELETE |
| data_old | JSONB | Previous state (for conflict resolution) |
| data_new | JSONB | New state (what client should apply) |
| timestamp | TIMESTAMP | **Cursor for pull** - client tracks this |

### 4.3 Drizzle Schema Example

```typescript
// src/db/schema/products.ts
import { pgTable, serial, text, uuid, timestamp, integer, doublePrecision, boolean } from "drizzle-orm/pg-core";
import { companies, categories, units, brands } from "./index";

export const products = pgTable("products", {
  id: serial("id").primaryKey(),
  uuid: uuid("uuid").defaultRandom().notNull().unique(),
  name: text("name").notNull(),
  sku: text("sku").notNull(),
  categoryId: integer("category_id").references(() => categories.id),
  unitId: integer("unit_id").references(() => units.id),
  brandId: integer("brand_id").references(() => brands.id),
  price: doublePrecision("price").notNull(),
  companyId: integer("company_id")
    .notNull()
    .references(() => companies.id, { onDelete: "cascade" }),
  isDeleted: boolean("is_deleted").default(false).notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export type Product = typeof products.$inferSelect;  // For SELECT queries
export type NewProduct = typeof products.$inferInsert;  // For INSERT queries
```

---

## 5. Sync Mechanism: Push/Pull with SSE

### 5.1 How Sync Works (The Complete Picture)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      OFFLINE-FIRST SYNC FLOW                        │
└─────────────────────────────────────────────────────────────────────┘

 PUSH (Flutter → Backend)                    PULL (Backend → Flutter)
 ──────────────────────                      ─────────────────────────

 1. User does action                         1. Timer triggers / SSE ping
    (create product)                           receives "data: ping"
                                                  │
                                                  ▼
 2. Save to local SQLite                   2. Call POST /api/sync
    with opId="uuid-001"                         with lastPulledAt="..."
                                                  │
                                                  ▼
 3. When online, POST to                  3. Backend queries:
    /api/sync with operations                  SELECT * FROM sync_operations_log
    [{ opId, type, table, ... }]               WHERE company_id = X
                                                  AND timestamp > lastPulledAt
                                                  │
                                                  ▼
 4. Backend validates                     4. Returns operations + nextCursor
    - Checks opId not processed              { operations: [...], nextCursor }
    - Converts UUIDs to IDs
    - Applies to database
    - Writes to sync_operations_log
                                                  │
 5. Backend responds with                    ▼
    acknowledged: [{ status }]             5. Flutter applies operations
                                                  - Updates local SQLite
                                                  - Stores nextCursor
```

### 5.2 Push Processor (`src/services/pushProcessor.ts`)

**Purpose:** Process incoming operations from Flutter

```typescript
export async function processPushOperations(operations, ctx) {
  // 1. Validate operation count (max 1000)
  if (operations.length > 1000) {
    return [{ opId: "SYSTEM", status: "FAILED", error: ... }];
  }

  // 2. ALL operations in SINGLE transaction
  return await withTransaction(async (client) => {
    // 3. Batch idempotency check
    const existing = await checkIdempotencyBatch(client, opIds, companyId);

    // 4. Process each operation in order
    for (const op of operations) {
      if (existing.includes(op.opId)) {
        return { opId, status: "DUPLICATE" };  // Already processed
      }

      // 5. Resolve UUID references
      const { resolved } = await resolveUuidRefs(client, table, data, companyId);
      // category_uuid → category_id

      // 6. Apply to entity table
      const { dataOld, dataNew } = await applyToEntityTable(client, op.type, ...);

      // 7. Write to sync_operations_log
      await writeOperationLog({ client, opId, dataOld, dataNew, ... });

      return { opId, status: "SUCCESS" };
    }
  });
}
```

### 5.3 Pull Processor (`src/services/pullProcessor.ts`)

**Purpose:** Fetch operations for Flutter to download

```typescript
export async function fetchPullOperations(companyId, lastPulledAt) {
  // 1. Parse cursor (defaults to epoch if null)
  const cursor = lastPulledAt ? new Date(lastPulledAt) : new Date(0);

  // 2. Query operations since cursor
  const { rows } = await pool.query(
    `SELECT * FROM sync_operations_log
     WHERE company_id = $1 AND timestamp > $2
     ORDER BY timestamp ASC
     LIMIT 500`,
    [companyId, cursor]
  );

  // 3. Convert integer FK IDs to UUIDs for client
  const uuidLookup = await buildUuidLookup(rows);
  const operations = rows.map(row => ({
    opId: row.op_id,
    type: row.operation,
    table: row.table_name,
    recordId: row.record_uuid,
    data: rewriteFkIdsToUuids(row.data_new, row.table_name, uuidLookup),
    timestamp: row.timestamp.toISOString()
  }));

  // 4. Calculate nextCursor (always advances!)
  const nextCursor = operations.length > 0
    ? operations[operations.length - 1].timestamp
    : serverNow;

  return { operations, nextCursor };
}
```

### 5.4 SSE (Server-Sent Events) for Real-Time (`src/routes/syncEvents.ts`)

**Purpose:** Push notification when server data changes

```typescript
router.get('/', authMiddleware, async (req, res) => {
  // Set SSE headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const companyId = req.companyId;
  const channel = `sync_company_${companyId}`;

  // Subscribe to PostgreSQL NOTIFY channel
  const unsubscribe = await broadcaster.subscribe(channel, () => {
    res.write('data: ping\n\n');  // Tell Flutter to sync!
  });

  // Send heartbeat every 25 seconds
  const heartbeat = setInterval(() => {
    res.write(': heartbeat\n\n');
  }, 25000);

  // Cleanup on disconnect
  req.on('close', () => {
    clearInterval(heartbeat);
    unsubscribe();
  });
});
```

---

## 6. YouTube Learning Resources

### 6.1 PostgreSQL & Database Fundamentals

| Video | URL | Description |
|-------|-----|-------------|
| PostgreSQL Tutorial for Beginners | https://www.youtube.com/watch?v=qw--VJLpxhs | Basic SQL, tables, queries |
| PostgreSQL Database Design | https://www.youtube.com/watch?v=pkLVjsgU-5E | Normalization, relationships |
| Understanding Database Indexes | https://www.youtube.com/watch?v=4cWgVLldMRo | Performance optimization |

### 6.2 Drizzle ORM

| Video | URL | Description |
|-------|-----|-------------|
| Drizzle ORM Crash Course | https://www.youtube.com/watch?v=1C1V3p3pT5E | Type-safe queries |
| Drizzle with PostgreSQL | https://www.youtube.com/watch?v=zBSKjkFzF0E | Setup & migrations |

### 6.3 Express.js & REST APIs

| Video | URL | Description |
|-------|-----|-------------|
| Express.js Tutorial | https://www.youtube.com/watch?v=L72fhGm1tfE | Express fundamentals |
| Node.js REST API Design | https://www.youtube.com/watch?v=0oXYL3cMffU | Best practices |

### 6.4 Sync & Real-Time (SSE/WebSockets)

| Video | URL | Description |
|-------|-----|-------------|
| Server-Sent Events (SSE) Tutorial | https://www.youtube.com/watch?v=8EfpPN3kPr4 | SSE basics |
| Building Real-time Apps with SSE | https://www.youtube.com/watch?v=2aAwkN7l9Tw | Practical implementation |
| WebSockets vs SSE | https://www.youtube.com/watch?v=1_2fRWK3O_M | Comparison |
| Offline-First Sync Patterns | https://www.youtube.com/watch?v=X4P6vHbN5wA | Sync strategies |

### 6.5 JWT & Authentication

| Video | URL | Description |
|-------|-----|-------------|
| JWT Authentication in Node.js | https://www.youtube.com/watch?v=mbsmsi7l3r4 | JWT basics |
| Express Authentication Best Practices | https://www.youtube.com/watch?v=EOYkH9eF0K4 | Security |

### 6.6 Complete Full-Stack Tutorials (Recommended)

| Video | URL | Description |
|-------|-----|-------------|
| Build a POS System with Node.js & React | https://www.youtube.com/watch?v=6R4qShEJSvM | Full-stack POS |
| Flutter + Node.js Sync | https://www.youtube.com/watch?v=CNUbHb7a6X8 | Mobile sync patterns |

---

## Quick Reference: Adding a New Entity

When you need to add a new feature (e.g., "expenses"):

1. **Create schema** → `src/db/schema/expenses.ts`
   - Add `companyId`, `uuid`, `isDeleted`, `updatedAt`

2. **Add validator** → `src/validators/sync.validator.ts`
   - Add "expenses" to `VALID_TABLES`

3. **Add UUID reference mapping** → `src/services/entityApplier.ts`
   - Map `expense_uuid` → `expense_id` if needed

4. **Create route** → `src/routes/expenses.ts`
   - GET, POST, PUT, DELETE endpoints

5. **Register in** `src/index.ts`
   - `app.use('/api/expenses', expenseRouter)`

6. **Add permissions** → `src/config/rbac.ts`
   - Add `"manage_expenses"` permission

---

## Summary for Frontend Developer

1. **Everything is UUID-based** - Flutter never sees integer IDs
2. **Company isolation is mandatory** - Every query filters by `company_id`
3. **Sync is bi-directional** - Push (upload local changes) + Pull (download server changes)
4. **SSE keeps you in sync** - Connect once, get pinged when data changes
5. **Timestamps matter** - `updatedAt` is used for conflict detection
6. **Operations are idempotent** - Same `opId` can be safely retried

You're working with a well-architected offline-first system! The sync complexity is handled by the backend - your Flutter app just needs to:
- Store operations locally with UUIDs
- Send them via `/api/sync`
- Listen to `/api/sync/events` for real-time updates