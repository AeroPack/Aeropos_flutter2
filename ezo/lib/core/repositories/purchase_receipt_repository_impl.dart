import 'package:drift/drift.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/repositories/purchase_receipt_repository.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/services/unit_conversion_service.dart';

class PurchaseReceiptRepositoryImpl implements PurchaseReceiptRepository {
  final AppDatabase db;

  PurchaseReceiptRepositoryImpl(this.db);

  @override
  Future<int> insertPurchaseReceipt(PurchaseReceiptsCompanion entry) async {
    final syncEngine = ServiceLocator.instance.syncEngine;
    return await db.transaction(() async {
      final id = await db.into(db.purchaseReceipts).insert(entry);
      if (entry.uuid.present) {
        await syncEngine.logOperation(
          entity: 'purchase_receipts',
          entityId: entry.uuid.value,
          opType: 1,
          data: _companionToData(entry, hasItems: false),
        );
      }
      return id;
    });
  }

  @override
  Future<List<PurchaseReceiptEntity>> getAllPurchaseReceipts() async {
    return await (db.select(db.purchaseReceipts)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  @override
  Stream<List<PurchaseReceiptEntity>> watchAllPurchaseReceipts(int tenantId) {
    return (db.select(db.purchaseReceipts)
          ..where(
            (t) => t.isDeleted.equals(false) & t.tenantId.equals(tenantId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  @override
  Future<void> deletePurchaseReceipt(int id) async {
    final syncEngine = ServiceLocator.instance.syncEngine;
    final entity = await (db.select(db.purchaseReceipts)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (entity == null) return;

    final now = DateTime.now();
    await (db.update(db.purchaseReceipts)..where((t) => t.id.equals(id))).write(
      PurchaseReceiptsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
        syncStatus: const Value(1),
      ),
    );
    await syncEngine.logOperation(
      entity: 'purchase_receipts',
      entityId: entity.uuid,
      opType: 3,
      data: _entityToData(entity),
    );
  }

  @override
  Future<void> updatePurchaseReceipt(PurchaseReceiptEntity entry) async {
    final syncEngine = ServiceLocator.instance.syncEngine;
    await (db.update(
      db.purchaseReceipts,
    )..where((t) => t.id.equals(entry.id))).write(entry.toCompanion(true));
    await syncEngine.logOperation(
      entity: 'purchase_receipts',
      entityId: entry.uuid,
      opType: 2,
      data: _entityToData(entry),
    );
  }

  @override
  Future<int> createPurchaseWithItems({
    required PurchaseReceiptsCompanion header,
    required List<PurchaseReceiptItemsCompanion> items,
  }) async {
    final syncEngine = ServiceLocator.instance.syncEngine;
    return await db.transaction(() async {
      final receiptId = await db.into(db.purchaseReceipts).insert(header);

      for (final item in items) {
        final itemWithReceiptId = PurchaseReceiptItemsCompanion(
          receiptId: Value(receiptId),
          productId: item.productId,
          quantity: item.quantity,
          unitId: item.unitId,
          price: item.price,
          totalPrice: item.totalPrice,
          discountPerItem: item.discountPerItem,
          taxPerItem: item.taxPerItem,
          isDeleted: const Value(false),
        );
        await db.into(db.purchaseReceiptItems).insert(itemWithReceiptId);

        final product = await (db.select(
          db.products,
        )..where((t) => t.id.equals(item.productId.value))).getSingleOrNull();

        if (product != null) {
          final conversionService = UnitConversionService(db);
          final unitId = item.unitId.value;
          final qtyInBase = await conversionService.convertToBaseUnit(
            productId: item.productId.value,
            quantity: item.quantity.value.toDouble(),
fromUnitId: unitId,
          );
          final newStock = product.stockQuantity + qtyInBase.toInt();
          await (db.update(
            db.products,
          )..where((t) => t.id.equals(item.productId.value))).write(
            ProductsCompanion(
              stockQuantity: Value(newStock),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(1),
            ),
          );
        }
      }

      if (header.uuid.present) {
        final itemsData = items.map((item) {
          final m = <String, dynamic>{
            'product_id': item.productId.value,
            'quantity': item.quantity.value,
            'total_price': item.totalPrice.value,
            'price': item.price.value,
          };
          if (item.unitId.present) m['unit_id'] = item.unitId.value;
          if (item.discountPerItem.present) m['discount_per_item'] = item.discountPerItem.value;
          if (item.taxPerItem.present) m['tax_per_item'] = item.taxPerItem.value;
          return m;
        }).toList();

        final data = _companionToData(header, hasItems: true);
        data['items'] = itemsData;
        await syncEngine.logOperation(
          entity: 'purchase_receipts',
          entityId: header.uuid.value,
          opType: 1,
          data: data,
        );
      }

      return receiptId;
    });
  }

  @override
  Future<void> updateProductStock(
    int productId,
    double additionalQuantity, {
    int? unitId,
  }) async {
    final product = await (db.select(
      db.products,
    )..where((t) => t.id.equals(productId))).getSingleOrNull();

    if (product != null) {
      final conversionService = UnitConversionService(db);
      final qtyInBase = await conversionService.convertToBaseUnit(
        productId: productId,
        quantity: additionalQuantity,
        fromUnitId: unitId ?? product.unitId ?? 1,
      );
      final newStock = product.stockQuantity + qtyInBase.toInt();
      await (db.update(
        db.products,
      )..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          stockQuantity: Value(newStock),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(1),
        ),
      );
    }
  }

  @override
  Future<void> updatePurchaseWithItems({
    required int receiptId,
    required int supplierId,
    required DateTime date,
    String? supplierInvoiceNumber,
    required double subtotal,
    required double tax,
    required double discount,
    required double totalAmount,
    String? notes,
    required List<PurchaseReceiptItemsCompanion> items,
  }) async {
    final syncEngine = ServiceLocator.instance.syncEngine;
    final existing = await (db.select(db.purchaseReceipts)
          ..where((t) => t.id.equals(receiptId)))
        .getSingleOrNull();
    if (existing == null) return;

    await db.transaction(() async {
      await (db.update(
        db.purchaseReceipts,
      )..where((t) => t.id.equals(receiptId))).write(
        PurchaseReceiptsCompanion(
          supplierId: Value(supplierId),
          date: Value(date),
          supplierInvoiceNumber: Value(supplierInvoiceNumber),
          subtotal: Value(subtotal),
          tax: Value(tax),
          discount: Value(discount),
          totalAmount: Value(totalAmount),
          notes: Value(notes),
          updatedAt: Value(DateTime.now()),
          syncStatus: Value(1),
        ),
      );

      await (db.delete(
        db.purchaseReceiptItems,
      )..where((t) => t.receiptId.equals(receiptId))).go();

      for (final item in items) {
        final itemWithReceiptId = PurchaseReceiptItemsCompanion(
          receiptId: Value(receiptId),
          productId: item.productId,
          quantity: item.quantity,
          unitId: item.unitId,
          price: item.price,
          totalPrice: item.totalPrice,
          discountPerItem: item.discountPerItem,
          taxPerItem: item.taxPerItem,
          isDeleted: const Value(false),
        );
        await db.into(db.purchaseReceiptItems).insert(itemWithReceiptId);
      }

      final itemsData = items.map((item) {
        final m = <String, dynamic>{
          'product_id': item.productId.value,
          'quantity': item.quantity.value,
          'total_price': item.totalPrice.value,
          'price': item.price.value,
        };
        if (item.unitId.present) m['unit_id'] = item.unitId.value;
        if (item.discountPerItem.present) m['discount_per_item'] = item.discountPerItem.value;
        if (item.taxPerItem.present) m['tax_per_item'] = item.taxPerItem.value;
        return m;
      }).toList();

      await syncEngine.logOperation(
        entity: 'purchase_receipts',
        entityId: existing.uuid,
        opType: 2,
        data: {
          'supplier_id': supplierId,
          'supplier_invoice_number': supplierInvoiceNumber,
          'subtotal': subtotal,
          'tax': tax,
          'discount': discount,
          'total_amount': totalAmount,
          'notes': notes,
          'date': date.toIso8601String(),
          'items': itemsData,
        },
      );
    });
  }

  @override
  Stream<List<PurchaseReceiptItemEntity>> watchItemsByReceiptId(int receiptId) {
    return (db.select(db.purchaseReceiptItems)..where(
          (t) => t.receiptId.equals(receiptId) & t.isDeleted.equals(false),
        ))
        .watch();
  }

  @override
  Future<List<PurchaseReceiptItemEntity>> getItemsByReceiptId(
    int receiptId,
  ) async {
    return await (db.select(db.purchaseReceiptItems)..where(
          (t) => t.receiptId.equals(receiptId) & t.isDeleted.equals(false),
        ))
        .get();
  }

  Map<String, dynamic> _companionToData(
    PurchaseReceiptsCompanion c, {
    bool hasItems = false,
  }) {
    final data = <String, dynamic>{};
    if (c.invoiceNumber.present) data['invoice_number'] = c.invoiceNumber.value;
    if (c.supplierInvoiceNumber.present) data['supplier_invoice_number'] = c.supplierInvoiceNumber.value;
    if (c.supplierId.present) data['supplier_id'] = c.supplierId.value;
    if (c.subtotal.present) data['subtotal'] = c.subtotal.value;
    if (c.tax.present) data['tax'] = c.tax.value;
    if (c.discount.present) data['discount'] = c.discount.value;
    if (c.totalAmount.present) data['total_amount'] = c.totalAmount.value;
    if (c.notes.present) data['notes'] = c.notes.value;
    if (c.status.present) data['status'] = c.status.value;
    if (c.createdBy.present) data['created_by'] = c.createdBy.value;
    if (c.date.present) data['date'] = c.date.value.toIso8601String();
    data['is_deleted'] = false;
    return data;
  }

  Map<String, dynamic> _entityToData(PurchaseReceiptEntity entity) {
    return {
      'invoice_number': entity.invoiceNumber,
      'supplier_invoice_number': entity.supplierInvoiceNumber,
      'supplier_id': entity.supplierId,
      'subtotal': entity.subtotal,
      'tax': entity.tax,
      'discount': entity.discount,
      'total_amount': entity.totalAmount,
      'notes': entity.notes,
      'status': entity.status,
      'created_by': entity.createdBy,
      'date': entity.date.toIso8601String(),
      'is_deleted': entity.isDeleted,
    };
  }
}
