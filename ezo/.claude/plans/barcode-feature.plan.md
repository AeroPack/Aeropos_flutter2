# Plan: Barcode Feature — End-to-End

**Complexity**: Large

---

## Production-Grade Gaps (Post-Review — Must Fix Before Shipping)

Five critical issues identified in review that the original plan did not cover. Each is integrated into the relevant task below and marked **[PG-N]**.

| # | Gap | Severity | Affected Task |
|---|---|---|---|
| PG-1 | **HID Scanner Focus Bleed** — scanner types barcode into whichever TextField has cursor | CRITICAL | Task 6 |
| PG-2 | **Rapid-Fire Race Condition** — back-to-back scans of same item can produce duplicate line items | HIGH | Task 6 |
| PG-3 | **Weight-Embedded Barcodes** — prefixes 21/23/24/25/28/29 encode weight, not price | HIGH | Task 5 |
| PG-4 | **Offline-First Sync Collision** — hard UNIQUE index breaks sync when two offline devices use same barcode | HIGH | Task 3 |
| PG-5 | **No Sensory Feedback** — cashiers rely on audio, not screen, to confirm scans | MEDIUM | Task 1, Task 6 |

---

## Codebase Discoveries (Pre-flight)

These save implementation time and prevent re-work:

| Finding | File | Impact |
|---|---|---|
| `barcode TEXT NULL` column **already exists** | `tables/product_units_table.dart:6` | No column migration needed |
| `getUnitByBarcode()` **already exists** | `dao/product_unit_dao.dart:64` | Barcode→ProductUnit lookup is done |
| `CartNotifier.addProduct()` is Riverpod `StateNotifier` | `state/cart_state.dart:264` | BarcodeService can call it via `ref.read(cartProvider.notifier)` |
| `HardwareKeyboard.instance` already used | `widgets/product_search_bar.dart:79` | Scanner intercept pattern is established |
| DB schema is at **v47** | `app_database.dart:75` | Next migration = v48 |
| No barcode packages in pubspec.yaml | `pubspec.yaml` | All 4 packages need adding |
| `ProductUnitDao` registered in `@DriftDatabase` | `app_database.dart:69` | DAO injection pattern clear |

---

## Pattern Reference

| Category | Source | Pattern |
|---|---|---|
| Naming | `state/cart_state.dart`, `dao/product_unit_dao.dart` | `snake_case_service.dart`, `snake_case_dao.dart` |
| Riverpod state | `state/cart_state.dart:464` | `StateNotifierProvider<Notifier, State>` |
| Async providers | `state/cart_state.dart:479` | `StreamProvider.autoDispose` with `Timer` debounce |
| DAO joins | `dao/product_unit_dao.dart:14` | `select().join([leftOuterJoin()])..where()` |
| DB migrations | `app_database.dart:527-598` | `if (from < N) { ... customStatement(...) }` |
| Index creation | `app_database.dart:95-133` | `customStatement('CREATE INDEX IF NOT EXISTS ...')` in both `onCreate` and `onUpgrade` |
| Service injection | `pos_screen.dart:986` | `ServiceLocator.instance.database` + `db.productUnitDao` |
| Platform gating | (new) | `import 'dart:io'; Platform.isIOS \|\| Platform.isMacOS` |
| Error handling | `pos_screen.dart:229` | `try/catch` with `PosToast.showError(context, msg)` |

---

## Files to Change

### Phase 1 — Core POS Scanning (MVP)

| File | Action | Why |
|---|---|---|
| `pubspec.yaml` | UPDATE | Add 4 new packages |
| `macos/Runner/Info.plist` | UPDATE | Camera usage description |
| `ios/Runner/Info.plist` | UPDATE | Camera usage description |
| `lib/core/database/app_database.dart` | UPDATE | Bump schemaVersion to 48, add partial index migration, add `getProductsByBarcode()` |
| `lib/features/pos/state/barcode_state.dart` | CREATE | Sealed result types (`BarcodeMatched`, `BarcodeNotFound`, `BarcodeMultiVariant`, `BarcodePriceEmbedded`) |
| `lib/features/pos/services/barcode_service.dart` | CREATE | Central lookup, GS1 parsing, price-embedded decoder, 80ms hardware buffer |
| `lib/features/pos/pos_screen.dart` | UPDATE | Wrap `Scaffold body` with `BarcodeKeyboardListener` from `flutter_barcode_listener` |
| `lib/features/pos/widgets/product_search_bar.dart` | UPDATE | Barcode-first regex detection; camera scan icon gated on `Platform.isIOS\|\|isMacOS` |
| `lib/features/pos/widgets/barcode_camera_overlay.dart` | CREATE | Modal bottom sheet housing `MobileScanner` widget |
| `lib/features/pos/layouts/compact_layout.dart` | UPDATE | Accept `onBarcodeScanned` callback threaded from `PosScreen` |
| `lib/features/pos/layouts/restaurant_layout.dart` | UPDATE | Same as compact |

