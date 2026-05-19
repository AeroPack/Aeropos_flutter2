import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';

/// Base class for all POS layout widgets.
abstract class BasePosLayout extends ConsumerStatefulWidget {
  final CartState cartState;
  final CartNotifier cartNotifier;
  final AsyncValue<List<ProductEntity>> products;
  final AsyncValue<List<CategoryEntity>> categories;
  final int? selectedCategoryId;
  final String searchQuery;
  final void Function({required bool shouldSave, String? paymentMethod})
  onCheckout;

  // Callbacks — keeps business logic in PosScreen
  final void Function(ProductEntity product) onProductTap;
  final void Function(int? categoryId) onCategoryTap;
  final void Function(String query) onSearch;
  final VoidCallback onOpenInvoiceSettings;
  final VoidCallback onOpenSalesHistory;
  final VoidCallback onShowAddCustomerDialog;
  final void Function(CartItem item) onShowItemDiscount;
  final void Function(double discount, bool isPercent) onSetOverallDiscount;
  final VoidCallback onReset;
  final VoidCallback onBack;

  const BasePosLayout({
    super.key,
    required this.cartState,
    required this.cartNotifier,
    required this.products,
    required this.categories,
    required this.selectedCategoryId,
    required this.searchQuery,
    required this.onProductTap,
    required this.onCategoryTap,
    required this.onSearch,
    required this.onCheckout,
    required this.onOpenInvoiceSettings,
    required this.onOpenSalesHistory,
    required this.onShowAddCustomerDialog,
    required this.onShowItemDiscount,
    required this.onSetOverallDiscount,
    required this.onReset,
    required this.onBack,
  });
}

/// Optional base state — layouts can extend this for convenience.
abstract class BasePosLayoutState<T extends BasePosLayout>
    extends ConsumerState<T> {}
