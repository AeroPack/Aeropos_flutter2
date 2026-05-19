# Ezo POS — Flutter App
> Offline-first cross-platform POS. Desktop (Linux/Windows) + mobile target.
> State: Riverpod 2.6.1 | DB: Drift 2.14.0 (SQLite) | Nav: GoRouter 17 | HTTP: Dio

## Architecture (MVVM + Repository)
- View: Flutter widgets in lib/features/<feature>/screens/ and lib/features/<feature>/widgets/
- ViewModel: Riverpod NotifierProvider/AsyncNotifierProvider in lib/features/<feature>/providers/
- Repository: lib/features/<feature>/repositories/ — ALL Drift queries go here, nowhere else
- Model: lib/features/<feature>/models/ — plain Dart classes with fromJson/toJson/copyWith

## THE sync contract (most important rule)
Every syncable entity has TWO ids:
- `id` INTEGER: local Drift autoincrement, NEVER sent to backend
- `uuid` TEXT UNIQUE NOT NULL: the global sync key, always v4 UUID, IS sent to backend
- `updatedAt` DATETIME: set on every write, used for delta sync
- `syncedAt` DATETIME NULLABLE: null = not yet synced, set after successful backend push

Never use `id` in API calls. Always use `uuid`. This is non-negotiable.

## HTTP rule
Use ONLY Dio. The `http` package is in pubspec.yaml but must NOT be used for new code.
All Dio calls go through lib/core/network/api_client.dart (DioClient singleton).
Auth token is injected via DioClient interceptor — never attach manually in a feature.

## DI rule
Use Riverpod providers for DI. ServiceLocator exists for legacy; do NOT create new
ServiceLocator registrations. New code: inject via ref.read(xRepositoryProvider).

## Drift rule
- Tables defined in lib/core/database/tables/
- DAOs in lib/core/database/daos/
- build_runner generates .g.dart files — never edit generated files
- Migrations in lib/core/database/migrations/ — increment schemaVersion in app_database.dart

## File naming
- Screens: snake_case_screen.dart
- Providers: snake_case_provider.dart  
- Repositories: snake_case_repository.dart
- Tables: snake_case_table.dart
- Models: snake_case_model.dart

## GoRouter
Shell routes in lib/core/router/app_router.dart
Route constants in lib/core/router/route_names.dart
Never use Navigator.push directly — always GoRouter.of(context).go()

## Do NOT commit
analysis_output*.txt files — add to .gitignore now