### Phase 2 — Generation & Display

| File | Action | Why |
|---|---|---|
| `lib/features/pos/widgets/quantity_with_unit_dialog.dart` | UPDATE | Show `BarcodeWidget` for the selected unit's barcode |
| `lib/features/inventory/products/add_product_screen.dart` | UPDATE | Scan-to-fill icon + focus-out duplicate barcode validation |

### Phase 3 — Purchase Receipt Integration

| File | Action | Why |
|---|---|---|
| `lib/features/purchase_receipt/purchase_receipt_screen.dart` | UPDATE | Mount hardware listener at screen root |
| `lib/features/purchase_receipt/purchase_entry_screen.dart` | UPDATE | Wire barcode lookup to item-search field |

---

## Task-by-Task Breakdown

---

### PHASE 1 — TASK 1: Add Dependencies

**File**: `pubspec.yaml`

Add under `dependencies:`:
```yaml
mobile_scanner: ^7.0.0
flutter_barcode_listener: ^0.1.4
barcode_widget: ^2.0.4
gs1_barcode_parser: ^1.0.0
audioplayers: ^6.1.0          # [PG-5] success beep / error buzz
```

> **[PG-5]** `audioplayers` must be initialized once at app startup. Bundle two short WAV assets:
> - `assets/sounds/beep_success.wav` — high-pitch ~800Hz, 80ms
> - `assets/sounds/beep_error.wav` — low-pitch ~200Hz, 200ms
>
> Declare both in `pubspec.yaml` under `flutter: assets:`.

**Validate**: `flutter pub get` exits 0; `flutter pub deps` shows all 5 resolved.

---

### PHASE 1 — TASK 2: Platform Permissions

**Files**: `macos/Runner/Info.plist`, `ios/Runner/Info.plist`

