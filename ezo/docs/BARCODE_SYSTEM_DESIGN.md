# Barcode System Design — AeroPOS

> **Status:** DRAFT — Awaiting review before implementation begins.  
> **Author:** Generated via codebase exploration  
> **Schema version at time of writing:** 47  
> **Target platforms:** Windows · Linux · macOS · iOS

---

## Table of Contents

1. [Codebase Audit Summary](#1-codebase-audit-summary)
2. [Library Recommendations](#2-library-recommendations)
3. [State Management & UI Integration Plan](#3-state-management--ui-integration-plan)
4. [Hardware Scanner Keystroke Interception Strategy](#4-hardware-scanner-keystroke-interception-strategy)
5. [Database Schema Additions](#5-database-schema-additions)
6. [File & Folder Plan](#6-file--folder-plan)
7. [Integration Points — Module by Module](#7-integration-points--module-by-module)
8. [Implementation Phases](#8-implementation-phases)
9. [Open Questions](#9-open-questions)

---

## 1. Codebase Audit Summary

### What Already Exists

| Asset | Location | Notes |
|---|---|---|
| `ProductUnits.barcode` column | `lib/core/database/tables/product_units_table.dart` | Nullable `TEXT`, already stored per unit |
| Barcode entry field (product editor) | `lib/features/inventory/products/add_product_screen.dart` | Text field for entering barcode per unit variant |
| `_showBarcodeScan` toggle flag | `lib/features/pos/pos_screen.dart:~1010` | Boolean present but wired to nothing |
| Toggle icon button | compact and restaurant layouts | Taps flip the flag; no scanning happens |
| PDF QR generation | `pdf: ^3.10.4` via `pw.Barcode.qrCode()` | Used in invoice PDF only; not a UI widget |
| `productSearchProvider` | `lib/features/pos/state/cart_state.dart:469` | `StateProvider<String>` for raw search text |
| `posProductListProvider` | `lib/features/pos/state/cart_state.dart:479` | Debounced `StreamProvider` filtering by name |
| `ProductSearchBar` keyboard navigation | `lib/features/pos/widgets/product_search_bar.dart` | Arrow/Enter/Escape/Shift+Down fully implemented |

### What Is Missing

1. **No barcode index** — `product_units.barcode` has no database index; lookup on a large table will be a full table scan.
2. **No barcode lookup query** — no Drift query joins `product_units → products` on a barcode value.
3. **No scanning library** — zero camera or keyboard-emulation scanner integration.
4. **No barcode display widget** — no way to render a scannable barcode image on screen (label print, product detail).
5. **No `BarcodeService`** — no service coordinates the two input modes (camera vs. hardware).
6. **No platform routing** — the same toggle icon appears on all platforms; desktop should never show "camera" mode.

---

## 2. Library Recommendations

### 2.1 Scanning

#### Recommendation A — Camera Scanning: `mobile_scanner ^6.0.0`

```yaml
mobile_scanner: ^6.0.0
```

| Criteria | Verdict |
|---|---|
| iOS (primary mobile target) | ✅ Full AVFoundation camera, Apple Vision barcode detector |
| macOS | ✅ Camera access via AVFoundation (requires `NSCameraUsageDescription`) |
| Android | ✅ (future-proof; not a current target but costs nothing) |
| Windows | ⚠️ Experimental; relies on Media Foundation; not stable enough for production |
| Linux | ❌ Not supported |
| License | MIT |
| Formats | EAN-13, EAN-8, Code128, Code39, QR, UPC-A, UPC-E, DataMatrix, PDF417, Aztec, ITF |
| Maintenance | Actively maintained, 3 000+ stars, used in production POS apps |

**Decision:** Use `mobile_scanner` **only** on iOS and macOS. Gate it behind `Platform.isIOS || Platform.isMacOS` at the service layer. On Windows/Linux the camera scan button is hidden entirely.

#### Recommendation B — Hardware Scanner (Keyboard Emulation): `flutter_barcode_listener ^2.0.3`

```yaml
flutter_barcode_listener: ^2.0.3
```

USB and Bluetooth barcode guns are HID keyboard devices. They stream characters at ~1 ms per character then emit an `Enter` keystroke to signal end-of-code. Normal `TextEditingController` misses this because:

- The target `TextField` may not have keyboard focus at the moment the gun fires.
- The rapid burst can be intercepted by whichever widget currently holds focus (e.g., a quantity field).

`flutter_barcode_listener` solves this by mounting a `BarcodeKeyboardListener` **above** the entire widget tree. It subscribes to `HardwareKeyboard.instance.addHandler`, buffers characters received within a configurable time window (`bufferDuration`, default 100 ms), and emits the complete barcode string when the burst ends.

| Criteria | Verdict |
|---|---|
| Windows | ✅ Works via HID keyboard events |
| Linux | ✅ Works via HID keyboard events |
| macOS | ✅ Works |
| iOS (hardware scanner via Bluetooth) | ✅ Works (Bluetooth scanner pairs as BT keyboard) |
| Focus dependency | ❌ None — uses global `HardwareKeyboard` handler |
| License | MIT |

**Decision:** Use `flutter_barcode_listener` as the **always-on** global hardware scanner listener. It runs on all four target platforms simultaneously and does not conflict with camera scanning.

### 2.2 Barcode Generation / Display

#### Recommendation: `barcode_widget ^2.0.4`

```yaml
barcode_widget: ^2.0.4
```

The existing `pdf` package already generates barcodes for PDF output (`pw.Barcode`). `barcode_widget` is its companion Flutter UI renderer — it uses the same underlying `barcode` Dart library so there is zero format inconsistency between screen display and PDF output.

| Use case | Tool |
|---|---|
| Display barcode on product detail / label preview screen | `barcode_widget` |
| Print barcode label (PDF) | existing `pdf: ^3.10.4` (`pw.Barcode`) |
| QR code in invoices | existing `pw.Barcode.qrCode()` — no change |

Supported formats: Code128, EAN-13, EAN-8, Code39, UPC-A, UPC-E, QR, PDF417, DataMatrix.

#### Final pubspec.yaml additions

```yaml
dependencies:
  # Barcode scanning — camera (iOS + macOS only)
  mobile_scanner: ^6.0.0

  # Barcode scanning — hardware USB/BT scanner (all platforms)
  flutter_barcode_listener: ^2.0.3

  # Barcode display widget (screen / label preview)
  barcode_widget: ^2.0.4
```

---

## 3. State Management & UI Integration Plan

The feature follows the existing Riverpod + Repository pattern. No new `ServiceLocator` registrations; all wiring is via Riverpod providers.

### 3.1 New Providers

All new providers live in `lib/features/pos/state/barcode_state.dart`.

```dart
// ── Input mode ────────────────────────────────────────────────────────────────

enum BarcodeScanMode {
  off,        // scanning disabled
  hardware,   // BarcodeKeyboardListener mounted; always available
  camera,     // mobile_scanner camera overlay (iOS / macOS only)
}

// Defaults to hardware on desktop, off on mobile (user must opt in to camera)
final barcodeScanModeProvider = StateProvider<BarcodeScanMode>((ref) {
  if (Platform.isLinux || Platform.isWindows) return BarcodeScanMode.hardware;
  return BarcodeScanMode.off;
});

// ── Lookup result — Dart 3 sealed class ──────────────────────────────────────

sealed class BarcodeResult {}
class BarcodeIdle          extends BarcodeResult {}
class BarcodeLoading       extends BarcodeResult { final String code; … }
class BarcodeFound         extends BarcodeResult { final ProductUnitWithProduct hit; … }
class BarcodeMultipleFound extends BarcodeResult { final List<ProductUnitWithProduct> hits; … }
class BarcodeNotFound      extends BarcodeResult { final String code; … }

final barcodeResultProvider = StateProvider<BarcodeResult>((ref) => BarcodeIdle());

// ── Service ───────────────────────────────────────────────────────────────────
final barcodeServiceProvider = Provider<BarcodeService>((ref) => BarcodeService(ref));
```

### 3.2 New Service: `BarcodeService`

**File:** `lib/core/services/barcode_service.dart`

Responsibilities:

1. Accept a raw barcode string from either input channel (camera or hardware).
2. Query `AppDatabase.getProductsByBarcode(code)` — pure offline, zero network.
3. Update `barcodeResultProvider`.
4. **Exactly one match:** auto-call `CartNotifier.addItem(product, unit)` via existing cart path.
5. **Zero matches:** set `BarcodeNotFound` → `ProductSearchBar` shows inline error for 2 s.
6. **Multiple unit variants:** set `BarcodeMultipleFound` → disambiguation bottom sheet.

### 3.3 Camera Overlay Widget

**File:** `lib/features/pos/widgets/barcode_camera_overlay.dart`

- Wraps `MobileScannerController` inside a `MobileScanner` widget.
- Displayed as a modal bottom sheet over the POS screen.
- On `onDetect(capture)`: extracts `capture.barcodes.first.rawValue`, calls `barcodeService.handleScan(code)`, closes overlay on success.
- Only instantiated when `Platform.isIOS || Platform.isMacOS`.

### 3.4 Changes to Existing Files

#### `lib/features/pos/widgets/product_search_bar.dart`

- Add camera scan icon button to the right of the text field (iOS/macOS only).
- Add barcode-first detection: if the current query matches `RegExp(r'^\d{8,14}$')` and `Enter` is pressed, route to `barcodeService.handleScan(query)` before the normal name-search path.
- Show a small scanner-gun icon badge when `barcodeScanModeProvider == BarcodeScanMode.hardware` so cashiers know the hardware scanner is active.

#### `lib/features/pos/pos_screen.dart`

- Replace the bare `_showBarcodeScan` bool with `ref.watch(barcodeScanModeProvider)`.
- Wrap the POS body with `BarcodeKeyboardListener` to intercept hardware scanner input.

#### `lib/features/pos/layouts/compact_layout.dart` and `restaurant_layout.dart`

- Remove manual `_showBarcodeScan` toggle state; read `barcodeScanModeProvider` instead.
- Camera icon: show only on `Platform.isIOS || Platform.isMacOS`.

#### `lib/features/inventory/products/add_product_screen.dart`

- Add "scan to fill" icon button beside each unit's barcode `TextField`.
- On iOS/macOS: opens a one-shot `MobileScanner` dialog, populates field, closes immediately.

#### `lib/features/pos/widgets/quantity_with_unit_dialog.dart`

- Already passes `ProductUnit.barcode` through; add a `BarcodeWidget` rendering the barcode as a scannable image — useful when a physical label is missing.

---

## 4. Hardware Scanner Keystroke Interception Strategy

### Problem

USB and Bluetooth scanners emit characters at ~1–5 ms intervals per character, followed by an `Enter` keydown. At this speed:

- Characters may land in whichever `TextField` currently holds focus (e.g., a discount field, a quantity field).
- If no widget has focus (cashier's hand is on the scanner gun), characters are discarded entirely.

### Solution: Global `BarcodeKeyboardListener` at POS Screen Root

```
PosScreen
└── BarcodeKeyboardListener(
      bufferDuration: Duration(milliseconds: 80),
      minCodeLength: 4,
      onBarcodeScanned: (code) => barcodeService.handleScan(code),
      child: PosBody(),
    )
```

Mount the listener at the `PosScreen` level only — not the app root — so it does not intercept keystrokes in unrelated screens (product editor, settings).

**Why `bufferDuration: 80 ms`?**  
Human typing speed at 120 WPM produces one character every ~100 ms. A barcode scanner fires all 13 characters in 30–50 ms total. Setting 80 ms as the buffer window means: "accumulate characters; emit when no new character arrives for 80 ms." This reliably separates scanner bursts from human typing without special hardware configuration.

**Why `minCodeLength: 4`?**  
Filters accidental single-key presses or two-character sequences that could false-positive as scans.

**Conflict avoidance with the search `TextField`:**  
`BarcodeKeyboardListener` uses `HardwareKeyboard.addHandler` which fires before Flutter's `TextInputClient`. When a burst is detected, the handler returns `true` (consumed) for those events and they never reach the `TextField`. Single-character keystrokes fired at human speed return `false` (not consumed) and fall through to the `TextField` normally. The cashier can still type product names; only scanner-speed bursts are intercepted.

**Suffix key configuration:**  
Most scanners default to `Enter` suffix. For scanners configured with `Tab` or no suffix, pass the `suffix` parameter to `BarcodeKeyboardListener`. Document the expected suffix setting in the hardware scanner setup guide for operators.

**iOS with Bluetooth scanner:**  
A Bluetooth scanner paired as a BT HID keyboard is handled identically by `flutter_barcode_listener` — no separate code path needed.

---

## 5. Database Schema Additions

### 5.1 Missing Index (Critical for Performance)

`product_units.barcode` currently has no index. A lookup against a store with 5 000 product units does a full table scan. This is unacceptable for a POS that must respond to scans instantly.

```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_units_barcode
  ON product_units(barcode)
  WHERE barcode IS NOT NULL AND is_deleted = 0;
```

**Unique index:** Two products should not share the same barcode. The unique constraint enforces data integrity and turns every lookup into a guaranteed O(log n) B-tree seek.

**Partial index:** Rows with `barcode IS NULL` or `is_deleted = 1` are excluded — prevents a unique constraint violation when multiple units have no barcode set, and keeps the index small.

### 5.2 New Drift Query in `app_database.dart`

```dart
/// Lookup products by barcode. Uses idx_product_units_barcode for O(log n) seek.
/// Returns a list because the same barcode can theoretically appear on
/// multiple unit variants (e.g., case and each) — the UI handles disambiguation.
Future<List<ProductUnitWithProduct>> getProductsByBarcode(String barcode) {
  return (select(productUnits).join([
    innerJoin(products, products.id.equalsExp(productUnits.productId)),
  ])
    ..where(productUnits.barcode.equals(barcode))
    ..where(productUnits.isDeleted.equals(false))
    ..where(products.isDeleted.equals(false))
    ..where(products.isActive.equals(true)))
  .map((row) => ProductUnitWithProduct(
    unit: row.readTable(productUnits),
    product: row.readTable(products),
  )).get();
}
```

**Data class:**

```dart
class ProductUnitWithProduct {
  final ProductUnitEntity unit;
  final ProductEntity product;
}
```

### 5.3 Drift Migration — Schema Version 47 → 48

```dart
// In app_database.dart, inside onUpgrade:
if (from < 48) {
  await customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_product_units_barcode '
    'ON product_units(barcode) WHERE barcode IS NOT NULL AND is_deleted = 0',
  );
}
```

Increment `schemaVersion` to `48`.

### 5.4 No New Table or Column Required

`ProductUnits.barcode` already exists and is already synced to the backend via the existing `product_units` sync contract (uuid-based push/pull). No backend schema changes are needed.

---

## 6. File & Folder Plan

```
ezo/lib/
│
├── core/
│   ├── database/
│   │   └── app_database.dart              MODIFY: getProductsByBarcode(), migration 48
│   └── services/
│       └── barcode_service.dart           NEW: BarcodeService
│
└── features/
    ├── pos/
    │   ├── pos_screen.dart                MODIFY: BarcodeKeyboardListener wrapper
    │   ├── state/
    │   │   ├── cart_state.dart            MODIFY: react to BarcodeFound result
    │   │   └── barcode_state.dart         NEW: BarcodeScanMode, BarcodeResult, providers
    │   ├── layouts/
    │   │   ├── compact_layout.dart        MODIFY: read barcodeScanModeProvider
    │   │   └── restaurant_layout.dart     MODIFY: read barcodeScanModeProvider
    │   └── widgets/
    │       ├── product_search_bar.dart          MODIFY: barcode-first routing + scan icon
    │       ├── barcode_camera_overlay.dart      NEW: MobileScanner camera overlay
    │       └── quantity_with_unit_dialog.dart   MODIFY: add BarcodeWidget display
    │
    └── inventory/
        └── products/
            └── add_product_screen.dart    MODIFY: "scan to fill" on barcode field
```

---

## 7. Integration Points — Module by Module

### 7.1 POS Screen (Primary integration target)

| Scan result | Behaviour |
|---|---|
| Exactly 1 product/unit match | Auto-add to cart; show snackbar "Added: {product name}" |
| Multiple unit variants for same barcode | Disambiguation bottom sheet listing unit names and prices |
| No match | Inline search bar error "No product for barcode {code}" — clears after 2 s |
| Camera scan button | Visible only on iOS/macOS; opens `BarcodeCameraOverlay` bottom sheet |
| Hardware mode indicator | Scanner-gun icon badge on search bar when `BarcodeScanMode.hardware` |

### 7.2 Inventory — Product List Screen

No active scanning integration in Phase 1. A `BarcodeWidget` showing the default unit's barcode can be added to the product detail view for label-copy convenience (Phase 2).

### 7.3 Inventory — Add/Edit Product Screen

- "Scan to fill" button beside each unit's barcode field (iOS/macOS only).
- Inline uniqueness validation: query `getProductsByBarcode(newBarcode)` on focus-out; if a different product already owns it, show "Already assigned to {other product name}".

### 7.4 Customer Ledger

No barcode integration required. Customer lookup is by phone/name.

### 7.5 Purchase Receipt (Phase 3)

- Mount `BarcodeKeyboardListener` at `PurchaseReceiptScreen` root.
- Wire barcode scan to the item-search field in the "Add item" dialog.
- Enables operators to scan goods during stock-in without touching the keyboard.

---

## 8. Implementation Phases

### Phase 1 — Core POS Barcode Scanning (MVP)

1. Add three packages to `pubspec.yaml`; run `flutter pub get`.
2. Add `NSCameraUsageDescription` to `ios/Runner/Info.plist` and `macos/Runner/Info.plist`.
3. Write Drift migration 48 (barcode unique index); bump `schemaVersion` to 48.
4. Add `getProductsByBarcode()` query and `ProductUnitWithProduct` data class to `app_database.dart`.
5. Create `barcode_state.dart` (sealed result + providers).
6. Create `BarcodeService` (lookup → dispatch → cart add).
7. Wrap `PosScreen` body with `BarcodeKeyboardListener`.
8. Modify `product_search_bar.dart`: barcode-first detection, camera scan icon.
9. Create `BarcodeCameraOverlay` widget.
10. Update compact + restaurant layouts to read `barcodeScanModeProvider`.
11. End-to-end test: USB scanner on Linux, Bluetooth scanner on macOS, camera on iOS simulator.

### Phase 2 — Barcode Generation & Display

1. Add `BarcodeWidget` to product detail / `QuantityWithUnitDialog`.
2. Add "scan to fill" shortcut in product editor.
3. Add barcode column (optional toggle) to inventory product list.

### Phase 3 — Purchase Receipt Integration

1. Mount `BarcodeKeyboardListener` in purchase receipt screen.
2. Wire barcode lookup to item search in purchase receipt add-item dialog.

---

## 9. Open Questions

| # | Question | Impact |
|---|---|---|
| Q1 | Should duplicate barcodes across tenants be blocked? The partial unique index is per-database (single tenant per device). | If multi-tenant on one device is ever needed, change index to `(barcode, tenant_id)`. |
| Q2 | What suffix key do deployed hardware scanners use? (Enter / Tab / none) | Sets `suffix` parameter in `BarcodeKeyboardListener`; must be documented for operators. |
| Q3 | Has `NSCameraUsageDescription` been added to the iOS/macOS `Info.plist` yet? | Required before any `mobile_scanner` usage; App Store will reject without it. |
| Q4 | Should `BarcodeNotFound` offer an inline "Create product with barcode {code}" shortcut? | Small UX win during initial stock setup; adds scope to Phase 1 if desired. |
| Q5 | Should scan events be logged (scanned vs. manually typed ratio) for analytics? | Can append a `scan_source` field to `invoice_items` or `sync_outbox` metadata. |
