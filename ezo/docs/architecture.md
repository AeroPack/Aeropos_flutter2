# Ezo POS — Architecture Guide
> Written for a MERN + DevOps engineer stepping into this codebase.  
> Read top-to-bottom once, then use as a reference.

---

## Phase 1 — The Big Picture

### What is this system?

A **Point-of-Sale (POS)** app that works **offline-first**. That means:

- A shopkeeper uses the Flutter app even when the internet is down.
- Every action (add product, make a sale) is written to a **local SQLite database** on the device first.
- When connectivity returns, changes are **synced to the backend** (PostgreSQL).

Think of it like **Google Docs offline mode** — you keep working, it syncs later.

---

### Two Codebases, One System

```
┌──────────────────────────────┐        ┌────────────────────────────────┐
│   FLUTTER APP  (ezo/)        │        │   BACKEND  (backend/)          │
│                              │        │                                │
│  SQLite (Drift)              │◄──────►│  PostgreSQL (Drizzle ORM)      │
│  Riverpod (state)            │  HTTP  │  Express.js routes             │
│  GoRouter (navigation)       │  Dio   │  JWT auth                      │
│  Dio (HTTP client)           │        │  Docker                        │
└──────────────────────────────┘        └────────────────────────────────┘
```

The backend is **vanilla Express + TypeScript** — exactly what you know from MERN,
just with Drizzle instead of Mongoose/Prisma.

---

### MERN → This Stack (Translation Table)

| MERN concept         | This codebase equivalent          | Where it lives                              |
|----------------------|-----------------------------------|---------------------------------------------|
| `mongoose.Schema`    | Drizzle table definition          | `backend/src/db/schema/*.ts`                |
| `mongoose.model()`   | Drizzle `db.select().from(table)` | `backend/src/routes/*.ts`                   |
| `.env`               | Docker `environment:` block       | `backend/docker-compose.yml`                |
| React `useState`     | Riverpod `StateNotifier`          | `lib/features/*/providers/`                 |
| React `useEffect`    | Flutter `StreamBuilder`           | every `*_screen.dart`                       |
| React Context/Redux  | Riverpod Provider                 | `lib/features/*/presentation/providers/`    |
| React Router         | GoRouter                          | `lib/core/router/app_router.dart`           |
| Axios / fetch        | Dio                               | `lib/core/network/dio_client.dart`          |
| Express middleware   | Flutter `AuthInterceptor`         | `lib/core/network/auth_interceptor.dart`    |
| MongoDB document     | Drift `Entity` (generated class)  | `lib/core/database/app_database.g.dart`     |
| Mongoose service     | Repository class                  | `lib/core/repositories/*_repository.dart`  |
| Custom React hook    | ViewModel class                   | `lib/core/viewModel/*_view_model.dart`      |
| npm DI / singletons  | ServiceLocator                    | `lib/core/di/service_locator.dart`          |
| MongoDB Atlas        | PostgreSQL in Docker              | `backend/docker-compose.yml`                |

---

## Phase 2 — Backend Architecture

The backend is a standard Express app. You will feel at home.

### Folder structure

```
backend/src/
├── index.ts              ← app entry (like server.js in MERN)
├── config/               ← env vars, RBAC permission maps
├── db/
│   ├── index.ts          ← Drizzle client (like mongoose.connect())
│   ├── schema/           ← table definitions (like Mongoose schemas)
│   │   ├── categories.ts
│   │   ├── products.ts
│   │   └── ...
│   └── seed.ts           ← runs DB init on startup
├── routes/               ← Express routers (one file per entity)
│   ├── categories.ts
│   ├── products.ts
│   └── sync.ts           ← THE sync endpoint (most important)
├── middleware/
│   ├── auth.ts           ← JWT verify, attach companyId to req
│   └── checkPermission.ts← RBAC guard
├── services/
│   ├── pushProcessor.ts  ← handles client→server changes
│   ├── pullProcessor.ts  ← handles server→client changes
│   └── entityApplier.ts  ← writes a synced row to the DB
├── migrations/           ← raw SQL migration files (run manually)
└── validators/
    └── sync.validator.ts ← Zod schema for sync request body
```

### How auth works on the backend

Every protected route goes through `middleware/auth.ts`:

```
Request
  → JWT verified
  → req.companyId  ← injected from JWT payload
  → req.employeeId ← injected from JWT payload
  → route handler
```

The JWT carries `tenant_id`, `company_id`, `role`. All DB queries are
**scoped to companyId** — one company can never see another company's data.
Identical to how you'd attach `userId` from a JWT in MERN.

### Drizzle ORM (think: Prisma but lighter)

Schema definition:
```typescript
// backend/src/db/schema/categories.ts
export const categories = pgTable("categories", {
  id:        serial("id").primaryKey(),
  uuid:      uuid("uuid").defaultRandom().notNull().unique(),
  name:      text("name").notNull(),
  companyId: integer("company_id").notNull().references(() => companies.id),
  isDeleted: boolean("is_deleted").default(false).notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
```

Query (like Mongoose's `Model.find()`):
```typescript
const rows = await db.select()
  .from(categories)
  .where(and(
    eq(categories.companyId, req.companyId),
    eq(categories.isDeleted, false)
  ));
```

---

## Phase 3 — Flutter App Architecture (MVVM)

This follows **MVVM** — Model, View, ViewModel. Coming from React it maps to:

```
React                     Flutter (this app)
──────────────────────    ──────────────────────────────────────
Component (UI)        →   Screen / Widget  (View)
Custom Hook           →   ViewModel
Redux/Context store   →   Riverpod Provider
API service           →   Repository
MongoDB document      →   Drift Entity (auto-generated class)
Plain JS object       →   Model (plain Dart class, toJson/fromJson)
```

### The MVVM layers

```
┌─────────────────────────────────────────────────────────┐
│  VIEW  — lib/features/<feature>/screens/*.dart           │
│  Renders UI. Reads from ViewModel. Calls ViewModel.      │
│  No business logic here. Ever.                           │
├─────────────────────────────────────────────────────────┤
│  VIEWMODEL  — lib/core/viewModel/*_view_model.dart       │
│  Coordinates between UI and Repository.                  │
│  Exposes Streams the View subscribes to.                 │
│  Like a custom React hook.                               │
├─────────────────────────────────────────────────────────┤
│  REPOSITORY  — lib/core/repositories/*_repository.dart  │
│  All database queries live here. ONLY place.             │
│  Like an Express service that talks to MongoDB.          │
├─────────────────────────────────────────────────────────┤
│  DATABASE TABLES  — lib/core/database/tables/*.dart      │
│  Drift table definitions (like Mongoose schemas).        │
│  build_runner generates *.g.dart from these.             │
├─────────────────────────────────────────────────────────┤
│  MODEL  — lib/core/models/*.dart                         │
│  Pure Dart class. toJson / fromJson. No DB logic.        │
│  Like a plain JS object / DTO.                           │
└─────────────────────────────────────────────────────────┘
```

### ServiceLocator — the DI Container

Because Flutter has no native DI framework, `ServiceLocator` is a hand-rolled
singleton that wires everything together. Think of it like your `app.js` in
Express where you instantiate dependencies and pass them around. It runs once
at app startup (`main.dart → ServiceLocator.initialize()`):

```dart
database          = AppDatabase();             // opens SQLite
dio               = DioClient.createDio();     // Axios equivalent
categoryRepo      = CategoryRepository(db);    // like new CategoryService(db)
categoryViewModel = CategoryViewModel(db, syncEngine);
```

After that, every screen grabs its ViewModel from the locator:
```dart
final _viewModel = ServiceLocator.instance.categoryViewModel;
```

### Riverpod — used only for Auth state

Riverpod in this app is used specifically for **authentication state**. Think of
it like a Redux store that only has one slice — auth. GoRouter watches the auth
stream and redirects to `/login` when the user is unauthenticated:

```dart
final authState = ref.watch(authControllerProvider);
if (authState.status == AuthStatus.authenticated) { ... }
```

### Streams (StreamBuilder) — the React `useEffect` analogy

Drift exposes live database queries as **Dart Streams**. When any row changes
in SQLite, the stream emits automatically and the UI rebuilds. No manual
refetch needed after creating or deleting a record.

```dart
// ViewModel exposes a Stream (like a MongoDB Change Stream):
Stream<List<CategoryEntity>> get allCategories => _database.watchAllCategories();

// Screen subscribes to it (like useEffect that auto-runs on data change):
StreamBuilder<List<CategoryEntity>>(
  stream: _viewModel.allCategories,
  builder: (context, snapshot) {
    final categories = snapshot.data ?? [];
    // automatically re-renders when categories change in SQLite
  },
)
```

### GoRouter — React Router equivalent

```dart
GoRouter(
  initialLocation: '/dashboard',
  redirect: (context, state) {
    // unauthenticated → '/login'
    // authenticated   → allow
  },
  routes: [
    ShellRoute(              // persistent sidebar (like React <Layout>)
      builder: AppShell,
      routes: [
        GoRoute(path: '/categories', builder: CategoryListScreen),
        GoRoute(path: '/products',   builder: ItemListScreen),
      ],
    ),
  ],
)
```

Navigate with `GoRouter.of(context).go('/categories')` — never use `Navigator.push()`.

---

## Phase 4 — The Sync Contract (Most Important Rule)

This is the core architectural decision. Understand it before touching any feature.

### The Dual-ID Problem

Every syncable row has **two ids**:

| Field      | Type | Purpose                           | Sent to backend? |
|------------|------|-----------------------------------|-----------------|
| `id`       | INT  | Local SQLite autoincrement PK     | NEVER           |
| `uuid`     | TEXT | Global unique key (v4 UUID)       | ALWAYS          |

**Why?** Device A creates a category with local `id=1`. Device B also creates a
different category with local `id=1`. When both sync to the server, the server
uses UUIDs to distinguish them. The integer `id` is meaningless outside the
device it was born on.

### syncStatus field (on every table)

```
0 = SYNCED   → green check icon  (safe to assume server has it)
1 = PENDING  → orange upload icon (written locally, not yet pushed)
2 = ERROR    → red icon           (push failed, needs retry)
```

### The Sync Lifecycle

```
User adds a category
       │
       ▼
Written to local SQLite with syncStatus=1 (PENDING)
       │
       ▼
SyncEngine timer fires (every 10 seconds)
       │
       ├──► PUSH: reads all rows where syncStatus=1
       │          POST /api/sync  { operations: [...] }
       │          Server writes to PostgreSQL
       │          Server returns acknowledged op IDs
       │          Flutter marks those rows syncStatus=0 (SYNCED)
       │
       └──► PULL: reads ops since lastPulledAt
                  Server returns all other devices' changes
                  Flutter upserts them into local SQLite
                  Other devices' changes appear in real time
```

### The sync endpoint shape

```
POST /api/sync
Body: {
  deviceId:     "device-uuid",
  lastPulledAt: "2026-05-07T10:00:00Z",
  operations: [
    { opId:"uuid", type:"INSERT", table:"categories",
      recordId:"cat-uuid", data:{name:"Drinks",...}, timestamp:"..." }
  ]
}
Response: {
  serverTime:   "2026-05-07T10:00:05Z",
  acknowledged: ["opId1", "opId2"],    ← which pushes succeeded
  operations:   [...],                 ← server's changes for this client
  nextCursor:   "2026-05-07T10:00:05Z"
}
```

---

## Phase 5 — The Category List: End-to-End Walkthrough

This is one complete feature traced through every layer. Use it as the
template when understanding or adding any feature.

### Files involved

```
BACKEND
├── backend/src/db/schema/categories.ts          ← DB table definition
├── backend/src/routes/categories.ts             ← REST CRUD endpoints
└── backend/src/services/pullProcessor.ts        ← sync pull logic

FLUTTER
├── lib/core/database/tables/categories_table.dart    ← local SQLite schema
├── lib/core/models/category.dart                     ← plain Dart DTO
├── lib/core/database/app_database.dart               ← Drift DB class
├── lib/core/repositories/category_repository.dart   ← all DB queries
├── lib/core/viewModel/category_view_model.dart       ← bridge: UI ↔ DB
├── lib/core/di/service_locator.dart                  ← DI wiring
└── lib/features/inventory/categories/
    └── category_list_screen.dart                     ← UI
```

---

### Step 1 — Drift Table (Flutter side schema, like Mongoose schema)

```dart
// lib/core/database/tables/categories_table.dart
class Categories extends Table {
  IntColumn get id         => integer().autoIncrement()();    // LOCAL only
  TextColumn get uuid      => text().unique()();              // sync key
  TextColumn get name      => text()();
  BoolColumn get isDeleted => boolean().withDefault(Constant(false))();
  IntColumn  get syncStatus=> integer().withDefault(Constant(0))();
}
```

After you define this, run:
```bash
flutter pub run build_runner build
```
This generates `CategoryEntity` class and all query helpers in `app_database.g.dart`.
You **never edit** `.g.dart` files — they are like Prisma's generated client.

---

### Step 2 — Model (plain DTO)

```dart
// lib/core/models/category.dart
class Category {
  final int    id;
  final String uuid;
  final String name;
  final bool   isDeleted;

  factory Category.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
}
```

No DB logic, no HTTP logic. Pure data. Equivalent to a TypeScript interface.

---

### Step 3 — Repository (DB queries — the ONLY place)

```dart
// lib/core/repositories/category_repository.dart
class CategoryRepository {
  Stream<List<Category>> watchAllCategories() {
    return (_database.select(_database.categories)
          ..where((t) => t.isDeleted.equals(false)))
        .watch()   // ← reactive, like a MongoDB Change Stream
        .map((entities) => entities.map(_mapToDomain).toList());
  }

  Future<int> createCategory(Category category) async {
    return _database.transaction(() async {
      // 1. Write to SQLite
      final id = await _database.into(_database.categories).insert(companion);
      // 2. Log to sync outbox so SyncEngine knows to push this
      await syncRepo.logOperation(entity:'categories', opType:SyncOpType.insert, ...);
      return id;
    });
  }
}
```

---

### Step 4 — ViewModel (orchestrates UI ↔ Repository)

```dart
// lib/core/viewModel/category_view_model.dart
class CategoryViewModel {
  final AppDatabase  _database;
  final ISyncService _syncService;   // SyncEngine implements this interface

  // The screen subscribes to this stream
  Stream<List<CategoryEntity>> get allCategories => _database.watchAllCategories();

  Future<void> addCategory({required String name}) async {
    await _database.insertCategory(CategoriesCompanion(
      uuid:       Value(Uuid().v4()),
      name:       Value(name),
      syncStatus: Value(1),          // PENDING — sync engine picks it up
    ));
  }

  Future<void> syncPendingCategories() async => _syncService.push();
  Future<void> fetchAndSync()           async => _syncService.pull();
}
```

---

### Step 5 — Screen (pure UI, no logic)

```dart
// lib/features/inventory/categories/category_list_screen.dart
class _CategoryListScreenState extends State<CategoryListScreen> {
  // DI: grab ViewModel from the service locator
  final _viewModel = ServiceLocator.instance.categoryViewModel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoryEntity>>(
      stream: _viewModel.allCategories,   // live SQLite query
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];
        // render table — re-renders automatically on any DB change
      },
    );
  }

  void _onAddPressed() {
    showDialog(builder: (ctx) => CategoryFormDialog(
      onSubmit: (name, desc) async {
        await _viewModel.addCategory(name: name);
        // no setState needed — stream fires automatically
      },
    ));
  }
}
```

---

### Step 6 — Backend REST endpoint

```typescript
// backend/src/routes/categories.ts
categoryRouter.get("/", async (req: AuthRequest, res) => {
  const rows = await db.select().from(categories)
    .where(and(
      eq(categories.companyId, req.companyId),   // scoped to this company
      eq(categories.isDeleted, false)
    ));
  res.json(rows);
});
```

The Flutter `SyncEngine` calls this as part of `pull()`. The ViewModel does
NOT call this directly — it only reads local SQLite.

---

### Full Data Flow Diagram

```
User taps "Add Category"
         │
         ▼
CategoryListScreen._onAddPressed()
         │ calls
         ▼
CategoryViewModel.addCategory(name)
         │ writes to SQLite syncStatus=1
         ▼
AppDatabase.insertCategory()  [Drift → SQLite file on device]
         │
         │◄── StreamBuilder auto-rebuilds UI immediately ──┐
         │                                                 │
         │  (background, every 10 seconds)                 │
         ▼                                                 │
SyncEngine.push()                                         │
  reads all syncStatus=1 rows                             │
  POST /api/sync  [Dio → Express backend]                 │
         │                                                 │
         ▼                                                 │
Backend pushProcessor.ts                                  │
  upserts into PostgreSQL categories table                │
  returns acknowledged op IDs                             │
         │                                                 │
         ▼                                                 │
SyncEngine marks rows syncStatus=0 in SQLite  ────────────┘
         │  (stream fires, sync icon turns green)
         ▼
SyncEngine.pull()
  fetches ops since lastPulledAt
  receives other devices' new categories
  upserts them into local SQLite
  (stream fires, other devices' data appears)
```

---

## Phase 6 — Learning Roadmap

You know MERN so you already have ~60% of this. Focus on the gaps:

### Week 1 — Dart/Flutter basics
- Dart null safety: `?`, `!`, `??`, `late`
- `async`/`await` and `Stream` — this is your most important concept
- `StatelessWidget` vs `StatefulWidget`
- `StreamBuilder` and `FutureBuilder`
- **Resource:** dart.dev/language + flutter.dev/learn

### Week 2 — Riverpod (auth state management)
- `Provider`, `StateNotifierProvider`
- `ref.watch` (reactive) vs `ref.read` (one-shot)
- Read `lib/features/auth/presentation/providers/auth_controller.dart`

### Week 3 — Drift (local SQLite ORM)
- How `Table` subclasses define the schema
- What `build_runner` generates — never edit `.g.dart`
- `.get()` (one-shot fetch) vs `.watch()` (reactive stream)
- Read `lib/core/database/app_database.dart`

### Week 4 — The Sync Engine
- Read `lib/core/services/sync_engine.dart` end to end
- Read `backend/src/services/pushProcessor.ts` and `pullProcessor.ts`
- Understand the `sync_operations_log` table on the backend
- SyncOpType: INSERT=1, UPDATE=2, DELETE=3

### Before adding any feature, ask yourself:
1. Does this entity sync? → add `uuid` + `syncStatus` + `isDeleted` columns
2. Where does the DB query live? → ONLY in the Repository
3. Where does business logic live? → ONLY in the ViewModel
4. Am I using `Navigator.push()`? → Use `GoRouter.of(context).go()` instead
5. Am I using the `http` package? → Use Dio through `DioClient` instead
6. Am I adding to ServiceLocator for a NEW feature? → Use Riverpod instead

---

## Quick Reference

### Add a new entity end-to-end checklist

```
Flutter side:
  1. lib/core/database/tables/<entity>_table.dart     ← Drift table
  2. flutter pub run build_runner build               ← regenerate .g.dart
  3. lib/core/models/<entity>.dart                    ← plain DTO
  4. lib/core/database/app_database.dart              ← add table + migration
  5. lib/core/repositories/<entity>_repository.dart  ← DB queries
  6. lib/core/viewModel/<entity>_view_model.dart      ← orchestration
  7. lib/core/di/service_locator.dart                 ← register VM + repo
  8. lib/features/.../<entity>_list_screen.dart       ← UI
  9. lib/core/router/app_router.dart                  ← add route

Backend side:
  10. backend/src/db/schema/<entity>.ts               ← Drizzle schema
  11. backend/src/routes/<entity>.ts                  ← Express CRUD
  12. backend/src/index.ts                            ← register router
  13. backend/migrations/00N_<entity>.sql             ← DB migration
```

### Key files cheat sheet

| What you want                  | File                                                  |
|-------------------------------|-------------------------------------------------------|
| Change base API URL            | `lib/config/app_config.dart`                         |
| Add a new screen               | `lib/features/<name>/screens/`                       |
| Add a new route                | `lib/core/router/app_router.dart`                    |
| Add a DB table (Flutter)       | `lib/core/database/tables/`                          |
| Change sync interval           | `lib/core/services/sync_engine.dart` → SYNC_INTERVAL |
| Add a backend route            | `backend/src/routes/` + register in `index.ts`       |
| Add/change a DB column         | `backend/src/db/schema/` + new migration SQL file    |
| RBAC permissions               | `backend/src/config/permissions.ts`                  |
| Auth / JWT logic               | `backend/src/routes/auth.ts`                         |
| Token storage / auth check     | `lib/features/auth/data/repositories/`               |