Add `NSCameraUsageDescription` key:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used to scan product barcodes at checkout.</string>
```

**Validate**: Build on macOS/iOS does not throw entitlement error.

---

### PHASE 1 — TASK 3: Database Migration v48

**File**: `lib/core/database/app_database.dart`

**Step 3a** — Bump `schemaVersion`:
```dart
@override
int get schemaVersion => 48;
```

**Step 3b** — Add partial unique index to `onCreate` block (after existing indexes):
```dart
'CREATE UNIQUE INDEX IF NOT EXISTS idx_product_units_barcode_unique '
'ON product_units(barcode) '
'WHERE barcode IS NOT NULL AND is_deleted = 0',
```

**Step 3c** — Add `if (from < 48)` block in `onUpgrade`:
```dart
if (from < 48) {
  try {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_product_units_barcode_unique '
      'ON product_units(barcode) '
      'WHERE barcode IS NOT NULL AND is_deleted = 0',
    );
  } catch (e) {
    // index may already exist on clean installs
  }
}
```

> **[PG-4] Sync Collision Strategy — READ BEFORE MERGING**
>
> The partial UNIQUE index enforces barcode uniqueness **locally** per device. Because this is an offline-first app with UUID-based sync, two devices can each assign the same barcode to different products while offline and save successfully. When they sync, the server's upsert will detect the conflict.
>
> **Required mitigations (choose one based on sync engine capability):**
>
> Option A — **Application-level guard (recommended for MVP)**: Drop the UNIQUE index. Instead, validate uniqueness in `BarcodeService.resolve()` and in `add_product_screen.dart` via `getProductsByBarcode()` before write. A non-unique barcode produces a warning, not a hard error. This avoids any constraint breakage during sync.
>
> Option B — **Server-wins conflict resolution**: Keep the UNIQUE index. Add a `try/catch` in the sync engine's upsert handler that, on `UNIQUE constraint failed: product_units.barcode`, renames the losing device's barcode to `{barcode}-conflict-{uuid_suffix}` and logs the collision to `sync_errors` table.
>
> **Default for this plan**: Use **Option A** for the initial migration. The index in Step 3b/3c should be created as a **non-unique** performance index only:
> ```dart
> 'CREATE INDEX IF NOT EXISTS idx_product_units_barcode '
> 'ON product_units(barcode) '
> 'WHERE barcode IS NOT NULL AND is_deleted = 0',
> ```
> Uniqueness is enforced at the application layer in `BarcodeService` and `add_product_screen`.

**Step 3d** — Add `getProductsByBarcode()` query method on `AppDatabase`:
```dart
/// Returns the product and its matching unit for a given barcode.
/// Returns null when no active (non-deleted) unit matches.
Future<({ProductEntity product, ProductUnitEntity unit})?> getProductsByBarcode(
  String barcode,
) async {
  final query = select(productUnits).join([
    innerJoin(products, products.id.equalsExp(productUnits.productId)),
  ])
    ..where(productUnits.barcode.equals(barcode))
    ..where(productUnits.isDeleted.equals(false))
    ..where(products.isDeleted.equals(false));

  final row = await query.getSingleOrNull();
  if (row == null) return null;
  return (
    product: row.readTable(products),
    unit: row.readTable(productUnits),
  );
}
```

**Mirror**: Matches `watchProductsWithCategory()` join pattern at `app_database.dart:709`.

**Validate**: `flutter pub run build_runner build --delete-conflicting-outputs` exits 0.

---

### PHASE 1 — TASK 4: Sealed Barcode Result Types

**File**: `lib/features/pos/state/barcode_state.dart` (CREATE)

```dart
import 'package:aeropos/core/database/app_database.dart';

sealed class BarcodeResult {}

final class BarcodeMatched extends BarcodeResult {
  final ProductEntity product;
  final ProductUnitEntity unit;
  BarcodeMatched({required this.product, required this.unit});
}

final class BarcodeNotFound extends BarcodeResult {
  final String rawCode;
  BarcodeNotFound(this.rawCode);
}

final class BarcodeMultiVariant extends BarcodeResult {
  final String rawCode;
  BarcodeMultiVariant(this.rawCode);
}

