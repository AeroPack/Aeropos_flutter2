# AeroPOS Audit Report

**Date:** 2026-06-29
**Scope:** Full static code analysis + manual test plan
**Codebase:** 295 Dart files, 32 DB tables, 17 feature modules, Node.js backend
**Auditor:** First Mate (automated code review)

---

## Executive Summary

| Severity | Count |
|----------|-------|
| Critical | 4 |
| High | 8 |
| Medium | 12 |
| Low | 6 |

The application is functional but carries significant technical debt from rapid iteration. The most impactful issues are: a hardcoded production API URL that affects all environments, duplicate POS screen implementations, dead code, and inconsistent state management patterns. The recent responsive refactor addressed 8 of 74+ hardcoded width instances.

---

## 1. Critical Bugs & Broken Features

### 1.1 Hardcoded Production API URL in All Environments
**File:** `lib/config/app_config.dart:6-30`
**Impact:** Debug mode, web, Android emulator, and production all hit `https://flutterbackend.aeropackpos.in/`. The commented-out localhost URLs are never used. The `environment` field (line 40-43) exists but is never consulted for URL selection.
**Evidence:**
```dart
if (kDebugMode) {
  if (kIsWeb) {
    // return 'http://localhost:5004/';
    return 'https://flutterbackend.aeropackpos.in/';  // <-- always production
  }
  // ... same for Android, desktop, fallback
}
return 'https://flutterbackend.aeropackpos.in/';  // <-- production
```
**Risk:** Developers unknowingly hit production database during local development. Data corruption risk.

### 1.2 Duplicate POS Screen Implementations
**Files:**
- `lib/features/pos/pos_screen.dart` (1978 lines) - the active version
- `lib/features/sales/screens/pos_screen.dart` (1493 lines) - older fork

Both independently define `HeldOrder` (lines 39-53) and `HeldOrdersNotifier` (lines 55-86) with identical structure. The sales variant has 7 commented-out imports (lines 24-30) that were replaced with package-style imports. Neither file imports the other.
**Risk:** Confusion about which is canonical. Changes to one won't propagate to the other. The sales variant appears to be dead code but still compiles.

### 1.3 Dead CartNotifier in Sales Module
**File:** `lib/features/sales/state/cart_notifier.dart` (128 lines)
**Impact:** Defines `CartItem` (wrapping a `Product` model) and `CartNotifier` (extends `ChangeNotifier`). Grep confirms nothing imports this file. The active cart system is at `lib/features/pos/state/cart_state.dart` using Riverpod `StateNotifier`.
**Risk:** Maintenance burden. Developers may误 import the wrong CartItem.

### 1.4 Placeholder Reports Screen
**Route:** `/reports` in `lib/core/router/app_router.dart`
**Impact:** Maps to a placeholder widget with no implementation. Users navigating to Reports see an empty or stub screen.

---

## 2. High-Severity Issues

### 2.1 Unsafe Dynamic Casts (15 locations)
**Worst offender:** `lib/features/pos/layouts/compact_layout.dart:712-714`
```dart
try { price = (product as dynamic).price?.toDouble() ?? 0.0; } catch (_) {}
try { stock = (product as dynamic).stock ?? (product as dynamic).quantity ?? 0; } catch (_) {}
try { imageUrl = (product as dynamic).imageUrl ?? (product as dynamic).image; } catch (_) {}
```
The `product` parameter is already typed as `ProductEntity`. These dynamic casts silently produce zero/null values on failure with no logging. Other locations:
- `core/repositories/base_repository.dart:25,30`
- `core/viewModel/product_view_model.dart:202,204`
- `core/database/app_database.dart:207`
- `core/services/sync_service.dart:1203,1205,1206`
- `features/employees/employee_list_screen.dart:476`
- `features/invoice/invoice_template_editor/template_repository.dart:226,227`
- `core/widgets/employee_form_dialog.dart:55`

