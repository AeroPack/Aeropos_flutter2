# Open Food Facts API Integration Plan

## Files to edit (5 total)

### 1. `ezo/lib/features/pos/state/barcode_state.dart`
**Action:** Append `BarcodeFoundExternally` class after `BarcodeWeightEmbedded`.

Add this at end of file:
```dart
final class BarcodeFoundExternally extends BarcodeResult {
  final String rawCode;
  final String suggestedName;
  final String? imageUrl;

  BarcodeFoundExternally({
    required this.rawCode,
    required this.suggestedName,
    this.imageUrl,
  });
}
```

---

### 2. `ezo/lib/features/pos/services/barcode_service.dart`
**Action:** Add `dio` import and insert API call in `resolve()` before the `return BarcodeNotFound` fallback.

Add imports (`package:flutter/foundation.dart`, `package:dio/dio.dart`).

Replace the existing DB lookup block (lines 19-24):
```dart
final db = ServiceLocator.instance.database;
final matches = await db.getProductsByBarcode(code);
if (matches.isEmpty) return BarcodeNotFound(code);
if (matches.length > 1) return BarcodeMultiVariant(code, matches);
final match = matches.first;
return BarcodeMatched(product: match.product, unit: match.unit);
```

With:
```dart
final db = ServiceLocator.instance.database;
final matches = await db.getProductsByBarcode(code);
if (matches.length > 1) return BarcodeMultiVariant(code, matches);
if (matches.length == 1) {
  final match = matches.first;
  return BarcodeMatched(product: match.product, unit: match.unit);
}

// --- LOCAL DB MISS: Try Open Food Facts API ---
try {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
    headers: {'User-Agent': 'AeroPOS_App/1.0'},
  ));

  final response =
      await dio.get('https://world.openfoodfacts.org/api/v0/product/$code.json');

  if (response.statusCode == 200) {
    final data = response.data;
    if (data['status'] == 1 && data['product'] != null) {
      final productData = data['product'];
      final name = productData['product_name'] ??
          productData['brands'] ??
          'Unknown Product';
      final imageUrl = productData['image_front_small_url'];

      return BarcodeFoundExternally(
        rawCode: code,
        suggestedName: name,
        imageUrl: imageUrl,
      );
    }
  }
} catch (e) {
  debugPrint('Open Food Facts API failed: $e');
}

// --- TOTAL MISS ---
return BarcodeNotFound(code);
```

---

### 3. `ezo/lib/core/database/app_database.dart`
**Action:** Add `insertQuickProduct` method after `getProductsByBarcode` (after line 759).

```dart
  Future<({ProductEntity product, ProductUnitEntity unit})> insertQuickProduct({
    required String barcode,
    required String name,
    required double sellingPrice,
    required int defaultUnitId,
  }) async {
    return transaction(() async {
      const uuidGen = Uuid();
      final productUuid = uuidGen.v4();
      final unitUuid = uuidGen.v4();
      const tenantId = 1;
      const syncStatus = 1;

      final productId = await into(products).insert(
        ProductsCompanion.insert(
          uuid: Value(productUuid),
          tenantId: const Value(tenantId),
          syncStatus: const Value(syncStatus),
          name: name,
          price: sellingPrice,
          isDeleted: const Value(false),
        ),
      );

      final unitId = await into(productUnits).insert(
        ProductUnitsCompanion.insert(
          uuid: Value(unitUuid),
          tenantId: const Value(tenantId),
          syncStatus: const Value(syncStatus),
          productId: productId,
          unitId: defaultUnitId,
          barcode: Value(barcode),
          conversionFactor: 1.0,
          sellingPrice: Value(sellingPrice),
          isDefault: const Value(true),
          isDeleted: const Value(false),
        ),
      );

      final newProduct =
          await (select(products)..where((t) => t.id.equals(productId))).getSingle();
      final newUnit =
          await (select(productUnits)..where((t) => t.id.equals(unitId))).getSingle();

      return (product: newProduct, unit: newUnit);
    });
  }
```

---

### 4. `ezo/lib/features/pos/widgets/quick_add_product_dialog.dart` (NEW FILE)

```dart
import 'package:flutter/material.dart';

class QuickAddProductDialog extends StatefulWidget {
  final String barcode;
  final String productName;

  const QuickAddProductDialog({
    super.key,
    required this.barcode,
    required this.productName,
  });

  @override
  State<QuickAddProductDialog> createState() => _QuickAddProductDialogState();
}

class _QuickAddProductDialogState extends State<QuickAddProductDialog> {
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '1');
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.productName;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _stockController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Internet Match Found'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: ${widget.barcode}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Selling Price',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Initial Stock',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_priceController.text.isEmpty ||
                _nameController.text.isEmpty) return;
            Navigator.pop(context, {
              'name': _nameController.text,
              'price': double.tryParse(_priceController.text) ?? 0.0,
              'stock': int.tryParse(_stockController.text) ?? 1,
            });
          },
          child: const Text('Save & Bill'),
        ),
      ],
    );
  }
}
```

