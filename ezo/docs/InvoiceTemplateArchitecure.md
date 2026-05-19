# Invoice Template Architecture

## Overview

The invoice template system supports multiple paper formats (A4, A5, Thermal) across various industries (Retail, Grocery, Garment, Electronics, Restaurant). Templates are defined as Dart classes extending an abstract `InvoiceTemplate` base class and registered in a central `TemplateRegistry`.

## Architecture Components

### 1. Abstract Base Class
**File:** `lib/features/invoice/invoice_template_editor/template_engine/invoice_template.dart`

Defines the contract all templates must implement:
- `id` — unique string identifier
- `name` — display name
- `industry` — e.g. `RETAIL`, `GROCERY`, `GARMENT`, `ELECTRONICS`, `RESTAURANT`
- `format` — `A4`, `A5`, or `THERMAL`
- `styleName` — e.g. `PROFESSIONAL`, `COMPACT`, `ELEGANT`
- `buildPdf(InvoiceData)` — generates a `pw.Document` for printing
- `buildFlutterPreview(InvoiceData)` — generates a Flutter widget for live preview
- `getDefaultData()` — returns sample `InvoiceData` for the editor

### 2. Template Registry
**File:** `lib/features/invoice/invoice_template_editor/template_engine/template_registry.dart`

Central list of all available templates. Provides `getTemplateById()` for lookup. Currently registers 14 templates.

### 3. Data Models
**File:** `lib/features/invoice/invoice_template_editor/models.dart`

- `InvoiceData` — full invoice payload (business info, client, items, tax, visibility flags)
- `InvoiceItem` — line item with id, desc, qty, rate

### 4. Repository & Providers
**File:** `lib/features/invoice/invoice_template_editor/template_repository.dart`

- `InvoiceTemplateRepository` — reads/writes template selection to the `invoice_settings` DB table
- `activeTemplateProvider` — `StreamProvider` that reactively provides the currently selected template
- `tenantIdProvider` — scopes templates to tenants

### 5. Selection Screen
**File:** `lib/features/invoice/invoice_template_editor/selection_screen.dart`

Template gallery with filter tabs and pagination.

### 6. Editor Screen
**File:** `lib/features/invoice/invoice_template_editor/editor_screen.dart`

Full template editor with live side-by-side preview and configuration sidebar.

## Thermal Width Support

All thermal templates support three paper widths via a shared utility:

**File:** `lib/features/invoice/invoice_template_editor/helpers/thermal_utils.dart`

| Width | Points | Use Case |
|-------|--------|----------|
| 58mm  | 164.41 | Small receipt printers |
| 72mm  | 204.09 | Mid-size POS printers |
| 80mm  | 226.77 | Standard thermal printers |

The `EditorScreen` allows users to select 58mm, 72mm, or 80mm in Printer Settings. The width is persisted in `InvoiceSettingsEntity.thermalWidth` and passed to templates via `InvoiceData.thermalWidth`.

## Registered Templates (14 total)

### THERMAL (58mm/72mm/80mm) — 5 templates

| ID | Name | Industry | Style |
|----|------|----------|-------|
| `fresh_mart_10` | Fresh Mart Grocery | GROCERY | COMPACT |
| `quick_serve_thermal` | Quick Serve Thermal | RETAIL | SPEEDY |
| `dine_plus_thermal` | DinePlus Thermal | RESTAURANT | CAFE STYLE |
| `style_craft_thermal` | StyleCraft Thermal | GARMENT | CHIC |
| `tech_bill_thermal` | TechBill Thermal | ELECTRONICS | TECH |

### A5 Half-Page — 3 templates

| ID | Name | Industry | Style |
|----|------|----------|-------|
| `bistro_half_page` | Bistro Half-Page | RESTAURANT | BISTRO |
| `fashionista_a5` | Fashionista A5 | GARMENT | ELEGANT |
| `grocery_saver_a5` | Grocery Saver A5 | GROCERY | SAVER |

### A4 Full-Page — 6 templates

| ID | Name | Industry | Style |
|----|------|----------|-------|
| `default_a4` | Design Systems India | RETAIL | PROFESSIONAL |
| `1` | Retail Basic | RETAIL | COMPACT |
| `electronics_8` | Electronics Detailed | ELECTRONICS | DETAILED |
| `restaurant_pro_a4` | Restaurant Pro A4 | RESTAURANT | PROFESSIONAL |
| `garment_collection_a4` | Garment Collection A4 | GARMENT | ELEGANT |
| `grocery_wholesale_a4` | Grocery Wholesale A4 | GROCERY | WHOLESALE |

## Filter & Pagination

### Format Filter
Three tabs: `Thermal Receipt` → `THERMAL`, `A5 Half-Page` → `A5`, `A4 Full-Page` → `A4`. Maps display names to template `format` field.

### Industry Filter
Dynamically derived from registered templates. Shows "All Industries" plus each unique `industry` value that appears in the full template list. When a format tab is active, industries without matching templates simply show empty state.

### Pagination
- 8 items per page (2 rows of 4 on desktop)
- `currentPage` resets to 1 when format or industry filter changes
- Previous/Next buttons disable at boundaries
- Up to 7 page buttons shown; ellipsis for larger page counts

## State Flow

```
TemplateRegistry.availableTemplates
  → SelectionScreen (filtered + paginated display)
  → onEdit(templateId) → EditorScreen
  → saveTemplateSelection() → DB (invoice_settings table)
  → activeTemplateProvider (StreamProvider)
  → InvoicePreviewScreen (builds PDF via buildPdf)
```

## Extending

To add a new template:
1. Create a class extending `InvoiceTemplate`
2. Implement all required getters and methods
3. Import and add instance to `TemplateRegistry.availableTemplates`
4. The selection screen automatically picks up the new template

No changes needed to the selection screen, editor, or preview for new templates.