### 2.2 Silent Error Swallowing (24 locations)
Empty `catch (_) {}` blocks that discard errors with no logging:

| File | Lines |
|------|-------|
| `core/widgets/table_export_actions.dart` | 152, 164, 180 |
| `config/app_config.dart` | 19 |
| `core/services/sync_service.dart` | 997, 1432 |
| `core/database/app_database.dart` | 574, 695 |
| `features/profile/presentation/screens/company_profile_screen.dart` | 85 |
| `features/inventory/products/add_product_screen.dart` | 517 |
| `features/pos/layouts/compact_layout.dart` | 712, 713, 714 |

### 2.3 Mixed State Management (3 patterns)
The codebase uses three competing patterns:
- **Riverpod StateNotifier** (newer): `CartNotifier`, `AuthController`, `InvoiceNotifier`, `ProfileController`, `PosLayoutNotifier`, `ReturnSettingsNotifier`, `SalesHistoryNotifier`
- **Legacy ChangeNotifier** (older): `CustomerTransactionViewModel`, `SupplierTransactionViewModel`, and the dead `CartNotifier` in sales/
- **Raw ServiceLocator**: All ViewModels in `core/viewModel/` (7 classes) reach directly into the global singleton

### 2.4 Sync Engine Duplication
Two sync implementations coexist:
- `SyncEngine` (`core/services/sync_engine.dart`) - active, outbox-based
- `SyncService` (`core/services/sync_service.dart`) - deprecated, flag-based, 1400+ lines

The deprecated `SyncService` is still referenced in `service_locator.dart` and has its own inline timeout values (`Duration(seconds: 15/30/35)`) that differ from `SyncEngine`'s (`Duration(seconds: 10)`).

### 2.5 Unused AppConstants Sync Interval
**File:** `core/constants/app_constants.dart:11`
```dart
static const Duration syncInterval = Duration(minutes: 15);
```
Neither sync system uses this value:
- `sync_service.dart:215` defaults to `Duration(minutes: 5)`
- `sync_engine.dart:16` uses `Duration(seconds: 10)`

### 2.6 Suppressed Warnings (13 instances)
| File | Warning |
|------|---------|
| `core/layout/pos_design_system.dart:56` | `use_null_aware_elements` |
| `core/layout/app_shell.dart:616` | `use_null_aware_elements` |
| `core/di/service_locator.dart:248` | `invalid_use_of_protected_member` |
| `core/database/app_database.dart:230` | `avoid_print` |
| 9 l10n files | `unused_import` |

The `invalid_use_of_protected_member` in `service_locator.dart` is a structural issue - SyncEngine is reinitialized through a protected member because there is no proper public API for credential rotation.

---

## 3. Medium-Severity Issues

### 3.1 Remaining Hardcoded Widths (66 instances post-refactor)

#### Form Dialogs (not yet responsive)
| File | Width | Context |
|------|-------|---------|
| `core/widgets/employee_form_dialog.dart:150` | 520 | Dialog |
| `core/widgets/customer_form_dialog.dart:113` | 500 | Dialog |
| `core/widgets/supplier_form_dialog.dart:99` | 500 | Dialog |

Note: `core/widgets/brand_form_dialog.dart` already uses `ConstrainedBox(maxWidth: 500)` - good pattern to follow.

#### POS Layouts
| File | Lines | Widths |
|------|-------|--------|
| `pos/layouts/retail_layout.dart` | 137, 203, 477, 1137 | 350, 360, 160, 100 |
| `pos/layouts/restaurant_layout.dart` | 104 | 420 |
| `pos/widgets/quantity_dialog_with_unit.dart` | 32 | 380 |
| `pos/widgets/invoice_audit_history_dialog.dart` | 17 | 600 |
| `sales/screens/invoice_preview_screen.dart` | 60 | 800 |
| `sales/screens/pos_screen.dart` | 309 | 420 |