final class BarcodePriceEmbedded extends BarcodeResult {
  final String productLinkCode;
  final double embeddedPrice;
  BarcodePriceEmbedded({required this.productLinkCode, required this.embeddedPrice});
}
```

**Validate**: `dart analyze lib/features/pos/state/barcode_state.dart` — no errors.

---

### PHASE 1 — TASK 5: BarcodeService

**File**: `lib/features/pos/services/barcode_service.dart` (CREATE)

Responsibilities:
1. Accept a raw string from either hardware or camera
2. Detect price-embedded format (starts with `02` or `20`, length 13)
3. **[PG-3]** Detect weight-embedded format (starts with `21`/`23`/`24`/`25`/`28`/`29`, length 13)
4. Parse GS1 with `gs1_barcode_parser` if code starts with `(` or FNC1 marker `\x1d`
5. Otherwise call `db.getProductsByBarcode(code)` via `AppDatabase`
6. Return a `BarcodeResult`

Add a new sealed class to `barcode_state.dart` for weight-embedded results:
```dart
final class BarcodeWeightEmbedded extends BarcodeResult {
  final String productLinkCode;
  final double weightKg;       // extracted from barcode digits
  BarcodeWeightEmbedded({required this.productLinkCode, required this.weightKg});
}
```

Updated `BarcodeService`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gs1_barcode_parser/gs1_barcode_parser.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/features/pos/state/barcode_state.dart';

class BarcodeService {
  static const _minCodeLength = 4;
  static const _priceEmbedPrefixes = ['02', '20'];
  // [PG-3] weight-embedded scale prefixes (deli / produce / meat counters)
  static const _weightEmbedPrefixes = ['21', '23', '24', '25', '28', '29'];

  Future<BarcodeResult> resolve(String rawCode) async {
    final code = rawCode.trim();
    if (code.length < _minCodeLength) return BarcodeNotFound(code);

    if (_isPriceEmbedded(code)) return _decodePriceEmbedded(code);
    if (_isWeightEmbedded(code)) return _decodeWeightEmbedded(code); // [PG-3]
    if (_isGs1(code)) return _resolveGs1(code);

    final db = ServiceLocator.instance.database;
    final match = await db.getProductsByBarcode(code);
    if (match == null) return BarcodeNotFound(code);
    return BarcodeMatched(product: match.product, unit: match.unit);
  }

  bool _isPriceEmbedded(String code) =>
      code.length == 13 && _priceEmbedPrefixes.any(code.startsWith);

  BarcodeResult _decodePriceEmbedded(String code) {
    // [prefix 2][product link 5][price cents 5][check 1]
    final productLinkCode = code.substring(2, 7);
    final price = int.tryParse(code.substring(7, 12));
    if (price == null) return BarcodeNotFound(code);
    return BarcodePriceEmbedded(
      productLinkCode: productLinkCode,
      embeddedPrice: price / 100.0,
    );
  }

  // [PG-3] Weight-embedded: [prefix 2][product link 5][weight grams 5][check 1]
  bool _isWeightEmbedded(String code) =>
      code.length == 13 && _weightEmbedPrefixes.any(code.startsWith);

  BarcodeResult _decodeWeightEmbedded(String code) {
    final productLinkCode = code.substring(2, 7);
    final weightRaw = int.tryParse(code.substring(7, 12));
    if (weightRaw == null) return BarcodeNotFound(code);
    // Weight is encoded as grams (e.g. 01500 = 1.500 kg)
    return BarcodeWeightEmbedded(
      productLinkCode: productLinkCode,
      weightKg: weightRaw / 1000.0,
    );
  }

  bool _isGs1(String code) => code.startsWith('(') || code.contains('\x1d');

  Future<BarcodeResult> _resolveGs1(String code) async {
    try {
      final parsed = GS1BarcodeParser.defaultParser().parse(code);
      final gtin = parsed.element('01')?.data ?? parsed.element('00')?.data;
      if (gtin == null) return BarcodeNotFound(code);
      final db = ServiceLocator.instance.database;
      final match = await db.getProductsByBarcode(gtin);
      if (match == null) return BarcodeNotFound(gtin);
      return BarcodeMatched(product: match.product, unit: match.unit);
    } catch (_) {
      return BarcodeNotFound(code);
    }
  }
}

final barcodeServiceProvider = Provider<BarcodeService>((ref) => BarcodeService());
```

> **[PG-3] Weight handler in `_onBarcodeScanned`** (Task 6): On `BarcodeWeightEmbedded`, look up product by `productLinkCode`, then compute `linePrice = product.pricePerKg * weightKg` and call `cartNotifier.addProduct(product, quantity: weightKg)`. Products sold by weight need a `pricePerKg` field — verify this exists on `ProductEntity` or fall back to `product.price` with a `kg` unit assumption.

**Mirror**: Provider registration matches `cartProvider` style (`state/cart_state.dart:464`).

**Validate**: `dart analyze lib/features/pos/services/barcode_service.dart` — no errors.

---

### PHASE 1 — TASK 6: Wrap PosScreen Body with Hardware Listener

**File**: `lib/features/pos/pos_screen.dart`

Add imports at top:
```dart
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:aeropos/features/pos/services/barcode_service.dart';
import 'package:aeropos/features/pos/state/barcode_state.dart';
```

**[PG-1] Focus-bleed guard** — add a global `FocusNode` tracker to `_PosScreenState`:

> Hardware scanners emit characters at ~1–5ms intervals. `flutter_barcode_listener` buffers these and emits a single string after the 80ms window. However, if a `TextField` currently holds focus when the burst arrives, Flutter's `TextInputClient` may receive the raw characters before the buffer fires.
>
> The fix is to check `FocusManager.instance.primaryFocus` at the moment `onBarcodeScanned` fires. If the focused widget is a `TextField` (or any `EditableText`), drop focus first so the barcode string never reaches the field, then process the scan.

```dart
// [PG-1] helper — true when a text field owns primary focus
bool _textFieldHasFocus() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null) return false;
  return focus.context?.widget is EditableText;
}
```

**[PG-5] Audio player** — initialise once in `initState`, dispose in `dispose`:
```dart
final _player = AudioPlayer();

@override
void initState() {
  super.initState();
  _player.setReleaseMode(ReleaseMode.stop); // reuse without re-creating
  // ... existing initState code
}

@override
void dispose() {
  _player.dispose();
  super.dispose();
}

Future<void> _playBeep(bool success) async {
  final asset = success ? 'sounds/beep_success.wav' : 'sounds/beep_error.wav';
  await _player.play(AssetSource(asset));
}
```

**[PG-2] Race-condition note**: `CartNotifier.addProduct()` at `state/cart_state.dart:271` already does a synchronous `indexWhere` check and increments quantity if the product+unit pair exists. This means rapid back-to-back scans of the same item correctly accumulate as a single line item. **No change needed** — but verify that `addProduct` is never `async` and never `await`ed through a network call. If it ever becomes async, wrap calls in a debounce lock (`_scanInFlight` bool guard).

Add `_onBarcodeScanned` method to `_PosScreenState`:
```dart
Future<void> _onBarcodeScanned(String rawCode) async {
  // [PG-1] Drop any active text field focus before processing
  if (_textFieldHasFocus()) {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  final service = ref.read(barcodeServiceProvider);
  final result = await service.resolve(rawCode);
  if (!mounted) return;

  switch (result) {
    case BarcodeMatched(:final product, :final unit):
      ref.read(cartProvider.notifier).addProduct(product);
      await _playBeep(true); // [PG-5]
      PosToast.showSuccess(context, '${product.name} added');

    case BarcodePriceEmbedded(:final productLinkCode, :final embeddedPrice):
      final db = ServiceLocator.instance.database;
      final match = await db.getProductsByBarcode(productLinkCode);
      if (match != null && mounted) {
        ref.read(cartProvider.notifier).addProduct(match.product);
        await _playBeep(true); // [PG-5]
        PosToast.showSuccess(
          context, '${match.product.name} — Rs ${embeddedPrice.toStringAsFixed(2)}');
      } else if (mounted) {
        await _playBeep(false); // [PG-5]
        PosToast.showError(context, 'Barcode not found: $productLinkCode');
      }

    case BarcodeWeightEmbedded(:final productLinkCode, :final weightKg): // [PG-3]
      final db = ServiceLocator.instance.database;
      final match = await db.getProductsByBarcode(productLinkCode);
      if (match != null && mounted) {
        ref.read(cartProvider.notifier).addProduct(
          match.product, quantity: weightKg);
        await _playBeep(true); // [PG-5]
        PosToast.showSuccess(
          context, '${match.product.name} — ${weightKg.toStringAsFixed(3)} kg');
      } else if (mounted) {
        await _playBeep(false); // [PG-5]
        PosToast.showError(context, 'Barcode not found: $productLinkCode');
      }

    case BarcodeMultiVariant():
      await _playBeep(false); // [PG-5] ambiguous = error tone
      PosToast.showInfo(context, 'Multiple variants — select manually');

    case BarcodeNotFound(:final rawCode):
      await _playBeep(false); // [PG-5]
      PosToast.showError(context, 'No product for barcode: $rawCode');
  }
}
```

In `build()`, wrap the `body:` value:
```dart
body: BarcodeKeyboardListener(
  bufferDuration: const Duration(milliseconds: 80),
  onBarcodeScanned: _onBarcodeScanned,
  child: _buildSelectedLayout(...),
),
```

**Mirror**: `Focus` widget wrapping at `product_search_bar.dart:153`.

**Validate**:
- Launch app → scan hardware barcode → product toast + success beep appears.
- Click into Customer Name field, then scan → field is NOT populated; toast + beep fires.
- Scan same barcode 3× rapidly → single cart line item with qty=3, not 3 separate lines.

---

### PHASE 1 — TASK 7: Update ProductSearchBar

**File**: `lib/features/pos/widgets/product_search_bar.dart`

**Change 1** — Barcode-first detection in `_onSearchChanged`:
```dart
static final _barcodePattern = RegExp(r'^\d{4,}$');

void _onSearchChanged(String query) {
  if (_barcodePattern.hasMatch(query)) {
    widget.onBarcodeInput?.call(query);
    _controller.clear();
    return;
  }
  // existing logic unchanged
}
```

**Change 2** — Add optional constructor param and camera icon (Apple-only):
```dart
final void Function(String)? onBarcodeInput; // new param

// In suffixIcon — replace existing single-icon widget with Row:
if (Platform.isIOS || Platform.isMacOS)
  IconButton(
    icon: const Icon(Icons.qr_code_scanner, size: 20),
    onPressed: () => showModalBottomSheet(
      context: context,
      builder: (_) => BarcodeCameraOverlay(onScanned: widget.onBarcodeInput),
    ),
  ),
```

**Validate**: On Linux — no camera icon. On macOS — icon visible.

---

### PHASE 1 — TASK 8: BarcodeCameraOverlay

**File**: `lib/features/pos/widgets/barcode_camera_overlay.dart` (CREATE)

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeCameraOverlay extends StatefulWidget {
  final void Function(String)? onScanned;
  const BarcodeCameraOverlay({super.key, this.onScanned});

  @override
  State<BarcodeCameraOverlay> createState() => _BarcodeCameraOverlayState();
}

class _BarcodeCameraOverlayState extends State<BarcodeCameraOverlay> {
  final _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          final barcode = capture.barcodes.firstOrNull?.rawValue;
          if (barcode != null) {
            _controller.stop();
            Navigator.pop(context);
            widget.onScanned?.call(barcode);
          }
        },
      ),
    );
  }
}
```

**Validate**: On macOS — shows live viewfinder. Scan → overlay closes → barcode routes to `_onBarcodeScanned`.

---

### PHASE 1 — TASK 9: Wire Layouts (Compact + Restaurant)

**Files**: `compact_layout.dart`, `restaurant_layout.dart`

Add `final Future<void> Function(String)? onBarcodeScanned;` constructor param to each layout, and pass it as `onBarcodeInput` to `ProductSearchBar` instances within. Pure plumbing — no logic in layouts.

**Mirror**: All existing layout callback delegation at `pos_screen.dart:1283`.

---

### PHASE 2 — TASK 10: BarcodeWidget in QuantityWithUnitDialog

**File**: `lib/features/pos/widgets/quantity_with_unit_dialog.dart`

In the unit detail section, when a unit has a non-null `barcode`:
```dart
import 'package:barcode_widget/barcode_widget.dart';

