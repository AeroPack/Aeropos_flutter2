import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/models/product_unit.dart';
import 'package:aeropos/features/pos/state/pos_category_state.dart';

// 1. Models
class CartItem {
  final ProductEntity product;
  final double quantity;
  final ProductUnit? selectedUnit;
  final double manualDiscount;
  final bool isPercentDiscount;
  final double? manualUnitPrice;
  final List<String>? modifiers;
  final String? course;

  const CartItem({
    required this.product,
    this.quantity = 1.0,
    this.selectedUnit,
    this.manualDiscount = 0.0,
    this.isPercentDiscount = false,
    this.manualUnitPrice,
    this.modifiers,
    this.course,
  });

  double get unitPrice => quantity > 0 ? calculatedPrice / quantity : 0;

  double get calculatedPrice {
    if (manualUnitPrice != null) return manualUnitPrice! * quantity;
    if (selectedUnit == null) {
      return product.price * quantity;
    }

    final qtyInBase = quantity * selectedUnit!.conversionFactor;

    // Case 1: Selected unit has its own selling_price
    if (selectedUnit!.sellingPrice != null) {
      return selectedUnit!.sellingPrice! * quantity;
    }

    // Case 2: Derive from another unit with selling_price (highest conversion_factor)
    // This requires productUnits from cache - need to check via CartNotifier
    // For now, fall back to product price
    if (product.price > 0) {
      final rawPrice = qtyInBase * product.price;
      return rawPrice.roundToDouble();
    }

    return product.price * quantity;
  }

  double get taxRate {
    final rateStr = product.gstRate?.replaceAll('%', '') ?? '0';
    return double.tryParse(rateStr) ?? 0.0;
  }

  double get tax {
    final rate = taxRate;
    final effectivePrice = selectedUnit != null
        ? calculatedPrice
        : (product.price * quantity);
    double discountAmount = manualDiscount;
    if (isPercentDiscount) {
      discountAmount = effectivePrice * (manualDiscount / 100);
    }
    final totalBeforeTax = effectivePrice - discountAmount;

    if (product.gstType?.toLowerCase() == 'exclusive' ||
        product.gstType?.toLowerCase() == 'excluding') {
      return (totalBeforeTax * rate) / 100;
    } else {
      return (totalBeforeTax * rate) / (100 + rate);
    }
  }

  double get subtotal {
    final effectivePrice = selectedUnit != null
        ? calculatedPrice
        : (product.price * quantity);
    double discountAmount = manualDiscount;
    if (isPercentDiscount) {
      discountAmount = effectivePrice * (manualDiscount / 100);
    }
    final totalBeforeTax = effectivePrice - discountAmount;
    if (product.gstType?.toLowerCase() == 'exclusive' ||
        product.gstType?.toLowerCase() == 'excluding') {
      return totalBeforeTax;
    } else {
      return totalBeforeTax - tax;
    }
  }

  double get total => subtotal + tax;

  CartItem copyWith({
    ProductEntity? product,
    double? quantity,
    ProductUnit? selectedUnit,
    double? basePrice,
    double? manualDiscount,
    bool? isPercentDiscount,
    double? manualUnitPrice,
    List<String>? modifiers,
    String? course,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedUnit: selectedUnit ?? this.selectedUnit,
      manualDiscount: manualDiscount ?? this.manualDiscount,
      isPercentDiscount: isPercentDiscount ?? this.isPercentDiscount,
      manualUnitPrice: manualUnitPrice ?? this.manualUnitPrice,
      modifiers: modifiers ?? this.modifiers,
      course: course ?? this.course,
    );
  }
}

class CartState {
  final List<CartItem> items;
  final CustomerEntity? selectedCustomer;
  final double overallDiscount; // The value (either Rs or %)
  final bool isOverallPercent;
  final Map<String, double> additionalCharges;
  final String notes;

  const CartState({
    this.items = const [],
    this.selectedCustomer,
    this.overallDiscount = 0.0,
    this.isOverallPercent = false,
    this.additionalCharges = const {},
    this.notes = '',
  });

  double get itemDiscounts => items.fold(0.0, (sum, item) {
    if (item.isPercentDiscount) {
      return sum +
          (item.product.price * item.quantity * (item.manualDiscount / 100));
    }
    return sum + item.manualDiscount;
  });

  double get overallDiscountAmount {
    final itemTotal = items.fold(0.0, (sum, item) => (sum) + (item.total));
    if (isOverallPercent) {
      return itemTotal * (overallDiscount / 100);
    }
    return overallDiscount;
  }

  double get totalDiscount => itemDiscounts + overallDiscountAmount;

  double get subtotal =>
      items.fold(0.0, (sum, item) => (sum) + (item.subtotal));
  double get taxAmount => items.fold(0.0, (sum, item) => (sum) + (item.tax));
  double get additionalChargesTotal =>
      additionalCharges.values.fold(0.0, (s, v) => s + v);

  double get total {
    final itemTotal = items.fold(0.0, (sum, item) => (sum) + (item.total));
    return itemTotal - overallDiscountAmount + additionalChargesTotal;
  }

