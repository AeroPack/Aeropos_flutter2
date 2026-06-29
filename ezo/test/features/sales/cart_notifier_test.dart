import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/core/database/app_database.dart';

void main() {
  final now = DateTime.now();

  final productExclusive = ProductEntity(
    id: 1,
    uuid: 'p1',
    name: 'Test Product Exclusive',
    sku: 'SKU001',
    price: 100.0,
    companyId: 1,
    createdAt: now,
    updatedAt: now,
    gstType: 'Exclusive',
    gstRate: '18%',
    allowLooseSale: true,
    stockQuantity: 0,
    isActive: true,
    discount: 0.0,
    isPercentDiscount: false,
    syncStatus: 0,
    isDeleted: false,
  );

  final productInclusive = ProductEntity(
    id: 2,
    uuid: 'p2',
    name: 'Test Product Inclusive',
    sku: 'SKU002',
    price: 118.0,
    companyId: 1,
    createdAt: now,
    updatedAt: now,
    gstType: 'Inclusive',
    gstRate: '18%',
    allowLooseSale: true,
    stockQuantity: 0,
    isActive: true,
    discount: 0.0,
    isPercentDiscount: false,
    syncStatus: 0,
    isDeleted: false,
  );

  group('Cart GST Calculations', () {
    test('Exclusive GST calculation', () {
      final notifier = CartNotifier();
      notifier.addProduct(productExclusive, quantity: 1.0);

      expect(notifier.state.taxAmount, closeTo(18.0, 0.01));
      expect(notifier.state.subtotal, closeTo(100.0, 0.01));
      expect(notifier.state.total, closeTo(118.0, 0.01));
    });

    test('Inclusive GST calculation', () {
      final notifier = CartNotifier();
      notifier.addProduct(productInclusive, quantity: 1.0);

      expect(notifier.state.taxAmount, closeTo(18.0, 0.01));
      expect(notifier.state.subtotal, closeTo(100.0, 0.01));
      expect(notifier.state.total, closeTo(118.0, 0.01));
    });

    test('Multiple items GST calculation', () {
      final notifier = CartNotifier();
      notifier.addProduct(productExclusive, quantity: 1.0); // 100 + 18
      notifier.addProduct(productInclusive, quantity: 1.0); // 100 + 18 (price 118)

      expect(notifier.state.taxAmount, closeTo(36.0, 0.01));
      expect(notifier.state.subtotal, closeTo(200.0, 0.01));
      expect(notifier.state.total, closeTo(236.0, 0.01));
    });

    test('Excluding keyword support', () {
      final productExcluding = productExclusive.copyWith(gstType: const Value('excluding'));
      final notifier = CartNotifier();
      notifier.addProduct(productExcluding, quantity: 1.0);

      expect(notifier.state.taxAmount, closeTo(18.0, 0.01));
    });
  });
}