#### Shared Widgets
| File | Width | Context |
|------|-------|---------|
| `core/widgets/pos_toast.dart:96` | 320 | Toast |
| `core/widgets/pos_calculator.dart:119` | 320 | Calculator |
| `core/widgets/master_header.dart:145` | 350 | Search dropdown |

#### Other Screens
| File | Lines | Widths |
|------|-------|--------|
| `stock_mgmt/inventory_dashboard_screen.dart` | 269, 501 | 180, 200 |
| `ledger/customer_ledger/customer_ledger.dart` | 360, 541 | 180, 200 |
| `ledger/supplier_ledger/supplier_ledger.dart` | 402, 586 | 180, 200 |
| `settings/screens/role_settings_screen.dart` | 210 | 250 |
| `invoice/invoice_template_editor/selection_screen.dart` | 223 | 240 |
| `barcode/screens/barcode_generation_screen.dart` | 897 | 150 |

### 3.2 Magic Numbers / Timeout Inconsistencies
Timeouts are scattered as inline values with no centralized constants:

| Location | Value | Used For |
|----------|-------|----------|
| `core/network/auth_interceptor.dart:20,29` | 5s | Auth token refresh |
| `core/network/dio_client.dart:10-11` | 10s | HTTP connect/receive |
| `core/services/sync_service.dart:195-196` | 10s | Sync operations |
| `core/services/sync_service.dart:509-514` | 15s, 30s, 35s | Sync retry stages |
| `core/services/sync_engine.dart:16` | 10s | Sync interval |
| `core/services/sync_engine.dart:85-86` | 5s, 10s | Push/pull timeouts |
| `features/auth/presentation/providers/auth_controller.dart:113,411` | 8s | Auth operations |
| `features/pos/widgets/quick_add_product_dialog.dart:32-33` | 5s | OpenFoodFacts API |

### 3.3 Package Name Mismatch
The project directory is named `ezo/` but all imports use `package:aeropos/...`. This means `pubspec.yaml` declares `name: aeropos` while the folder is `ezo`. Not a bug, but causes confusion during navigation.

### 3.4 Dead Code Blocks
| File | Lines | Content |
|------|-------|---------|
| `pos/widgets/common/cart_item_tile.dart` | 369+ | `// TODO: Uncomment when needed` + ~25 lines |
| `employees/employee_list_screen.dart` | 646 | `// TODO: Uncomment when needed` |
| `customers/customer_list_screen.dart` | 685 | `// TODO: Uncomment when needed` |
| `pos/layouts/compact_layout.dart` | 5 | Commented-out import |
| `inventory/categories/add_category_screen.dart` | 4 | Commented-out import of non-existent `pos_text_input.dart` |

### 3.5 External API URLs Hardcoded
| File | URL |
|------|-----|
| `pos/widgets/quick_add_product_dialog.dart:38` | `https://world.openfoodfacts.org/api/v0/product/...` |
| `invoice/screens/invoice_template_editor_screen.dart:64-107,239` | 6 Unsplash image URLs |

### 3.6 Empty Database Tables
Three stub table files exist with no implementation:
- `core/database/tables/stock_table.dart`
- `core/database/tables/purchase_table.dart`
- `core/database/tables/purchase_item_table.dart`

---

## 4. Low-Severity Issues

### 4.1 Localization Files with Suppressed Warnings
All 9 l10n generated files (`app_localizations_*.dart`) suppress `unused_import` at line 1.

### 4.2 Excessive Debug Logging in Production Code
100+ `debugPrint` and `print` statements across:
- `core/services/sync_service.dart` (heaviest)
- `features/auth/presentation/providers/auth_controller.dart`
- `core/services/session_service.dart`

### 4.3 Inconsistent Error Toast Patterns
Some screens use `PosToast.showError()`, others use `ScaffoldMessenger.of(context).showSnackBar()`, and some use both in the same flow.

### 4.4 No AGENTS.md
The project has no `AGENTS.md` file for AI agent context, unlike the firstmate template.

