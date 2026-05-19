import 'package:drift/drift.dart';
import 'package:aeropos/core/database/tables/purchase_receipts_table.dart';
import 'package:aeropos/core/database/tables/products_table.dart';
import 'package:aeropos/core/database/tables/units_table.dart';

@DataClassName('PurchaseReceiptItemEntity')
class PurchaseReceiptItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get receiptId => integer().references(PurchaseReceipts, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  IntColumn get unitId => integer().references(Units, #id)();
  RealColumn get price => real()();
  RealColumn get totalPrice => real()();
  RealColumn get discountPerItem => real().nullable()();
  RealColumn get taxPerItem => real().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}