  CartState copyWith({
    List<CartItem>? items,
    CustomerEntity? selectedCustomer,
    double? overallDiscount,
    bool? isOverallPercent,
    Map<String, double>? additionalCharges,
    String? notes,
  }) {
    return CartState(
      items: items ?? this.items,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      overallDiscount: overallDiscount ?? this.overallDiscount,
      isOverallPercent: isOverallPercent ?? this.isOverallPercent,
      additionalCharges: additionalCharges ?? this.additionalCharges,
      notes: notes ?? this.notes,
    );
  }
}

// 2. Notifier
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  static const int _maxCacheEntries = 50;
  final Map<int, List<ProductUnit>> _productUnitsCache = {};

  Future<void> loadProductUnits(int productId) async {
    if (_productUnitsCache.containsKey(productId)) return;

    final db = ServiceLocator.instance.database;
    final dao = db.productUnitDao;
    final units = await dao.getUnitsForProduct(productId);
    _productUnitsCache[productId] = units;
  }

  void setProductUnitsCache(int productId, List<ProductUnit> units) {
    if (_productUnitsCache.length >= _maxCacheEntries) {
      _productUnitsCache.remove(_productUnitsCache.keys.first);
    }
    _productUnitsCache[productId] = units;
  }

  List<ProductUnit>? getProductUnits(int productId) {
    return _productUnitsCache[productId];
  }

  double calculatePrice({
    required ProductEntity product,
    required double quantity,
    required ProductUnit? selectedUnit,
  }) {
    if (selectedUnit == null) {
      return product.price * quantity;
    }

    final qtyInBase = quantity * selectedUnit.conversionFactor;

    // Case 1: Selected unit has its own selling_price
    if (selectedUnit.sellingPrice != null) {
      return selectedUnit.sellingPrice! * quantity;
    }

    // Case 2: Derive from another unit with selling_price (highest conversion_factor)
    final productUnits = _productUnitsCache[product.id];
    if (productUnits != null) {
      final unitsWithPrice =
          productUnits.where((u) => u.sellingPrice != null).toList()
            ..sort((a, b) => b.conversionFactor.compareTo(a.conversionFactor));

      if (unitsWithPrice.isNotEmpty &&
          unitsWithPrice.first.conversionFactor > 0) {
        final basePrice =
            unitsWithPrice.first.sellingPrice! /
            unitsWithPrice.first.conversionFactor;
        final rawPrice = qtyInBase * basePrice;
        return rawPrice.roundToDouble();
      }
    }

    // Case 3: Fallback to product price
    if (product.price > 0) {
      final rawPrice = qtyInBase * product.price;
      return rawPrice.roundToDouble();
    }

    return product.price * quantity;
  }

  bool _compareModifiers(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    final sortedA = List<String>.from(a)..sort();
    final sortedB = List<String>.from(b)..sort();
    for (int i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  void addProduct(
    ProductEntity product, {
    double quantity = 1.0,
    ProductUnit? selectedUnit,
    double? manualUnitPrice,
    List<String>? modifiers,
    String? course,
  }) {
    final existingIndex = state.items.indexWhere(
      (i) =>
          i.product.id == product.id &&
          _compareModifiers(i.modifiers, modifiers) &&
          i.course == course &&
          i.selectedUnit?.id == selectedUnit?.id,
    );

    if (existingIndex >= 0) {
      // Increment
      final newItems = List<CartItem>.from(state.items);
      final newItem = newItems[existingIndex].copyWith(
        quantity: newItems[existingIndex].quantity + quantity,
      );
      newItems[existingIndex] = newItem;
      state = state.copyWith(items: newItems);
    } else {
      double validDiscount = product.discount;
      if (product.isPercentDiscount) {
        if (validDiscount > 100) validDiscount = 100;
      } else {
        if (validDiscount > product.price) validDiscount = product.price;
      }
      if (validDiscount < 0) validDiscount = 0;

      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            product: product,
            quantity: quantity,
            selectedUnit: selectedUnit,
            manualDiscount: validDiscount,
            isPercentDiscount: product.isPercentDiscount,
            manualUnitPrice: manualUnitPrice,
            modifiers: modifiers,
            course: course,
          ),
        ],
      );
    }
  }

  void removeProduct(
    ProductEntity product, {
    ProductUnit? selectedUnit,
    List<String>? modifiers,
    String? course,
  }) {
    state = state.copyWith(
      items: state.items
          .where(
            (i) =>
                i.product.id != product.id ||
                i.selectedUnit?.id != selectedUnit?.id ||
                !_compareModifiers(i.modifiers, modifiers) ||
                i.course != course,
          )
          .toList(),
    );
  }

  void updateQuantity(
    ProductEntity product,
    double quantity, {
    ProductUnit? selectedUnit,
    List<String>? modifiers,
    String? course,
  }) {
    if (quantity <= 0) {
      removeProduct(
        product,
        selectedUnit: selectedUnit,
        modifiers: modifiers,
        course: course,
      );
      return;
    }

    final index = state.items.indexWhere(
      (i) =>
          i.product.id == product.id &&
          _compareModifiers(i.modifiers, modifiers) &&
          i.course == course &&
          (selectedUnit != null ? i.selectedUnit?.id == selectedUnit.id : true),
    );
    if (index >= 0) {
      final newItems = List<CartItem>.from(state.items);
      newItems[index] = newItems[index].copyWith(
        quantity: quantity,
        selectedUnit: selectedUnit ?? newItems[index].selectedUnit,
      );
      state = state.copyWith(items: newItems);
    }
  }

  void updateItemUnit(
    ProductEntity product,
    ProductUnit newUnit, {
    List<String>? modifiers,
    String? course,
  }) {
    final index = state.items.indexWhere(
      (i) =>
          i.product.id == product.id &&
          _compareModifiers(i.modifiers, modifiers) &&
          i.course == course,
    );
    if (index >= 0) {
      final newItems = List<CartItem>.from(state.items);
      newItems[index] = newItems[index].copyWith(selectedUnit: newUnit);
      state = state.copyWith(items: newItems);
    }
  }

  void updateItemDiscount(
    ProductEntity product,
    double discount,
    bool isPercent, {
    ProductUnit? selectedUnit,
    List<String>? modifiers,
    String? course,
  }) {
    final index = state.items.indexWhere(
      (i) =>
          i.product.id == product.id &&
          i.selectedUnit?.id == selectedUnit?.id &&
          _compareModifiers(i.modifiers, modifiers) &&
          i.course == course,
    );
    if (index >= 0) {
      double validDiscount = discount;
      final itemSubtotal =
          state.items[index].product.price * state.items[index].quantity;

      if (isPercent) {
        if (validDiscount > 100) validDiscount = 100;
      } else {
        if (validDiscount > itemSubtotal) validDiscount = itemSubtotal;
      }

      if (validDiscount < 0) validDiscount = 0;

      final newItems = List<CartItem>.from(state.items);
      newItems[index] = newItems[index].copyWith(
        manualDiscount: validDiscount,
        isPercentDiscount: isPercent,
      );
      state = state.copyWith(items: newItems);
    }
  }

  void setOverallDiscount(double discount, bool isPercent) {
    double validDiscount = discount;
    final currentTotal = state.items.fold(0.0, (sum, item) => sum + item.total);

    if (isPercent) {
      if (validDiscount > 100) validDiscount = 100;
    } else {
      if (validDiscount > currentTotal) validDiscount = currentTotal;
    }

    if (validDiscount < 0) validDiscount = 0;

    state = state.copyWith(
      overallDiscount: validDiscount,
      isOverallPercent: isPercent,
    );
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  void setAdditionalCharge(String name, double amount) {
    final updated = Map<String, double>.from(state.additionalCharges);
    if (amount <= 0) {
      updated.remove(name);
    } else {
      updated[name] = amount;
    }
    state = state.copyWith(additionalCharges: updated);
  }

  void clearCart() {
    state = const CartState();
  }

  void setCustomer(CustomerEntity? customer) {
    state = state.copyWith(selectedCustomer: customer);
  }
}

