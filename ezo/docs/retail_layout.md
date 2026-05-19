# Retail Layout — Architecture & User Flow

## Overview

`RetailLayout` is a desktop-optimised POS screen designed for high-volume, keyboard-driven transactions — the "Excel-sheet cashier" experience. It presents a two-panel layout: a wide left workspace for product search and a line-item table, and a fixed 400 px right sidebar that functions as a live invoice builder.

---

## Architecture

### Inheritance Chain

```
ConsumerStatefulWidget
  └── BasePosLayout          (lib/features/pos/layouts/base_pos_layout.dart)
        └── RetailLayout     (lib/features/pos/layouts/retail_layout.dart)
              └── _RetailLayoutState extends BasePosLayoutState<RetailLayout>
```

`BasePosLayout` owns **all business-logic callbacks** (checkout, reset, discount, customer, etc.) as constructor parameters. `RetailLayout` only wires them to UI — no business logic lives here.

### Widget Tree

```
Scaffold
├── Row
│   ├── Expanded (flex: 3) — left workspace
│   │   ├── _buildIndustrialHeader()       ← top nav bar
│   │   └── Padding
│   │       ├── ProductSearchBar           ← search + autocomplete
│   │       └── CartTableWidget            ← spreadsheet-style line items
│   └── Container (width: 400) — right sidebar
│       └── _buildInvoiceSidebar()
│           ├── Invoice header (ref, customer selector)
│           ├── Expanded — item list (or empty state)
│           └── Footer — subtotal / tax / total + CLEAR / CHECKOUT
```

### State

| Provider | Type | Purpose |
|---|---|---|
| `productSearchProvider` | `StateProvider<String>` | Shared search query between `RetailLayout` and `ProductSearchBar` |
| `posProductListProvider` | `AsyncNotifierProvider` | Full product list watched by `ProductSearchBar` for filtering |
| `CartState` / `CartNotifier` | Passed via constructor | Cart items, totals, customer — owned by `PosScreen` |

`_RetailLayoutState` caches the `productSearchProvider` notifier in `initState` (`_searchNotifier`) and clears the search on `dispose`, avoiding a Riverpod ref-after-invalidation crash.

### Key Files

| File | Role |
|---|---|
| [retail_layout.dart](../lib/features/pos/layouts/retail_layout.dart) | Main layout widget |
| [base_pos_layout.dart](../lib/features/pos/layouts/base_pos_layout.dart) | Abstract base with all callbacks |
| [product_search_bar.dart](../lib/features/pos/widgets/product_search_bar.dart) | Search input + autocomplete dropdown |
| [cart_table_widget.dart](../lib/features/pos/widgets/cart_table_widget.dart) | Spreadsheet-style cart table |
| [quantity_with_unit_dialog.dart](../lib/features/pos/widgets/quantity_with_unit_dialog.dart) | Quantity + unit selector dialog |
| [cart_state.dart](../lib/features/pos/state/cart_state.dart) | `CartItem`, `CartState`, `CartNotifier` |

---

## User Flow

### 1. Opening the Screen

`PosScreen` selects `RetailLayout` based on the active POS mode and passes in the current `CartState`, `CartNotifier`, and all action callbacks. The layout renders immediately in its empty state.

### 2. Searching for a Product

```
Cashier types in ProductSearchBar
  → _onSearchChanged() updates productSearchProvider
  → posProductListProvider is filtered (client-side, up to 8 results)
  → Dropdown overlay renders below the search field
```

Each suggestion row shows the **product name** and a colour-coded **stock badge**:
- Green badge — stock ≥ 20
- Orange badge — stock 1–19
- Red badge — out of stock (0)

### 3. Selecting a Product (adding to cart)

**Mouse click** on a suggestion row  
or **keyboard navigation** (↑ / ↓ to highlight, Enter to confirm):

```
_selectSuggestion(product)
  → clears the search field and hides dropdown
  → calls widget.onProductSelected → _addToCartDirect()
```

`_addToCartDirect` → `_doAdd`:
1. Calls `cartNotifier.loadProductUnits(product.id)` — loads units from DB if not cached.
2. Finds the **default unit** for the product (falls back to `units.first`).
3. Queries the `units` table to resolve the unit name and symbol.
4. Calls `cartNotifier.addProduct(product, quantity: 1.0, selectedUnit: defaultUnit)`.

The product appears as a new row in `CartTableWidget` and as a line in the sidebar item list simultaneously.

> **Keyboard shortcut:** `Shift + ↓` while a suggestion is highlighted selects that item without moving the highlight cursor, enabling rapid back-to-back additions.

### 4. Editing a Line Item in the Table

`CartTableWidget` renders one row per `CartItem` with these columns:

| Column | Interaction |
|---|---|
| Product Name | Read-only; shows discount badge if `manualDiscount > 0` |
| HSN | Read-only |
| Price | Read-only (unit-aware calculated price) |
| Taxable Amt | Read-only subtotal |
| Unit | Tappable chip → opens `QuantityWithUnitDialog` |
| Qty | Inline `_QtyControl` (−  field  +) |

**Quantity control** (`_QtyControl`):
- Tap `+` / `−` → immediate `onQuantityChanged` callback.
- Type directly in the field → committed on blur or Enter.
- Min quantity is 1 (decrement below 1 is blocked).

**Unit chip tap** → `_showUnitDialog(item)`:
- Opens `QuantityWithUnitDialog` with the item's current quantity and unit.
- On save → `cartNotifier.updateQuantity(product, qty, selectedUnit: unit)`.

### 5. Invoice Sidebar

The sidebar is a live mirror of `CartState`. It does **not** have its own state — it reads directly from `widget.cartState`.

- **REF number** — generated from millisecond timestamp suffix (display-only, not persisted here).
- **Customer row** — shows "Walk-in Customer" or the selected customer's name; tap opens `onShowAddCustomerDialog`.
- **Item list** — scrollable; tapping any item opens `QuantityWithUnitDialog` for quick edits.
- **Totals footer** — SUBTOTAL, TAX, TOTAL recalculate reactively as the cart changes.

### 6. Checkout & Reset

| Button | Action |
|---|---|
| CLEAR | Calls `widget.onReset` — empties the cart |
| CHECKOUT | Calls `widget.onCheckout(shouldSave: false)` — proceeds to payment |

Both actions are delegated upward to `PosScreen`; `RetailLayout` contains no checkout logic.

---

## Design Notes

- **No category grid** — retail mode omits the product grid entirely; everything goes through the search bar for speed.
- **Keyboard-first** — `ProductSearchBar` handles arrow keys, Enter, and Escape natively so a cashier never needs the mouse.
- **Unit resolution at add-time** — the default unit is resolved from the DB when a product is first added, not lazily, so the price column is always accurate immediately.
- **Ref safety in dispose** — the `_searchNotifier` pointer is captured in `initState` and nulled in `dispose` to prevent calling `ref.read` after Riverpod invalidates the ref on widget removal.