---

### 5. `ezo/lib/features/pos/pos_screen.dart`
**Action:** Add import for dialog + `ISyncService`, and add `BarcodeFoundExternally` case in switch.

**Import** — add after line 17:
```dart
import 'package:aeropos/features/pos/widgets/quick_add_product_dialog.dart';
import 'package:aeropos/core/services/i_sync_service.dart';
```

**Switch case** — insert as a new case before `BarcodeNotFound` (line 212):

```dart
      case BarcodeFoundExternally(:final rawCode, :final suggestedName):
        await _playBeep(false);

        if (mounted) {
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => QuickAddProductDialog(
              barcode: rawCode,
              productName: suggestedName,
            ),
          );

          if (result != null && mounted) {
            final db = ServiceLocator.instance.database;

            final allUnits = await db.select(db.units).get();
            if (allUnits.isEmpty) {
              throw Exception('No master units found in database');
            }

            final pieceUnit = allUnits.firstWhere(
              (u) =>
                  u.name.toLowerCase() == 'piece' ||
                  u.name.toLowerCase() == 'pcs',
              orElse: () => allUnits.first,
            );

            final newItems = await db.insertQuickProduct(
              barcode: rawCode,
              name: result['name'],
              sellingPrice: result['price'],
              defaultUnitId: pieceUnit.id,
            );

            final syncService = ServiceLocator.instance.syncEngine;
            await syncService.logOperation(
              entity: 'products',
              entityId: newItems.product.uuid,
              opType: 1,
              data: {
                'uuid': newItems.product.uuid,
                'name': result['name'],
                'price': result['price'],
              },
            );
            await syncService.logOperation(
              entity: 'product_units',
              entityId: newItems.unit.uuid,
              opType: 1,
              data: {
                'uuid': newItems.unit.uuid,
                'product_id': newItems.product.uuid,
                'barcode': rawCode,
                'selling_price': result['price'],
                'conversion_factor': 1.0,
              },
            );

            final pu = ProductUnit(
              id: newItems.unit.id,
              productId: newItems.unit.productId,
              unitId: newItems.unit.unitId,
              conversionFactor: newItems.unit.conversionFactor,
              sellingPrice: newItems.unit.sellingPrice,
              barcode: newItems.unit.barcode,
              isDefault: newItems.unit.isDefault,
            );

            ref.read(cartProvider.notifier).addProduct(
              newItems.product,
              selectedUnit: pu,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${result['name']} added to inventory!')),
              );
            }
          }
        }
```

---

### Final corrections (verified against actual codebase)

#### Issue 1: `ServiceLocator.instance.get<T>()` doesn't exist
Use direct property access instead:
- `ServiceLocator.instance.syncEngine`  (implements `ISyncService`)
- `ServiceLocator.instance.syncRepository`  (type `SyncRepository`, no interface)

#### Issue 2: `ISyncService.logOperation` signature
Actual signature:
```dart
logOperation({required String entity, required String entityId, required int opType, required Map<String, dynamic> data})
```
Not `tableName`/`operation`.

#### Issue 3: Drift `insert()` required fields
For `ProductsCompanion.insert()` and `ProductUnitsCompanion.insert()`:
- Required fields (no DB default): pass as **direct values** (`uuid: productUuid`, `tenantId: tenantId`)
- Optional fields (have DB default or nullable): pass as `Value(...)` (`stockQuantity: Value(initialStock)`, `isDeleted: const Value(false)`)

**Corrected POS screen sync block:**
```dart
// 3. Log Sync Operations
final syncService = ServiceLocator.instance.syncEngine;
await syncService.logOperation(
  entity: 'products',
  entityId: newItems.product.uuid,
  opType: 1,
  data: {
    'uuid': newItems.product.uuid,
    'name': newItems.product.name,
    'price': newItems.product.price,
  },
);
await syncService.logOperation(
  entity: 'product_units',
  entityId: newItems.unit.uuid,
  opType: 1,
  data: {
    'uuid': newItems.unit.uuid,
    'product_id': newItems.product.uuid,
    'barcode': rawCode,
    'selling_price': newItems.unit.sellingPrice,
    'conversion_factor': 1.0,
  },
);

// 4. Log Stock Delta
if (stock > 0) {
  final syncRepo = ServiceLocator.instance.syncRepository;
  await syncRepo.logStockDelta(
    productId: newItems.product.id.toString(),
    delta: stock.toDouble(),
    reason: 'initial_stock',
  );
}
```

### Verification

After applying all changes, run:
```bash
cd ezo && flutter analyze
```
