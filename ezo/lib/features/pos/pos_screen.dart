import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/features/pos/state/pos_category_state.dart';
import 'package:aeropos/features/pos/state/barcode_state.dart';
import 'package:aeropos/features/pos/services/barcode_service.dart';
import 'package:aeropos/features/pos/providers/pos_layout_provider.dart';
import 'package:aeropos/features/pos/layouts/compact_layout.dart';
import 'package:aeropos/features/pos/layouts/restaurant_layout.dart';
import 'package:aeropos/features/pos/layouts/retail_layout.dart';
import 'package:aeropos/features/pos/layouts/touch_layout.dart';
import 'package:aeropos/features/pos/layouts/dual_screen_layout.dart';
import 'package:aeropos/features/pos/widgets/quantity_with_unit_dialog.dart';
import 'package:aeropos/features/pos/widgets/quick_add_product_dialog.dart';

import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/models/product_unit.dart';
import '../../core/models/sale.dart';
import '../../core/widgets/pos_toast.dart';
import '../../core/widgets/customer_form_dialog.dart';
import '../../core/di/service_locator.dart';
import '../../core/exceptions/sale_validation_exception.dart';
import 'package:aeropos/features/invoice/screens/invoice_preview_screen.dart';
import '../../core/widgets/master_header.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/template_repository.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/models.dart'
    as editor_models;
import 'package:aeropos/features/invoice/invoice_template_editor/invoice_completeness_checker.dart'
    as completeness;
