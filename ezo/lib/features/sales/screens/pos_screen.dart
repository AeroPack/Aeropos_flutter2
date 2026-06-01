import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/exceptions/sale_validation_exception.dart';
import 'package:aeropos/core/models/sale.dart';
import 'package:aeropos/core/widgets/customer_form_dialog.dart';
import 'package:aeropos/core/widgets/master_header.dart';
import 'package:aeropos/core/widgets/pos_toast.dart';
import 'package:aeropos/features/sales/screens/invoice_preview_screen.dart';
import 'package:aeropos/features/pos/widgets/quantity_with_unit_dialog.dart';
import 'package:aeropos/core/models/product_unit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/features/pos/state/pos_category_state.dart';
import 'package:aeropos/features/pos/providers/pos_layout_provider.dart';
import 'package:aeropos/features/pos/layouts/compact_layout.dart';
import 'package:aeropos/features/pos/layouts/restaurant_layout.dart';
import 'package:aeropos/features/pos/layouts/retail_layout.dart';
import 'package:aeropos/features/pos/layouts/touch_layout.dart';
import 'package:aeropos/features/pos/layouts/dual_screen_layout.dart';

import 'package:aeropos/core/database/app_database.dart';
// import '../../core/models/sale.dart';
// import '../../core/widgets/pos_toast.dart';
// import '../../core/widgets/customer_form_dialog.dart';
// import '../../core/di/service_locator.dart';
// import '../../core/exceptions/sale_validation_exception.dart';
// import '../sales/screens/invoice_preview_screen.dart';
// import '../../core/widgets/master_header.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/template_repository.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/models.dart'
    as editor_models;
import 'package:aeropos/core/providers/tenant_provider.dart';
import 'package:aeropos/core/theme/app_theme.dart';
import 'package:aeropos/core/utils/number_to_words.dart';
import 'package:aeropos/core/services/pdf_generator_isolate.dart';

class HeldOrder {
  final String id;
  final List<CartItem> items;
  final CustomerEntity? customer;
  final double total;
  final DateTime createdAt;

  HeldOrder({
    required this.id,
    required this.items,
    this.customer,
    required this.total,
    required this.createdAt,
  });
}

class HeldOrdersNotifier extends StateNotifier<List<HeldOrder>> {
  HeldOrdersNotifier() : super([]);

  void addOrder({
    required String id,
    required List<CartItem> items,
    CustomerEntity? customer,
    required double total,
    required DateTime createdAt,
  }) {
    state = [
      ...state,
      HeldOrder(
        id: id,
        items: items
            .map((i) => CartItem(product: i.product, quantity: i.quantity))
            .toList(),
        customer: customer,
        total: total,
        createdAt: createdAt,
      ),
    ];
  }

  void removeOrder(String id) {
    state = state.where((o) => o.id != id).toList();
  }

  void clear() {
    state = [];
  }
}

