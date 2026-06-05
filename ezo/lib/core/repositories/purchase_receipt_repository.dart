import 'package:aeropos/core/database/app_database.dart';

abstract class PurchaseReceiptRepository {
  Future<int> insertPurchaseReceipt(PurchaseReceiptsCompanion entry);
  Future<List<PurchaseReceiptEntity>> getAllPurchaseReceipts();
  Stream<List<PurchaseReceiptEntity>> watchAllPurchaseReceipts(int companyId);
  Future<void> deletePurchaseReceipt(int id);
  Future<void> updatePurchaseReceipt(PurchaseReceiptEntity entry);

  Future<int> createPurchaseWithItems({
    required PurchaseReceiptsCompanion header,
    required List<PurchaseReceiptItemsCompanion> items,
  });

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
  });

  Future<void> updateProductStock(
    int productId,
    double additionalQuantity, {
    int? unitId,
  });

  Stream<List<PurchaseReceiptItemEntity>> watchItemsByReceiptId(int receiptId);
  Future<List<PurchaseReceiptItemEntity>> getItemsByReceiptId(int receiptId);
}