import 'package:aeropos/core/providers/tenant_provider.dart';
import 'package:aeropos/core/theme/app_theme.dart';
import 'package:aeropos/core/utils/number_to_words.dart';

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
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.stop);
    ServiceLocator.instance.syncEngine.pull().catchError((e, st) {
      debugPrint('POS sync pull failed: $e');
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  bool _textFieldHasFocus() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    return focus.context?.widget is EditableText;
  }

  Future<void> _playBeep(bool success) async {
    final asset = success ? 'sounds/beep_success.wav' : 'sounds/beep_error.wav';
    await _player.play(AssetSource(asset));
  }

  Future<void> _onBarcodeScanned(String rawCode) async {
    if (_textFieldHasFocus()) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    final service = ref.read(barcodeServiceProvider);
    final result = await service.resolve(rawCode);
    if (!mounted) return;

    switch (result) {
      case BarcodeMatched(:final product, :final unit):
        final pu = ProductUnit(
          id: unit.id, productId: unit.productId, unitId: unit.unitId,
          conversionFactor: unit.conversionFactor,
          sellingPrice: unit.sellingPrice,
          barcode: unit.barcode, isDefault: unit.isDefault,
        );
        ref.read(cartProvider.notifier).addProduct(product, selectedUnit: pu);
        await _playBeep(true);
        if (mounted) {
          PosToast.showSuccess(context, '${product.name} added');
        }

      case BarcodePriceEmbedded(:final productLinkCode, :final embeddedPrice):
        final db = ServiceLocator.instance.database;
        final matches = await db.getProductsByBarcode(productLinkCode);
        if (matches.isNotEmpty) {
          final match = matches.first;
          ref.read(cartProvider.notifier).addProduct(
            match.product, manualUnitPrice: embeddedPrice);
          await _playBeep(true);
          if (!mounted) return;
          PosToast.showSuccess(
            context, '${match.product.name} — Rs ${embeddedPrice.toStringAsFixed(2)}');
        } else {
          await _playBeep(false);
          if (!mounted) return;
          PosToast.showError(context, 'Barcode not found: $productLinkCode');
        }

      case BarcodeWeightEmbedded(:final productLinkCode, :final weightKg):
        final db = ServiceLocator.instance.database;
        final matches = await db.getProductsByBarcode(productLinkCode);
        if (matches.isNotEmpty) {
          final match = matches.first;
          ref.read(cartProvider.notifier).addProduct(
            match.product, quantity: weightKg);
          await _playBeep(true);
          if (!mounted) return;
          PosToast.showSuccess(
            context, '${match.product.name} — ${weightKg.toStringAsFixed(3)} kg');
        } else {
          await _playBeep(false);
          if (!mounted) return;
          PosToast.showError(context, 'Barcode not found: $productLinkCode');
        }

      case BarcodeMultiVariant(:final rawCode, :final matches):
        await _playBeep(false);
        if (mounted) {
          final selectedMatch = await showDialog<({ProductEntity product, ProductUnitEntity unit})>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: Text('Select Item ($rawCode)'),
              children: matches.map((match) {
                final priceStr = 'Rs ${match.unit.sellingPrice?.toStringAsFixed(2) ?? match.product.price.toStringAsFixed(2)}';
                return SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, match),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(match.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(priceStr),
                    trailing: const Icon(Icons.add_circle_outline),
                  ),
                );
              }).toList(),
            ),
          );
          if (selectedMatch != null && mounted) {
            final pu = ProductUnit(
              id: selectedMatch.unit.id, productId: selectedMatch.unit.productId,
              unitId: selectedMatch.unit.unitId,
              conversionFactor: selectedMatch.unit.conversionFactor,
              sellingPrice: selectedMatch.unit.sellingPrice,
              barcode: selectedMatch.unit.barcode, isDefault: selectedMatch.unit.isDefault,
            );
            ref.read(cartProvider.notifier).addProduct(selectedMatch.product, selectedUnit: pu);
          }
        }

      case BarcodeNotFound(:final rawCode):
        await _playBeep(false);

        if (!mounted) return;
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => QuickAddProductDialog(barcode: rawCode),
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

          final stock = (result['stock'] as int? ?? 0);

          final newItems = await db.insertQuickProduct(
            barcode: rawCode,
            name: result['name'] as String,
            sellingPrice: result['price'] as double,
            defaultUnitId: pieceUnit.id,
            initialStock: stock,
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

          if (stock > 0) {
            final syncRepo = ServiceLocator.instance.syncRepository;
            await syncRepo.logStockDelta(
              productId: newItems.product.id.toString(),
              delta: stock.toDouble(),
              reason: 'initial_stock',
            );
          }

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
              SnackBar(
                content: Text('${result['name']} added to inventory!'),
              ),
            );
          }
        }
    }
  }

  Future<void> _handleCheckout({
    bool shouldSave = true,
    String? paymentMethod,
  }) async {
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) return;

    final companyId = ref.read(companyIdProvider);
    final invoiceNumber = await ServiceLocator.instance.invoiceSequenceService.getNextInvoiceNumber(companyId);

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
          await repo.getHydratedInvoiceData(companyId, null);

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
              details: '',
              qty: item.quantity.toDouble(),
              rate: item.unitPrice,
              hsnCode: item.product.hsn ?? '',
              cgstRate: _halfGst(item.product.gstRate),
              sgstRate: _halfGst(item.product.gstRate),
              discount: item.discount,
            ),
          )
          .toList();

      if (!mounted) return;

      // Clear cart immediately so cashier can start next order
      if (shouldSave) {
        ref.read(cartProvider.notifier).clearCart();
        PosToast.showSuccess(context, "Checkout completed");
      }

      // Check for missing invoice fields and warn before showing preview.
      final gaps = completeness.checkInvoiceCompleteness(invoiceData);
      if (gaps.isNotEmpty && mounted) {
        final proceed = await _showInvoiceCompletenessWarning(gaps, companyId, templateId);
        if (!proceed || !mounted) return;
      }

      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => InvoicePreviewScreen(
          prebuiltData: invoiceData,
          prebuiltTemplateId: templateId,
          customer: cartState.selectedCustomer,
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

  /// Shows a bottom sheet listing missing invoice fields.
  /// Returns true if the user chooses to continue, false if they cancel.
  Future<bool> _showInvoiceCompletenessWarning(
    List<completeness.InvoiceFieldGap> gaps,
    int companyId,
    String templateId,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InvoiceCompletenessSheet(
        gaps: gaps,
        companyId: companyId,
        templateId: templateId,
      ),
    );
    return result ?? false;
  }

  /// Parses a product's gstRate string (e.g. "18%") into a numeric rate.
  /// Returns half that rate for CGST/SGST split (intra-state default).
  static double _halfGst(String? gstRateStr) {
    if (gstRateStr == null) return 0.0;
    final rate = double.tryParse(gstRateStr.replaceAll('%', '').trim()) ?? 0.0;
    return rate / 2;
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
              final customer = await ServiceLocator.instance.customerViewModel
                  .addCustomer(
                    name: name,
                    phone: phone,
                    email: email,
                    gstin: gstin,
                    address: address,
                    creditLimit: creditLimit,
                  );
              if (!context.mounted) return;
              ref.read(cartProvider.notifier).setCustomer(customer);
              PosToast.showSuccess(context, "Customer created and selected");
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
          final isCompact = MediaQuery.sizeOf(context).width < 600;
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
            insetPadding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 40,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isCompact ? 360 : 420,
                maxHeight: isCompact ? 520 : 580,
              ),
              width: double.infinity,
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
                    padding: EdgeInsets.fromLTRB(isCompact ? 16 : 24, 20, isCompact ? 12 : 20, 16),
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
                      padding: EdgeInsets.fromLTRB(isCompact ? 16 : 24, 20, isCompact ? 16 : 24, 8),
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
                    padding: EdgeInsets.fromLTRB(isCompact ? 16 : 24, 12, isCompact ? 16 : 24, 20),
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

    onSearch(q) => ref.read(productSearchProvider.notifier).state = q;
    void onBack() => context.go('/dashboard');

    // CompactLayout manages its own full-screen header; skip the AppBar to
    // avoid a double toolbar and the leading-Row overflow on narrow screens.
    return Scaffold(
      appBar: layoutType == PosLayoutType.compact
          ? null
          : MasterHeader(
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
      body: BarcodeKeyboardListener(
        bufferDuration: const Duration(milliseconds: 80),
        onBarcodeScanned: _onBarcodeScanned,
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
    VoidCallback onBack,
  ) {
    Future<void> onBarcodeScanned(String code) => _onBarcodeScanned(code);
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
        if (!mounted) return;
        showDialog(
          context: context,
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

    onCategoryTap(id) => ref.read(selectedCategoryProvider.notifier).state = id;

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

      final companyId = ref.read(companyIdProvider);
      final invoiceNumber = await ServiceLocator.instance.invoiceSequenceService.getNextInvoiceNumber(companyId);

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
          await repo.getHydratedInvoiceData(companyId, null);

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
              hsnCode: item.product.hsn ?? '',
              cgstRate: _halfGst(item.product.gstRate),
              sgstRate: _halfGst(item.product.gstRate),
              discount: item.discount,
            ),
          )
          .toList();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => InvoicePreviewScreen(
          prebuiltData: invoiceData,
          prebuiltTemplateId: templateId,
          customer: cartState.selectedCustomer,
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
        builder: (ctx) {
          final isCompact = MediaQuery.sizeOf(ctx).width < 600;
          return AlertDialog(
            title: const Text('Recall Order'),
            content: SizedBox(
              width: isCompact ? 320 : 400,
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
          );
        },
      );
    }

    switch (type) {
      case PosLayoutType.compact:
        return CompactLayout(
          key: const ValueKey('layout_compact'),
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
          onBarcodeScanned: onBarcodeScanned,
        );
      case PosLayoutType.restaurant:
        return RestaurantLayout(
          key: const ValueKey('layout_restaurant'),
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
          onBarcodeScanned: onBarcodeScanned,
        );
      case PosLayoutType.retail:
        return RetailLayout(
          key: const ValueKey('retail'),
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
          onBarcodeScanned: onBarcodeScanned,
        );
      case PosLayoutType.touch:
        return TouchLayout(
          key: const ValueKey('touch'),
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
          key: const ValueKey('dual'),
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

// ─────────────────────────────────────────────────────────────────────────────
// Invoice completeness warning sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceCompletenessSheet extends ConsumerStatefulWidget {
  final List<completeness.InvoiceFieldGap> gaps;
  final int companyId;
  final String templateId;

  const _InvoiceCompletenessSheet({
    required this.gaps,
    required this.companyId,
    required this.templateId,
  });

  @override
  ConsumerState<_InvoiceCompletenessSheet> createState() =>
      _InvoiceCompletenessSheetState();
}

class _InvoiceCompletenessSheetState
    extends ConsumerState<_InvoiceCompletenessSheet> {
  bool _saving = false;

  Future<void> _disableField(String toggleKey) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(invoiceTemplateRepositoryProvider);
      await repo.saveTemplateSelection(
        companyId: widget.companyId,
        templateId: widget.templateId,
        showTaxBreakdown: toggleKey == 'showTaxBreakdown' ? false : null,
        showAddress: toggleKey == 'showAddress' ? false : null,
        showFooter: toggleKey == 'showFooter' ? false : null,
        showBankDetails: toggleKey == 'showBankDetails' ? false : null,
        showUpiQr: toggleKey == 'showUpiQr' ? false : null,
        showCustomerDetails: toggleKey == 'showCustomerDetails' ? false : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _navigateToEdit(String editRoute) {
    Navigator.of(context).pop(false);
    context.go('/company-profile');
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<completeness.InvoiceFieldGap>>{};
    for (final gap in widget.gaps) {
      grouped.putIfAbsent(gap.category, () => []).add(gap);
    }

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Invoice Incomplete',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'The following fields are missing. Fill them in or disable '
                'the section, then retry.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final category in grouped.keys) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Text(
                        completeness.gapCategoryLabel(category),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    for (final gap in grouped[category]!)
                      _GapRow(
                        gap: gap,
                        saving: _saving,
                        onEdit: () => _navigateToEdit(gap.editRoute),
                        onDisable: gap.disableToggle != null
                            ? () => _disableField(gap.disableToggle!)
                            : null,
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Continue Anyway'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  final completeness.InvoiceFieldGap gap;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback? onDisable;

  const _GapRow({
    required this.gap,
    required this.saving,
    required this.onEdit,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.radio_button_unchecked,
        size: 18,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(gap.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: saving ? null : onEdit,
            child: const Text('Fill in'),
          ),
          if (onDisable != null) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: saving ? null : onDisable,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
              child: const Text('Disable'),
            ),
          ],
        ],
      ),
    );
  }
}