final heldOrdersProvider =
    StateNotifierProvider<HeldOrdersNotifier, List<HeldOrder>>((ref) {
      return HeldOrdersNotifier();
    });

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    ServiceLocator.instance.syncEngine.pull().catchError((e, st) {
      debugPrint('POS sync pull failed: $e');
    });
  }

  Future<void> _handleCheckout({
    bool shouldSave = true,
    String? paymentMethod,
  }) async {
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) return;

    final tenantId = ref.read(tenantIdProvider);
    final invoiceNumber = await ServiceLocator.instance.invoiceSequenceService.getNextInvoiceNumber(tenantId);

    final sale = Sale(
      uuid: _uuid.v4(),
      invoiceNumber: invoiceNumber,
      customerId: cartState.selectedCustomer?.id,
      items: cartState.items
          .map(
            (cartItem) => SaleItem(
              uuid: _uuid.v4(),
              productId: cartItem.product.id,
              product: cartItem.product,
              quantity: cartItem.quantity.toInt(),
              unitPrice: cartItem.product.price,
              discount: cartItem.manualDiscount,
              total: cartItem.total,
            ),
          )
          .toList(),
      total: cartState.total,
      subtotal: cartState.subtotal,
      tax: cartState.taxAmount,
      discount: cartState.totalDiscount,
      paymentMethod: paymentMethod,
      createdAt: DateTime.now(),
    );

    try {
      if (shouldSave) {
        await ServiceLocator.instance.saleRepository.createSale(sale);
      }

      final repo = ref.read(invoiceTemplateRepositoryProvider);

      // Fetch hydrated template with company details and stored customizations
      final (data: invoiceData, templateId: templateId) =
          await repo.getHydratedInvoiceData(tenantId, null);

      // Update with sale specific data
      if (cartState.selectedCustomer != null) {
        invoiceData.clientName = cartState.selectedCustomer!.name;
        invoiceData.clientAddress = cartState.selectedCustomer!.address ?? '';
        invoiceData.clientPhone = cartState.selectedCustomer!.phone ?? '';
        invoiceData.clientEmail = cartState.selectedCustomer!.email ?? '';
        invoiceData.clientGstin = cartState.selectedCustomer!.gstin ?? '';
        invoiceData.showClientContact = true;
      } else {
        invoiceData.clientName = 'Walk-in Customer';
        invoiceData.clientAddress = '';
        invoiceData.clientPhone = '';
        invoiceData.clientEmail = '';
        invoiceData.clientGstin = '';
        invoiceData.showClientContact = false;
      }

      invoiceData.invoiceNumber = sale.invoiceNumber;
      invoiceData.invoiceDate = sale.createdAt;
      invoiceData.notes = cartState.notes;
      invoiceData.amountInWords = convertToIndianRupees(sale.total);
      invoiceData.paymentMethod = paymentMethod;

      invoiceData.items = sale.items
          .map(
            (item) => editor_models.InvoiceItem(
              id: item.uuid,
              desc: item.product.name,
              details: '', // SaleItem doesn't have detailed description usually
              qty: item.quantity.toDouble(),
              rate: item.unitPrice,
            ),
          )
          .toList();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => InvoicePreviewScreen(
          invoiceNumber: sale.invoiceNumber,
          onLayout: (format) async {
            return generatePdfInIsolate(invoiceData, templateId);
          },
          onPrintComplete: () {
            if (shouldSave) {
              ref.read(cartProvider.notifier).clearCart();
              PosToast.showSuccess(context, "Checkout completed");
            }
            if (mounted) Navigator.pop(context);
          },
        ),
      );
    } on SaleValidationException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Products'),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                PosToast.showInfo(context, 'Syncing products...');
                await ServiceLocator.instance.syncEngine.push();
              },
              child: const Text('Sync Products'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) PosToast.showError(context, "Failed to process sale: $e");
    }
  }

  void _openInvoiceSettings() {
    try {
      context.go('/settings');
    } catch (e) {
      // Fallback navigation
      Navigator.pushNamed(context, '/settings');
    }
  }

  void _openSalesHistory() => context.go('/sales-history');

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(
        onSubmit:
            ({
              required name,
              phone,
              email,
              gstin,
              address,
              required creditLimit,
            }) async {
              final dialogContext = context;
              final customer = await ServiceLocator.instance.customerViewModel
                  .addCustomer(
                    name: name,
                    phone: phone,
                    email: email,
                    gstin: gstin,
                    address: address,
                    creditLimit: creditLimit,
                  );
        if (!dialogContext.mounted) return;
              ref.read(cartProvider.notifier).setCustomer(customer);
              PosToast.showSuccess(dialogContext, "Customer created and selected");
            },
      ),
    );
  }

  void _showItemDiscountDialog(CartItem item) {
    bool isPercent = item.isPercentDiscount;
    final controller = TextEditingController(
      text: item.manualDiscount > 0 ? item.manualDiscount.toString() : '',
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final discountValue = double.tryParse(controller.text) ?? 0;
          final itemSubtotal = item.product.price * item.quantity;
          double previewDiscount = 0;
          if (isPercent) {
            previewDiscount = itemSubtotal * (discountValue / 100);
          } else {
            previewDiscount = discountValue;
          }
          final discountedPrice = itemSubtotal - previewDiscount;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: 420,
              constraints: const BoxConstraints(maxHeight: 580),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.local_offer_rounded,
                            color: AppColors.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Item Discount',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.grey500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.grey400,
                            size: 22,
                          ),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item info
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.grey50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.grey100),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Qty: ${item.quantity} × Rs ${item.product.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.grey600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Rs ${itemSubtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.manualDiscount > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Current Discount',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                      Text(
                                        item.isPercentDiscount
                                            ? '${item.manualDiscount.toStringAsFixed(0)}%'
                                            : 'Rs ${item.manualDiscount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Discount type toggle
                          Text(
                            'Discount Type',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.grey50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.grey200),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _itemDiscountTypeBtn(
                                    'Percentage',
                                    Icons.percent_rounded,
                                    isPercent,
                                    () => setDialogState(() {
                                      isPercent = true;
                                      controller.clear();
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _itemDiscountTypeBtn(
                                    'Fixed Amount',
                                    Icons.currency_rupee_rounded,
                                    !isPercent,
                                    () => setDialogState(() {
                                      isPercent = false;
                                      controller.clear();
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Quick presets
                          if (isPercent) ...[
                            Text(
                              'Quick Select',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [5, 10, 15, 20, 25, 50].map((p) {
                                final selected = discountValue == p.toDouble();
                                return InkWell(
                                  onTap: () {
                                    controller.text = p.toString();
                                    setDialogState(() {});
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.accent
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.accent
                                            : AppColors.grey200,
                                        width: selected ? 0 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$p%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.grey700,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Custom input
                          Text(
                            isPercent ? 'Custom Percentage' : 'Custom Amount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.grey200),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.grey50,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(12),
                                    ),
                                    border: Border(
                                      right: BorderSide(
                                        color: AppColors.grey200,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    isPercent ? '%' : 'Rs',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.grey600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (_) => setDialogState(() {}),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                        color: AppColors.grey300,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),
                                    autofocus: !isPercent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Preview
                          if (discountValue > 0)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Discount Amount',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '- Rs ${previewDiscount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Item Total',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      Text(
                                        'Rs ${discountedPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.grey100)),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Remove discount
                        if (item.manualDiscount > 0)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ref
                                    .read(cartProvider.notifier)
                                    .updateItemDiscount(
                                      item.product,
                                      0,
                                      false,
                                      selectedUnit: item.selectedUnit,
                                      modifiers: item.modifiers,
                                      course: item.course,
                                    );
                                Navigator.pop(context);
                              },
                              icon: Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                                color: Colors.red[400],
                              ),
                              label: Text(
                                'Remove',
                                style: TextStyle(
                                  color: Colors.red[400],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        if (item.manualDiscount > 0) const SizedBox(width: 12),

                        // Cancel
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: AppColors.grey200),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.grey600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Apply
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final d = double.tryParse(controller.text) ?? 0.0;
                              ref
                                  .read(cartProvider.notifier)
                                  .updateItemDiscount(
                                    item.product,
                                    d,
                                    isPercent,
                                    selectedUnit: item.selectedUnit,
                                    modifiers: item.modifiers,
                                    course: item.course,
                                  );
                              Navigator.pop(context);
                            },
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 20,
                            ),
                            label: const Text(
                              'Apply Discount',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _itemDiscountTypeBtn(
    String label,
    IconData iconData,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 18,
              color: selected ? Colors.white : AppColors.grey500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Force a rebuild when layout changes by using the layout type in the key
    final layoutType = ref.watch(posLayoutProvider);
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final products = ref.watch(posProductListProvider);
    final categories = ref.watch(categoryStreamProvider);
    final selectedCategoryId = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(productSearchProvider);

    final String layoutTitle = switch (layoutType) {
      PosLayoutType.compact => "Compact POS",
      PosLayoutType.restaurant => "Dine POS",
      PosLayoutType.retail => "Retail POS",
      PosLayoutType.touch => "Touch POS",
      PosLayoutType.dualScreen => "Dual Screen POS",
    };

    void onSearch(q) => ref.read(productSearchProvider.notifier).state = q;
    void onBack() => context.go('/dashboard');

    return Scaffold(
      appBar: MasterHeader(
        showSidebarToggle: false,
        hidePosButton: true,
        title: Text(
          layoutTitle,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        searchQuery: searchQuery,
        onSearch: onSearch,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
              onPressed: onBack,
              tooltip: 'Back to Dashboard',
            ),
            InkWell(
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Icon(Icons.storefront, color: Color(0xFF0F172A), size: 28),
                    SizedBox(width: 8),
                    Text(
                      "Aero",
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "POS",
                      style: TextStyle(
                        color: Color.fromARGB(255, 0, 191, 255),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        // CRITICAL FIX: Add a unique key that changes when layout type changes
        child: _buildSelectedLayout(
          layoutType,
          cartState,
          cartNotifier,
          products,
          categories,
          selectedCategoryId,
          searchQuery,
          onSearch,
          onBack,
          key: ValueKey(
            'layout_${layoutType.name}_${DateTime.now().millisecondsSinceEpoch}',
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedLayout(
    PosLayoutType type,
    CartState cartState,
    CartNotifier cartNotifier,
    AsyncValue<List<ProductEntity>> products,
    AsyncValue<List<CategoryEntity>> categories,
    int? selectedCategoryId,
    String searchQuery,
    void Function(String) onSearch,
    VoidCallback onBack, {
    Key? key,
  }) {
    Future<void> onProductTap(ProductEntity product) async {
      final db = ServiceLocator.instance.database;

      final dao = db.productUnitDao;
      final productUnits = await dao.getUnitsForProduct(product.id);

      cartNotifier.setProductUnitsCache(product.id, productUnits);

      ProductUnit? selectedUnit;

      if (productUnits.isNotEmpty) {
        final defaultUnit = productUnits.firstWhere(
          (u) => u.isDefault,
          orElse: () => productUnits.first,
        );

        final unit = await (db.select(
          db.units,
        )..where((t) => t.id.equals(defaultUnit.unitId))).getSingleOrNull();

        selectedUnit = ProductUnit(
          id: defaultUnit.id,
          productId: defaultUnit.productId,
          unitId: defaultUnit.unitId,
          conversionFactor: defaultUnit.conversionFactor,
          sellingPrice: defaultUnit.sellingPrice,
          barcode: defaultUnit.barcode,
          isDefault: defaultUnit.isDefault,
          unitName: unit?.name,
          unitSymbol: unit?.symbol,
        );
      }

      // If multiple units, show dialog first; if single unit, add directly
      if (productUnits.length > 1) {
        // Show QuantityWithUnitDialog for multi-unit products
        final buildContext = context;
        if (!buildContext.mounted) return;
        showDialog(
          context: buildContext,
          barrierDismissible: true,
          builder: (dialogCtx) => QuantityWithUnitDialog(
            product: product,
            currentUnit: null,
            currentQuantity: 1.0,
            productUnits: productUnits,
            onSave: (qty, unit) {
              cartNotifier.addProduct(
                product,
                quantity: qty,
                selectedUnit: unit,
              );
            },
          ),
        );
      } else {
        // Single unit - add directly to cart
        cartNotifier.addProduct(product, selectedUnit: selectedUnit);
      }
    }

    void onCategoryTap(id) =>
        ref.read(selectedCategoryProvider.notifier).state = id;

    Future<void> onCheckout({
      required bool shouldSave,
      String? paymentMethod,
    }) => _handleCheckout(shouldSave: shouldSave, paymentMethod: paymentMethod);

    void onSetOverallDiscount(d, p) => cartNotifier.setOverallDiscount(d, p);
    void onReset() => cartNotifier.clearCart();

    Future<void> onSplitBill() async {
      if (cartState.items.isEmpty) {
        PosToast.showInfo(context, 'Cart is empty');
        return;
      }

      final int? splitCount = await showDialog<int>(
        context: context,
        builder: (ctx) => _SplitBillDialog(total: cartState.total),
      );

      if (splitCount == null || splitCount <= 1) return;
      if (!mounted) return;

      final double splitAmount = cartState.total / splitCount;

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Split Bill'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bill split into $splitCount parts'),
              const SizedBox(height: 8),
              Text(
                'Each part: Rs${splitAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select payment method for each split:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _handleCheckout(shouldSave: true, paymentMethod: 'Split');
                PosToast.showSuccess(
                  context,
                  'Bill split into $splitCount payments',
                );
              },
              child: const Text('Process Split'),
            ),
          ],
        ),
      );
    }

    Future<void> onPrintReceipt() async {
      if (cartState.items.isEmpty) {
        PosToast.showInfo(context, 'Cart is empty');
        return;
      }

      final tenantId = ref.read(tenantIdProvider);
      final invoiceNumber = await ServiceLocator.instance.invoiceSequenceService.getNextInvoiceNumber(tenantId);

      final sale = Sale(
        uuid: _uuid.v4(),
        invoiceNumber: invoiceNumber,
        customerId: cartState.selectedCustomer?.id,
        items: cartState.items
            .map(
              (cartItem) => SaleItem(
                uuid: _uuid.v4(),
                productId: cartItem.product.id,
                product: cartItem.product,
                quantity: cartItem.quantity.toInt(),
                unitPrice: cartItem.product.price,
                discount: cartItem.manualDiscount,
                total: cartItem.total,
              ),
            )
            .toList(),
        total: cartState.total,
        subtotal: cartState.subtotal,
        tax: cartState.taxAmount,
        discount: cartState.totalDiscount,
        paymentMethod: 'Print Only',
        createdAt: DateTime.now(),
      );

      final repo = ref.read(invoiceTemplateRepositoryProvider);
      final (data: invoiceData, templateId: templateId) =
          await repo.getHydratedInvoiceData(tenantId, null);

      if (cartState.selectedCustomer != null) {
        invoiceData.clientName = cartState.selectedCustomer!.name;
        invoiceData.clientAddress = cartState.selectedCustomer!.address ?? '';
        invoiceData.clientPhone = cartState.selectedCustomer!.phone ?? '';
        invoiceData.clientEmail = cartState.selectedCustomer!.email ?? '';
        invoiceData.clientGstin = cartState.selectedCustomer!.gstin ?? '';
        invoiceData.showClientContact = true;
      } else {
        invoiceData.clientName = 'Walk-in Customer';
        invoiceData.clientAddress = '';
        invoiceData.clientPhone = '';
        invoiceData.clientEmail = '';
        invoiceData.clientGstin = '';
        invoiceData.showClientContact = false;
      }

      invoiceData.invoiceNumber = sale.invoiceNumber;
      invoiceData.invoiceDate = sale.createdAt;
      invoiceData.notes = cartState.notes;
      invoiceData.amountInWords = convertToIndianRupees(sale.total);
      invoiceData.paymentMethod = 'Print Only';
      invoiceData.items = sale.items
          .map(
            (item) => editor_models.InvoiceItem(
              id: item.uuid,
              desc: item.product.name,
              details: '',
              qty: item.quantity.toDouble(),
              rate: item.unitPrice,
            ),
          )
          .toList();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => InvoicePreviewScreen(
          invoiceNumber: sale.invoiceNumber,
          onLayout: (format) async {
            return generatePdfInIsolate(invoiceData, templateId);
          },
          onPrintComplete: () {
            if (mounted) Navigator.pop(context);
            PosToast.showSuccess(context, 'Receipt printed successfully');
          },
        ),
      );
    }

    void onOrderHold() {
      if (cartState.items.isEmpty) {
        PosToast.showInfo(context, 'Cart is empty');
        return;
      }

      final heldOrders = ref.read(heldOrdersProvider.notifier);
      final orderId = 'HOLD-${DateTime.now().millisecondsSinceEpoch}';

      heldOrders.addOrder(
        id: orderId,
        items: cartState.items,
        customer: cartState.selectedCustomer,
        total: cartState.total,
        createdAt: DateTime.now(),
      );

      cartNotifier.clearCart();
      PosToast.showSuccess(context, 'Order placed on hold ($orderId)');
    }

    void onRecallOrder() {
      final heldOrders = ref.read(heldOrdersProvider);

      if (heldOrders.isEmpty) {
        PosToast.showInfo(context, 'No held orders');
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Recall Order'),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: heldOrders.length,
              itemBuilder: (context, index) {
                final order = heldOrders[index];
                return ListTile(
                  leading: const Icon(Icons.receipt),
                  title: Text('Order #${order.id}'),
                  subtitle: Text(
                    '${order.items.length} items - Rs${order.total.toStringAsFixed(2)}',
                  ),
                  trailing: Text(
                    _formatDateTime(order.createdAt),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    for (final item in order.items) {
                      cartNotifier.addProduct(
                        item.product,
                        quantity: item.quantity,
                        modifiers: item.modifiers,
                        course: item.course,
                      );
                    }
                    Navigator.pop(ctx);
                    PosToast.showSuccess(
                      context,
                      'Order #${order.id} recalled',
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    // CRITICAL FIX: Pass the key to each layout widget
    switch (type) {
      case PosLayoutType.compact:
        return CompactLayout(
          key: key ?? const ValueKey('compact'),
          cartState: cartState,
          cartNotifier: cartNotifier,
          products: products,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          searchQuery: searchQuery,
          onProductTap: onProductTap,
          onCategoryTap: onCategoryTap,
          onSearch: onSearch,
          onCheckout: onCheckout,
          onOpenInvoiceSettings: _openInvoiceSettings,
          onOpenSalesHistory: _openSalesHistory,
          onShowAddCustomerDialog: _showAddCustomerDialog,
          onShowItemDiscount: _showItemDiscountDialog,
          onSetOverallDiscount: onSetOverallDiscount,
          onReset: onReset,
          onBack: onBack,
        );
      case PosLayoutType.restaurant:
        return RestaurantLayout(
          key: key ?? const ValueKey('restaurant'),
          cartState: cartState,
          cartNotifier: cartNotifier,
          products: products,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          searchQuery: searchQuery,
          onProductTap: onProductTap,
          onCategoryTap: onCategoryTap,
          onSearch: onSearch,
          onCheckout: onCheckout,
          onOpenInvoiceSettings: _openInvoiceSettings,
          onOpenSalesHistory: _openSalesHistory,
          onShowAddCustomerDialog: _showAddCustomerDialog,
          onShowItemDiscount: _showItemDiscountDialog,
          onSetOverallDiscount: onSetOverallDiscount,
          onReset: onReset,
          onBack: onBack,
          onSplitBill: onSplitBill,
          onPrintReceipt: onPrintReceipt,
          onOrderHold: onOrderHold,
          onRecallOrder: onRecallOrder,
        );
      case PosLayoutType.retail:
        return RetailLayout(
          key: key ?? const ValueKey('retail'),
          cartState: cartState,
          cartNotifier: cartNotifier,
          products: products,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          searchQuery: searchQuery,
          onProductTap: onProductTap,
          onCategoryTap: onCategoryTap,
          onSearch: onSearch,
          onCheckout: onCheckout,
          onOpenInvoiceSettings: _openInvoiceSettings,
          onOpenSalesHistory: _openSalesHistory,
          onShowAddCustomerDialog: _showAddCustomerDialog,
          onShowItemDiscount: _showItemDiscountDialog,
          onSetOverallDiscount: onSetOverallDiscount,
          onReset: onReset,
          onBack: onBack,
        );
      case PosLayoutType.touch:
        return TouchLayout(
          key: key ?? const ValueKey('touch'),
          cartState: cartState,
          cartNotifier: cartNotifier,
          products: products,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          searchQuery: searchQuery,
          onProductTap: onProductTap,
          onCategoryTap: onCategoryTap,
          onSearch: onSearch,
          onCheckout: onCheckout,
          onOpenInvoiceSettings: _openInvoiceSettings,
          onOpenSalesHistory: _openSalesHistory,
          onShowAddCustomerDialog: _showAddCustomerDialog,
          onShowItemDiscount: _showItemDiscountDialog,
          onSetOverallDiscount: onSetOverallDiscount,
          onReset: onReset,
          onBack: onBack,
          onSplitBill: onSplitBill,
          onPrintReceipt: onPrintReceipt,
          onOrderHold: onOrderHold,
          onRecallOrder: onRecallOrder,
        );
      case PosLayoutType.dualScreen:
        return DualScreenLayout(
          key: key ?? const ValueKey('dual'),
          cartState: cartState,
          cartNotifier: cartNotifier,
          products: products,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          searchQuery: searchQuery,
          onProductTap: onProductTap,
          onCategoryTap: onCategoryTap,
          onSearch: onSearch,
          onCheckout: onCheckout,
          onOpenInvoiceSettings: _openInvoiceSettings,
          onOpenSalesHistory: _openSalesHistory,
          onShowAddCustomerDialog: _showAddCustomerDialog,
          onShowItemDiscount: _showItemDiscountDialog,
          onSetOverallDiscount: onSetOverallDiscount,
          onReset: onReset,
          onBack: onBack,
        );
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SplitBillDialog extends StatefulWidget {
  final double total;

  const _SplitBillDialog({required this.total});

  @override
  State<_SplitBillDialog> createState() => _SplitBillDialogState();
}

class _SplitBillDialogState extends State<_SplitBillDialog> {
  int _splitCount = 2;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Split Bill'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How many ways would you like to split?'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _splitCount > 2
                    ? () => setState(() => _splitCount--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 32,
              ),
              const SizedBox(width: 16),
              Text(
                '$_splitCount',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _splitCount < 10
                    ? () => setState(() => _splitCount++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 32,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Each part: Rs${(widget.total / _splitCount).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _splitCount),
          child: const Text('Split'),
        ),
      ],
    );
  }
}