### 4.5 Missing Responsive Treatment on Auth Screens
The `signup_screen.dart`, `forgot_password_screen.dart`, and `reset_password_screen.dart` were updated with `ConstrainedBox(maxWidth: 400)` but the `login_screen.dart` was not included in this batch.

### 4.6 Invoice Template Editor Has Hardcoded Unsplash URLs
Six image URLs in `invoice_template_editor_screen.dart` (lines 64-107) point to Unsplash. These will break if the images are removed or rate-limited.

---

## 5. Manual Test Plan

### Pre-conditions
- Backend running at the configured API URL
- Test account with email verification completed
- At least one company created
- Test data: products, categories, units, brands, customers, suppliers

---

### Module 1: Authentication
**Route:** `/login`, `/signup`, `/forgot-password`, `/reset-password`, `/verify-email`, `/select-company`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 1.1 | Navigate to `/signup`, fill all fields, submit | Account created, redirected to verification pending | - |
| 1.2 | Click "Sign up with Google" | Google OAuth flow initiates | Requires Google OAuth configured in backend |
| 1.3 | Navigate to `/login`, enter valid credentials | Redirected to `/select-company` or `/dashboard` | - |
| 1.4 | Enter invalid credentials | Error snackbar shown | - |
| 1.5 | Click "Forgot Password" on login | Navigates to `/forgot-password` | - |
| 1.6 | Submit email on forgot password | Success message: "Check your inbox" | Backend must send email |
| 1.7 | Click reset link from email | Navigates to `/reset-password?token=...` | - |
| 1.8 | Submit new password | Success, redirected to `/login` | - |
| 1.9 | Login with unverified email | Redirected to `/verify-pending` | - |
| 1.10 | On `/select-company`, pick a company | Redirected to `/dashboard` with company context | - |
| 1.11 | Resize window to < 600px on signup/forgot/reset | Form shrinks, padding reduces, no overflow | Recently fixed |
| 1.12 | Test on mobile keyboard open (signup) | No overflow from keyboard | SingleChildScrollView present |

---

### Module 2: Dashboard
**Route:** `/dashboard`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 2.1 | Navigate to dashboard after login | Dashboard loads with summary cards | - |
| 2.2 | Click navigation items in sidebar/shell | Correct routes navigate | Verify all 18 AppShell routes work |
| 2.3 | Check dashboard on compact width | Layout adapts | Not verified in this audit |

---

### Module 3: POS (Point of Sale)
**Route:** `/pos` (standalone, outside AppShell)

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 3.1 | Open POS screen | Default layout loads (based on `posLayoutProvider`) | - |
| 3.2 | Switch between layouts (Compact/Retail/Restaurant/Touch/Dual) | Layout switches correctly | - |
| 3.3 | Search products | Product list filters | - |
| 3.4 | Tap product to add to cart | Product added with default quantity 1 | - |
| 3.5 | Multi-unit product: tap product | `QuantityWithUnitDialog` appears | - |
| 3.6 | Change quantity in cart | Total updates | - |
| 3.7 | Apply item discount (percentage) | Discount applied, total recalculates | - |
| 3.8 | Apply item discount (fixed amount) | Discount applied | - |
| 3.9 | Remove item discount | Discount cleared | - |
| 3.10 | Apply overall discount | Cart total updates | - |
| 3.11 | Hold order | Order saved to `heldOrdersProvider`, cart cleared | - |
| 3.12 | Recall held order | Items restored to cart | - |
| 3.13 | Split bill dialog | Split count adjustable, amounts calculated | - |
| 3.14 | Checkout (save) | Sale created, invoice preview shown | - |
| 3.15 | Print receipt (no save) | Invoice preview with PDF generated | - |
| 3.16 | Add customer during checkout | Customer created and selected | - |
| 3.17 | Compact layout: product card `as dynamic` casts | **BUG RISK:** Price/stock/image may silently be 0/null if `ProductEntity` fields don't match dynamic access pattern | `compact_layout.dart:712-714` |
| 3.18 | Item discount dialog on compact width | Dialog width may overflow on narrow screens | `pos_screen.dart:309` hardcoded `width: 420` |

