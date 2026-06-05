import 'package:drift/drift.dart' as drift;
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/repositories/purchase_receipt_repository.dart';
import 'package:uuid/uuid.dart';

class PurchaseReceiptViewModel {
  final PurchaseReceiptRepository _repository;
  final AppDatabase _database;
  final _uuid = const Uuid();

  PurchaseReceiptViewModel(this._repository, this._database);

  int get _companyId => ServiceLocator.instance.sessionService.companyId;

  Stream<List<PurchaseReceiptEntity>> get allReceipts =>
      _repository.watchAllPurchaseReceipts(_companyId);

  Future<List<PurchaseReceiptEntity>> getAllReceipts() =>
      _repository.getAllPurchaseReceipts();

  Future<void> deleteReceipt(int id) async {
    await _repository.deletePurchaseReceipt(id);
  }

  Future<void> updateReceipt(PurchaseReceiptEntity entry) async {
    final updated = entry.copyWith(updatedAt: DateTime.now(), syncStatus: 1);
    await _repository.updatePurchaseReceipt(updated);
  }

  Future<SupplierEntity?> getSupplierById(int id) async {
    final suppliers = await (_database.select(
      _database.suppliers,
    )..where((t) => t.id.equals(id) & t.isDeleted.equals(false))).get();
    return suppliers.isNotEmpty ? suppliers.first : null;
  }

  Future<ProductEntity?> getProductById(int id) async {
    final products = await (_database.select(
      _database.products,
    )..where((t) => t.id.equals(id) & t.isDeleted.equals(false))).get();
    return products.isNotEmpty ? products.first : null;
  }

  Future<String> generateNextInvoiceNumber() async {
    final skuGenerator = ServiceLocator.instance.skuGenerator;
    final invoiceNumber = await skuGenerator.generateNextSku();
    return 'PR-$invoiceNumber';
  }

  Future<int> createPurchaseWithItems({
    required int supplierId,
    required DateTime date,
    String? supplierInvoiceNumber,
    double subtotal = 0.0,
    double tax = 0.0,
    double discount = 0.0,
    double totalAmount = 0.0,
    String? notes,
    required List<PurchaseItemData> items,
  }) async {
    final invoiceNumber = await generateNextInvoiceNumber();

    final header = PurchaseReceiptsCompanion(
      uuid: drift.Value(_uuid.v4()),
      invoiceNumber: drift.Value(invoiceNumber),
      supplierInvoiceNumber: drift.Value(supplierInvoiceNumber),
      supplierId: drift.Value(supplierId),
      subtotal: drift.Value(subtotal),
      tax: drift.Value(tax),
      discount: drift.Value(discount),
      totalAmount: drift.Value(totalAmount),
      notes: drift.Value(notes),
      status: const drift.Value('COMPLETED'),
      date: drift.Value(date),
      companyId: drift.Value(_companyId),
      syncStatus: const drift.Value(1),
      isDeleted: const drift.Value(false),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    );

    final itemsCompanions = items
        .map(
          (item) => PurchaseReceiptItemsCompanion(
            productId: drift.Value(item.productId),
            quantity: drift.Value(item.quantity),
            unitId: drift.Value(item.unitId),
            price: drift.Value(item.price),
            totalPrice: drift.Value(item.totalPrice),
            discountPerItem: item.discountPerItem != null
                ? drift.Value(item.discountPerItem)
                : const drift.Value.absent(),
            taxPerItem: item.taxPerItem != null
                ? drift.Value(item.taxPerItem)
                : const drift.Value.absent(),
            isDeleted: const drift.Value(false),
          ),
        )
        .toList();

    return await _repository.createPurchaseWithItems(
      header: header,
      items: itemsCompanions,
    );
  }

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
    required List<PurchaseItemData> items,
  }) async {
    final itemsCompanions = items
        .map(
          (item) => PurchaseReceiptItemsCompanion(
            productId: drift.Value(item.productId),
            quantity: drift.Value(item.quantity),
            unitId: drift.Value(item.unitId),
            price: drift.Value(item.price),
            totalPrice: drift.Value(item.totalPrice),
            discountPerItem: item.discountPerItem != null
                ? drift.Value(item.discountPerItem)
                : const drift.Value.absent(),
            taxPerItem: item.taxPerItem != null
                ? drift.Value(item.taxPerItem)
                : const drift.Value.absent(),
            isDeleted: const drift.Value(false),
          ),
        )
        .toList();

    await _repository.updatePurchaseWithItems(
      receiptId: receiptId,
      supplierId: supplierId,
      date: date,
      supplierInvoiceNumber: supplierInvoiceNumber,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      totalAmount: totalAmount,
      notes: notes,
      items: itemsCompanions,
    );
  }

  Stream<List<PurchaseReceiptItemEntity>> watchItemsByReceiptId(int receiptId) {
    return _repository.watchItemsByReceiptId(receiptId);
  }

  Future<List<PurchaseReceiptItemEntity>> getItemsByReceiptId(int receiptId) {
    return _repository.getItemsByReceiptId(receiptId);
  }
}

class PurchaseItemData {
  final int productId;
  final double quantity;
  final int unitId;
  final double price;
  final double totalPrice;
  final double? discountPerItem;
  final double? taxPerItem;

  PurchaseItemData({
    required this.productId,
    required this.quantity,
    required this.unitId,
    required this.price,
    required this.totalPrice,
    this.discountPerItem,
    this.taxPerItem,
  });
}