// 3. Providers
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

// Search input providers (immediate, used to trigger debounced queries)
final productSearchProvider = StateProvider<String>((ref) => '');
final customerSearchProvider = StateProvider<String>((ref) => '');

/// POS product list with SQL-level filtering, debounced 300ms.
///
/// Uses [productSearchProvider] for the raw search input but debounces
/// before hitting SQLite so rapid keystrokes don't trigger N queries.
///
/// When [selectedCategoryProvider] changes the query runs immediately
/// (category selection is a discrete action, not continuous typing).
final posProductListProvider = StreamProvider.autoDispose<List<ProductEntity>>((ref) {
  final database = ServiceLocator.instance.database;
  final selectedCategoryId = ref.watch(selectedCategoryProvider);
  final controller = StreamController<List<ProductEntity>>();
  Timer? timer;

  void runQuery(String rawQuery) {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 300), () async {
      final results = await database.getFilteredProducts(
        query: rawQuery,
        categoryId: selectedCategoryId,
      );
      if (!controller.isClosed) controller.add(results);
    });
  }

  // Immediate initial load (no debounce for first render)
  Future.microtask(() async {
    final initial = await database.getFilteredProducts(
      categoryId: selectedCategoryId,
    );
    if (!controller.isClosed) controller.add(initial);
  });

  // Debounced search on every keystroke
  ref.listen(productSearchProvider, (_, String next) {
    runQuery(next);
  });

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// POS customer list with SQL-level filtering, debounced 300ms.
final posCustomerListProvider = StreamProvider.autoDispose<List<CustomerEntity>>((ref) {
  final database = ServiceLocator.instance.database;
  final controller = StreamController<List<CustomerEntity>>();
  Timer? timer;

  void runQuery(String rawQuery) {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 300), () async {
      final results = await database.getFilteredCustomers(query: rawQuery);
      if (!controller.isClosed) controller.add(results);
    });
  }

  Future.microtask(() async {
    final initial = await database.getFilteredCustomers();
    if (!controller.isClosed) controller.add(initial);
  });

  ref.listen(customerSearchProvider, (_, String next) {
    runQuery(next);
  });

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});