---

### Module 4: Inventory Management
**Routes:** `/inventory`, `/inventory/add`, `/inventory/view`, `/category-list`, `/unit-list`, `/brand-list`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 4.1 | View product list | Products load from local DB | - |
| 4.2 | Add new product | Product saved, synced to backend | - |
| 4.3 | Edit product | Changes persist | - |
| 4.4 | Delete product | Product soft-deleted (isDeleted flag) | - |
| 4.5 | Filter by category | List filters | - |
| 4.6 | Search products | List filters | - |
| 4.7 | Add category | Category saved | - |
| 4.8 | Add unit | Unit saved | - |
| 4.9 | Add brand | Brand saved | - |
| 4.10 | Bulk import products (Excel) | `BulkImportDialog` opens, file picker works | Verify on web vs native |
| 4.11 | View product detail | Product info displays | - |
| 4.12 | Generate barcode for product | Barcode image generated | - |

---

### Module 5: Customers & Suppliers
**Routes:** `/customers`, `/suppliers`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 5.1 | View customer list | Customers load | - |
| 5.2 | Add customer via form dialog | Customer saved, dialog closes | `customer_form_dialog.dart:113` hardcoded `width: 500` |
| 5.3 | Edit customer | Changes persist | - |
| 5.4 | Delete customer | Customer soft-deleted | - |
| 5.5 | Bulk import customers (Excel) | `CustomerBulkImportDialog` opens | Recently fixed for responsive |
| 5.6 | View supplier list | Suppliers load | - |
| 5.7 | Add/edit/delete supplier | CRUD operations work | `supplier_form_dialog.dart:99` hardcoded `width: 500` |

---

### Module 6: Sales History & Invoices
**Routes:** `/sales-history`, `/invoice-templates`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 6.1 | View sales history | Invoices load from local DB | - |
| 6.2 | View invoice detail/preview | PDF preview renders | `invoice_preview_screen.dart:60` hardcoded `width: 800` |
| 6.3 | Print invoice | PDF generated and sent to printer | - |
| 6.4 | Navigate to invoice templates | Template selection screen loads | - |
| 6.5 | Select template | Editor opens with template | - |
| 6.6 | Edit template (business name, items) | Changes reflected in preview | - |
| 6.7 | Export PDF from editor | PDF generated | - |
| 6.8 | Template editor on compact width | Sidebar shrinks to 300px, grid becomes 2 columns | Recently fixed |

---

### Module 7: Ledger
**Routes:** `/customer-ledger`, `/customer-ledger/add`, `/supplier-ledger`, `/supplier-ledger/add`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 7.1 | View customer ledger | Transactions load | Hardcoded field widths (180, 200) |
| 7.2 | Add ledger entry | Entry saved | - |
| 7.3 | View supplier ledger | Transactions load | Hardcoded field widths (180, 200) |
| 7.4 | Add supplier ledger entry | Entry saved | - |

---

### Module 8: Stock Management
**Routes:** `/inventory-dashboard`, `/purchase-receipt`, `/purchase-receipt/add`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 8.1 | View inventory dashboard | Stock levels display | Hardcoded widths (180, 200) |
| 8.2 | View stock list | Products with stock load | - |
| 8.3 | View stock movement log | Movements display | - |
| 8.4 | Create purchase receipt | Receipt saved, stock updated | - |
| 8.5 | Bulk import stock (Excel) | `BulkImportDialog` opens | Recently fixed for responsive |

---

### Module 9: Employees
**Route:** `/employees`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 9.1 | View employee list | Employees load | - |
| 9.2 | Add employee via dialog | Employee saved | `employee_form_dialog.dart:150` hardcoded `width: 520` |
| 9.3 | Edit employee | Changes persist | - |
| 9.4 | Delete employee | Employee soft-deleted | - |