if (unit.barcode != null && unit.barcode!.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: BarcodeWidget(
      barcode: Barcode.code128(),
      data: unit.barcode!,
      width: 160,
      height: 48,
      drawText: false,
    ),
  ),
```

**Validate**: Open quantity dialog for a product with a barcode unit → Code128 stripe renders.

---

### PHASE 2 — TASK 11: add_product_screen.dart Enhancements

**File**: `lib/features/inventory/products/add_product_screen.dart`

**Change 1** — Scan-to-fill icon (Apple-only, next to barcode field):
```dart
if (Platform.isIOS || Platform.isMacOS)
  IconButton(
    icon: const Icon(Icons.qr_code_scanner),
    onPressed: () async {
      final code = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => BarcodeCameraOverlay(
          onScanned: (v) => Navigator.pop(context, v),
        ),
      );
      if (code != null) _barcodeController.text = code;
    },
  ),
```

**Change 2** — Duplicate barcode validation on `onEditingComplete`:
```dart
Future<void> _validateBarcodeUnique(String code) async {
  if (code.isEmpty) return;
  final db = ServiceLocator.instance.database;
  final existing = await db.getProductsByBarcode(code);
  if (existing != null && existing.product.id != widget.product?.id) {
    setState(() =>
      _barcodeError = 'Already assigned to "${existing.product.name}"');
  } else {
    setState(() => _barcodeError = null);
  }
}
```

**Validate**: Enter a barcode assigned to another product → inline warning fires.

---

### PHASE 3 — TASK 12: Purchase Receipt Screen

**File**: `lib/features/purchase_receipt/purchase_receipt_screen.dart`

Wrap `Scaffold body` with `BarcodeKeyboardListener` (identical setup as Task 6). Handler calls `BarcodeService.resolve()` and opens the add-item dialog pre-populated when matched:
```dart
Future<void> _onBarcodeScanned(String rawCode) async {
  final result = await ref.read(barcodeServiceProvider).resolve(rawCode);
  if (result case BarcodeMatched(:final product)) {
    _openAddItemDialog(product: product);
  } else if (mounted) {
    PosToast.showError(context, 'Barcode not found: $rawCode');
  }
}
```

---

### PHASE 3 — TASK 13: Purchase Entry Add-Item Dialog

**File**: `lib/features/purchase_receipt/purchase_entry_screen.dart`

In the item-search `TextField.onChanged`, route numeric-looking input through `BarcodeService` before the text filter:
```dart
static final _barcodePattern = RegExp(r'^\d{4,}$');

