---
name: drift-entity
description: Generate a complete Drift entity for Ezo POS. Use when adding a new syncable
  data model. Creates: Drift table with uuid sync fields, DAO, Repository class, Dart model
  with fromJson/toJson, and Riverpod provider. Follows the dual-id sync contract.
allowed-tools: Read, Write, Bash
---

## Context
@lib/core/database/app_database.dart
@lib/core/database/tables/

## Current schema version
!`grep -n "schemaVersion" lib/core/database/app_database.dart | head -3`

## Existing tables (for reference)
!`ls lib/core/database/tables/`

## Task
Generate a complete Drift entity for: $ARGUMENTS

Create these files:
1. `lib/core/database/tables/<name>_table.dart` — Drift table with:
   - `id` IntColumn autoIncrement primary key
   - `uuid` TextColumn unique not null (default: const UuidTextConverter())
   - `createdAt` DateTimeColumn withDefault now
   - `updatedAt` DateTimeColumn withDefault now
   - `syncedAt` DateTimeColumn nullable
   - All domain-specific columns per entity

2. `lib/core/database/daos/<name>_dao.dart` — Drift DAO with:
   - watchAll() → Stream
   - getAll() → Future<List>
   - getByUuid(String uuid) → Future<nullable>
   - upsertByUuid(Companion) → Future<int>
   - deleteSoftByUuid(String uuid) — sets is_active = false if entity has it

3. `lib/features/<name>/models/<name>_model.dart` — Pure Dart model:
   - All fields final
   - fromJson / toJson (for API sync — use uuid not id)
   - fromDrift constructor (maps from Drift data class)
   - copyWith

4. `lib/features/<name>/repositories/<name>_repository.dart` — Repository:
   - Inject AppDatabase via constructor
   - watchAll() → proxies to DAO
   - syncFromRemote(List<Map>) — upserts list received from backend API
   - getUnsyncedUuids() → finds records where syncedAt is null
   - markSynced(List<String> uuids)

5. `lib/features/<name>/providers/<name>_provider.dart` — Riverpod:
   - repositoryProvider (Provider<NameRepository>)
   - listProvider (StreamProvider<List<NameModel>>)
   - AsyncNotifier for mutations

After generating: remind to increment schemaVersion in app_database.dart and run:
`dart run build_runner build --delete-conflicting-outputs`