---

### Module 10: Settings & Roles
**Routes:** `/settings`, `/settings/invoice`, `/settings/roles`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 10.1 | View settings | Settings screen loads | - |
| 10.2 | Edit invoice settings | Settings saved | - |
| 10.3 | View roles | Role list displays | `role_settings_screen.dart:210` sidebar hardcoded `width: 250` |
| 10.4 | Edit role permissions | Permissions saved | - |

---

### Module 11: Profile
**Routes:** `/profile`, `/profile/companies`, `/company-profile`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 11.1 | View user profile | Profile info displays | - |
| 11.2 | Update profile | Changes saved | - |
| 11.3 | View companies list | Companies load | - |
| 11.4 | Create new company | Company created | - |
| 11.5 | Switch company | Company context changes, data refreshes | - |
| 11.6 | Update company logo | Logo uploaded | - |

---

### Module 12: Barcode Generation
**Route:** `/barcode-generation`

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 12.1 | Open barcode screen | Screen loads | Hardcoded image width: 150 |
| 12.2 | Generate barcode for product | Barcode image displays | - |
| 12.3 | Print barcode | Barcode sent to printer | - |

---

### Module 13: Sync Engine

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 13.1 | Create product offline | Product saved to local DB with syncStatus=1 | - |
| 13.2 | Come online | SyncEngine pushes change to backend | - |
| 13.3 | Modify product on backend | SyncEngine pulls change locally | - |
| 13.4 | Conflict: edit same product offline + online | Last-write-wins or conflict resolution | Verify outbox retry behavior |
| 13.5 | Kill app during sync | Pending outbox entries retry on next launch | Exponential backoff: 30s, 1m, 2m... |
| 13.6 | SSE connection (native) | Real-time push notifications received | Web falls back to 10s polling |
| 13.7 | Check sync with stale cursor | FULL_RESYNC_REQUIRED clears local DB | Destructive - verify user notification |

---

### Module 14: Responsive Layout (Cross-cutting)

| # | Test Step | Expected Result | Known Risk |
|---|-----------|-----------------|------------|
| 14.1 | Resize window across breakpoints (< 600, 600-1024, > 1024) | Layouts adapt | 66 hardcoded widths remain |
| 14.2 | Test all 5 POS layouts at 400px width | No horizontal overflow | retail_layout: 350px drawer, restaurant_layout: 420px sidebar |
| 14.3 | Test dialogs on 320px width | Dialogs shrink or scroll | employee_form: 520px, customer_form: 500px, supplier_form: 500px |
| 14.4 | Test invoice preview on tablet | Dialog fits viewport | 800px hardcoded width |
| 14.5 | Test role settings on tablet | Sidebar + content fit | 250px sidebar hardcoded |

---

## 6. Recommendations (Priority Order)

1. **Fix `app_config.dart`** to respect the `environment` variable for API URL selection
2. **Delete `features/sales/screens/pos_screen.dart`** and `features/sales/state/cart_notifier.dart` (dead code)
3. **Replace `as dynamic` casts** in `compact_layout.dart` with proper `ProductEntity` field access
4. **Add logging** to empty `catch (_) {}` blocks (at minimum `debugPrint`)
5. **Migrate remaining `ChangeNotifier` ViewModels** to Riverpod `StateNotifier`
6. **Remove deprecated `SyncService`** or clearly mark it as unused
7. **Make `AppConstants.syncInterval`** actually used by the sync engines
8. **Apply responsive `ConstrainedBox` pattern** to the remaining 4 form dialogs (employee, customer, supplier, invoice audit)
9. **Centralize timeout constants** instead of scattering magic numbers
10. **Add `login_screen.dart`** to the responsive batch (currently missing)

---

## 7. Files Modified in Recent Responsive Refactor