void _onItemSearchChanged(String query) async {
  if (_barcodePattern.hasMatch(query)) {
    final result = await ref.read(barcodeServiceProvider).resolve(query);
    if (result case BarcodeMatched(:final product)) {
      _populateItemFromProduct(product);
      return;
    }
  }
  // existing text-filter logic
}
```

---

## Validation Commands

```bash
cd ezo

# After Task 1
flutter pub get

# After Task 3
flutter pub run build_runner build --delete-conflicting-outputs
dart analyze lib/

# After Phase 1
flutter run -d linux
# Manual: scan hardware barcode → toast + product in cart
# Manual: type 8-digit number → barcode path triggers
# Manual: invalid barcode → error toast, no crash

# After Phase 2
# Manual: open QuantityWithUnitDialog for barcode-tagged unit → Code128 renders
# Manual: add_product_screen → type existing barcode → duplicate warning

# After Phase 3
# Manual: open PurchaseReceiptScreen → scan incoming item → dialog pre-fills
```

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| **[PG-1]** Scanner types into focused TextField | High | `_textFieldHasFocus()` guard unfocuses before processing |
| **[PG-2]** Rapid scans create duplicate line items | Medium | `CartNotifier.addProduct` is synchronous qty-increment; verify it stays non-async |
| **[PG-3]** Weight decimal encoding varies by scale vendor | Medium | Make gram divisor (1000) a shopkeeper-configurable constant; default 1000 |
| **[PG-4]** Offline devices assign same barcode → sync collision | High | Use non-unique index (Option A); enforce uniqueness at application layer only |
| **[PG-5]** Audio assets missing at runtime | Low | Add `assets/sounds/` to `pubspec.yaml` flutter assets block; test on first launch |
| `flutter_barcode_listener` leaks events into search bar | Medium | 80ms buffer + min-length 4 guard; test with slow human typing |
| `mobile_scanner` build failure on Linux/Windows | High | Gate ALL `MobileScanner` usage behind `Platform.isIOS \|\| Platform.isMacOS` |
| GS1 parser API changes | Low | Pin to `^2.0.0`; wrap `parse()` in `try/catch` |
| Price-embedded decimal scale varies by hardware vendor | Medium | Add a shopkeeper-configurable `priceDecimalShift` setting in Phase 1.5 |

---

## Acceptance Checklist

### Phase 1 — Core Scanning
- [ ] Hardware scanner adds product to cart within 80ms buffer
- [ ] Camera overlay works on iOS/macOS; hidden on Linux/Windows
- [ ] Price-embedded barcode (02/20 prefix) extracts price correctly
- [ ] Weight-embedded barcode (21/23/24/25/28/29 prefix) extracts weight, computes line price **[PG-3]**
- [ ] GS1 structured barcode resolves via GTIN lookup
- [ ] Unknown barcode shows "not found" toast + error beep, no crash
- [ ] Scanning while a TextField has focus: field is NOT populated; beep + toast fires correctly **[PG-1]**
- [ ] Scanning same barcode 3× rapidly → single line item qty=3, not 3 rows **[PG-2]**
- [ ] Success scan plays high-pitch beep; failed scan plays low-pitch buzz **[PG-5]**
- [ ] `dart analyze` clean, `build_runner` clean

### Phase 2 — Generation & Display
- [ ] `BarcodeWidget` renders Code128 in `QuantityWithUnitDialog`
- [ ] Duplicate barcode warning fires on `add_product_screen`
- [ ] Application-level uniqueness check prevents duplicate barcodes without hard DB constraint **[PG-4]**

### Phase 3 — Purchase Receipt
- [ ] Purchase receipt screen accepts hardware scanner input
- [ ] Scanned item pre-populates add-item dialog

### All Phases
- [ ] Schema v48 migration runs on existing v47 DB without data loss
- [ ] Non-unique barcode index created (not UNIQUE — sync-safe) **[PG-4]**
