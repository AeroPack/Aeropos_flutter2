import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../database/app_database.dart';
import '../di/service_locator.dart';
import 'sync_repository.dart';

class SaleRepository {
  final AppDatabase _db;
  SaleRepository(this._db);

  Future<List<Sale>> getAllSales() async {
    final invoiceEntities = await _db.getAllInvoices();
    List<Sale> sales = [];
    for (var entity in invoiceEntities) {
      final items = await getSaleItems(entity.id);
      sales.add(
        Sale(
          id: entity.id,
          uuid: entity.uuid,
          invoiceNumber: entity.invoiceNumber,
          customerId: entity.customerId,
          subtotal: entity.subtotal,
          tax: entity.tax,
          discount: entity.discount,
          total: entity.total,
          paymentMethod: entity.paymentMethod,
          createdAt: entity.date,
          isDeleted: entity.isDeleted,
          items: items,
        ),
      );
    }
    return sales;
  }

  Stream<List<Sale>> watchAllSales() {
    return _db.watchAllInvoices().map((entities) {
      return entities
          .map(
            (entity) => Sale(
              id: entity.id,
              uuid: entity.uuid,
              invoiceNumber: entity.invoiceNumber,
              customerId: entity.customerId,
              subtotal: entity.subtotal,
              tax: entity.tax,
              discount: entity.discount,
              total: entity.total,
              paymentMethod: entity.paymentMethod,
              createdAt: entity.date,
              isDeleted: entity.isDeleted,
              items: [],
            ),
          )
          .toList();
    });
  }

  Stream<List<TypedResult>> watchSalesWithCustomer() {
    final companyId = ServiceLocator.instance.sessionService.companyId;
    return _db.watchInvoicesWithCustomer(companyId: companyId);
  }

  Future<Sale?> getSaleById(int id) async {
    final sales = await getAllSales();
    try {
      return sales.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<int> createSale(Sale sale) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final companyId = ServiceLocator.instance.sessionService.companyId;

    return await _db.transaction(() async {
      // 1. Insert Invoice header
      final invoiceId = await _db.insertInvoice(
        InvoicesCompanion.insert(
          uuid: sale.uuid,
          invoiceNumber: sale.invoiceNumber,
          date: sale.createdAt,
          subtotal: sale.subtotal,
          tax: sale.tax,
          discount: Value(sale.discount),
          total: sale.total,
          paymentMethod: Value(sale.paymentMethod),
          customerId: Value(sale.customerId),
          isDeleted: Value(false),
          updatedAt: Value(DateTime.now()),
          companyId: companyId,
        ),
      );

      // 2. Insert Invoice items
      final itemCompanions = sale.items
          .map(
            (item) => InvoiceItemsCompanion.insert(
              invoiceId: invoiceId,
              productId: item.productId,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              discount: Value(item.discount),
              totalPrice: item.total,
              uuid: item.uuid.isEmpty ? const Uuid().v4() : item.uuid,
              isDeleted: Value(false),
              updatedAt: Value(DateTime.now()),
              companyId: companyId,
            ),
          )
          .toList();

      await _db.insertInvoiceItems(itemCompanions);

      // 3. Log stock deltas (DELTA ONLY, not absolute)
      for (final item in sale.items) {
        await syncRepo.logStockDelta(
          productId: item.productId.toString(),
          delta: -item.quantity.toDouble(),
          reason: 'sale',
          refId: invoiceId.toString(),
        );
      }

      // 4. Log sale operation to sync_outbox
      await syncRepo.logOperation(
        entity: 'invoices',
        entityId: sale.uuid,
        opType: SyncOpType.insert,
        data: sale.toJson(),
      );

      // 5. Log each invoice item to sync_outbox (LAST step)
      for (final item in sale.items) {
        await syncRepo.logOperation(
          entity: 'invoice_items',
          entityId: item.uuid,
          opType: SyncOpType.insert,
          data: {
            'uuid': item.uuid,
            'invoice_uuid': sale.uuid,
            'product_uuid': item.product.uuid,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'discount': item.discount,
            'total_price': item.total,
            'is_deleted': false,
          },
        );
      }

      return invoiceId;
    });
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final results = await _db.getInvoiceItemsWithProduct(saleId);
    return results.map((row) {
      final item = row.readTable(_db.invoiceItems);
      final product = row.readTable(_db.products);
      return SaleItem(
        id: item.id,
        uuid: item.uuid,
        saleId: item.invoiceId,
        productId: item.productId,
        product: product,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        discount: item.discount,
        total: item.totalPrice,
        isDeleted: item.isDeleted,
      );
    }).toList();
  }

  Future<List<String>> validateSaleProducts(Sale sale) async {
    final validationErrors = <String>[];
    for (final item in sale.items) {
      final product = await (_db.select(
        _db.products,
      )..where((t) => t.id.equals(item.productId))).getSingleOrNull();
      if (product == null) {
        validationErrors.add('Product ID ${item.productId} not found');
      } else if (product.stockQuantity < item.quantity) {
        validationErrors.add('Insufficient stock for ${product.name}');
      }
    }
    return validationErrors;
  }

  Future<bool> deleteSale(int id) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final entity = await (_db.select(
      _db.invoices,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entity == null) return false;

    return await _db.transaction(() async {
      // Soft delete invoice
      await (_db.update(_db.invoices)..where((t) => t.id.equals(id))).write(
        InvoicesCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Soft delete items
      await (_db.update(
        _db.invoiceItems,
      )..where((t) => t.invoiceId.equals(id))).write(
        InvoiceItemsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Log delete to sync_outbox
      await syncRepo.logOperation(
        entity: 'invoices',
        entityId: entity.uuid,
        opType: SyncOpType.delete,
        data: null,
      );

      return true;
    });
  }
}