These 8 files were updated as part of the responsive layout work:

| File | Change |
|------|--------|
| `features/customers/widgets/bulk_import_dialog.dart` | `ConstrainedBox(maxWidth: 400)` + responsive padding |
| `features/sales/screens/pos_screen.dart` | Recall order dialog: `ConstrainedBox(maxWidth: 400)` |
| `features/invoice/screens/invoice_template_editor_screen.dart` | Sidebar 300/400px, grid 2/5 cols, header stacks vertically, search hidden on compact |
| `features/auth/presentation/screens/signup_screen.dart` | `ConstrainedBox(maxWidth: 400)` + responsive padding + shadow dropped on compact |
| `features/auth/presentation/screens/forgot_password_screen.dart` | `ConstrainedBox(maxWidth: 400)` + responsive padding |
| `features/auth/presentation/screens/reset_password_screen.dart` | `ConstrainedBox(maxWidth: 400)` + responsive padding |
| `features/stock_mgmt/widgets/bulk_import_dialog.dart` | `ConstrainedBox(maxWidth: 400)` + responsive padding |
| `core/widgets/unit_form_dialog.dart` | `ConstrainedBox(maxWidth: 400)` + responsive padding |

All pass `dart analyze` with zero new issues.

---

## Dead Code Cleanup

**48 files deleted, 3 files restored from git, 1 empty directory removed.**
Net: 45 files deleted, ~9,300 lines removed. `dart analyze` passes clean.

### Deleted files

**13 empty stubs** (0-byte DAOs, models, repos, screens):
`base_repository.dart`, `customer_repository_impl.dart`, `supplier_repository_impl.dart`, `purchase_receipt_repository_impl.dart`, `category_screen.dart`, `supplier_form_screen.dart`, `payment_method_dialog.dart`, `payment_history_screen.dart`, `product_selection_screen.dart`, `add_expense_screen.dart`, `expense_category_form_screen.dart`, `expense_list_screen.dart`, `expense_category_service.dart`

**7 unused models/enums**: `payment_method.dart`, `sale_status.dart`, `inventory_movement.dart`, `return.dart`, `wallet_transaction.dart`, `mock_data.dart`, `app_constants.dart`

**2 unused services**: `sync_service.dart` (1400+ lines), `invoice_service.dart` (legacy print service)

**7 unused widgets**: `offline_indicator.dart`, `pos_data_table.dart`, `responsive_data_view.dart`, `cart_item_tile.dart`, `pos_header.dart`, `invoice_status_badge.dart`, `quantity_dialog_with_unit.dart`

**5 unused screens**: `invoice_form_screen.dart`, `sales_receipt_screen.dart`, `add_category_screen.dart`, `report_screen.dart`, `sales_list_screen.dart` (old stub)

**2 unused state/providers**: `return_settings_provider.dart`, `cart_notifier.dart`

**4 other dead files**: `platform_utils.dart`, `constants.dart`, `custom_layout.dart`, `firebase_options.dart`

**9 dead template files** (features/sales/templates/): `advanced_gst_layout.dart`, `classic_layout.dart`, `dreams_layout.dart`, `luxury_layout.dart`, `modern_layout.dart`, `simple_layout.dart`, `stylish_layout.dart`, `thermal_layout.dart`, `template_helper.dart`

### Restored from git

- `customer_transaction_repository_impl.dart` — had 166 lines, was incorrectly identified as empty
- `supplier_transaction_repository_impl.dart` — same; required by `service_locator.dart`
- `purchase_receipt_repository_impl.dart` — same; required by `service_locator.dart`
- `sales/screens/invoice_preview_screen.dart` — dead duplicate of the active invoice preview screen, but was still imported by `pos_screen.dart` (different API than the active version)

### Cleanup in compact_layout.dart

- Removed dead `_recentItems` list (populated but never read)
- Removed commented-out import

### Removed empty directories

- `core/data/`
- `features/sales_receipt/`
