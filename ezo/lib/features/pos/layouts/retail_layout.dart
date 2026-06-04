import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aeropos/features/pos/layouts/base_pos_layout.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/features/pos/widgets/product_search_bar.dart';
import 'package:aeropos/features/pos/widgets/cart_table_widget.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/models/product_unit.dart';

class RetailLayout extends BasePosLayout {
  const RetailLayout({
    super.key,
    required super.cartState,
    required super.cartNotifier,
    required super.products,
    required super.categories,
    required super.selectedCategoryId,
    required super.searchQuery,
    required super.onProductTap,
    required super.onCategoryTap,
    required super.onSearch,
    required super.onCheckout,
    required super.onOpenInvoiceSettings,
    required super.onOpenSalesHistory,
    required super.onShowAddCustomerDialog,
    required super.onShowItemDiscount,
    required super.onSetOverallDiscount,
    required super.onReset,
    required super.onBack,
    this.onBarcodeScanned,
  });

  final Future<void> Function(String)? onBarcodeScanned;

  @override
  ConsumerState<RetailLayout> createState() => _RetailLayoutState();
}

class _RetailLayoutState extends BasePosLayoutState<RetailLayout> {
  final Color surfaceColor = const Color(0xFFFAF8FF);
  final Color outlineColor = const Color(0xFFC3C5D9);
  final Color onSurface = const Color(0xFF191B25);
  final Color sidebarHeaderColor = const Color(0xFFEDEDFA);

  List<String> _chargeTypes = [];
  final Map<String, TextEditingController> _chargeControllers = {};
  final Map<String, TextEditingController> _chargeNameControllers = {};
  final Set<String> _savedCharges = {};
  late final TextEditingController _customerSearchController;
  late final String _invoiceRef;

  StateController<String>? _searchNotifier;

  @override
  void initState() {
    super.initState();
    _invoiceRef = 'CART-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
    _customerSearchController = TextEditingController();
    _searchNotifier = ref.read(productSearchProvider.notifier);
    _searchNotifier!.state = widget.searchQuery;
    _chargeTypes = [];
  }

  @override
  void dispose() {
    for (final c in _chargeControllers.values) {
      c.dispose();
    }
    for (final c in _chargeNameControllers.values) {
      c.dispose();
    }
    _customerSearchController.dispose();
    _searchNotifier?.state = '';
    _searchNotifier = null;
    super.dispose();
  }

  void _addToCartDirect(ProductEntity product) {
    _doAdd(product);
  }

  Future<void> _doAdd(ProductEntity product) async {
    try {
      await widget.cartNotifier.loadProductUnits(product.id);
      if (!mounted) return;
      final rawUnits = widget.cartNotifier.getProductUnits(product.id);

      if (rawUnits == null || rawUnits.isEmpty) {
        widget.cartNotifier.addProduct(product, quantity: 1.0);
        return;
      }

      final db = ServiceLocator.instance.database;
      final enriched = <ProductUnit>[];
      for (final u in rawUnits) {
        final record = await (db.select(db.units)
              ..where((t) => t.id.equals(u.unitId)))
            .getSingleOrNull();
        enriched.add(ProductUnit(
          id: u.id,
          productId: u.productId,
          unitId: u.unitId,
          conversionFactor: u.conversionFactor,
          sellingPrice: u.sellingPrice,
          barcode: u.barcode,
          isDefault: u.isDefault,
          unitName: record?.name,
          unitSymbol: record?.symbol,
        ));
      }

      if (!mounted) return;
      widget.cartNotifier.setProductUnitsCache(product.id, enriched);

      final defaultUnit = enriched.firstWhere(
        (u) => u.isDefault,
        orElse: () => enriched.first,
      );
      widget.cartNotifier.addProduct(product, quantity: 1.0, selectedUnit: defaultUnit);
    } catch (_) {
      if (mounted) widget.cartNotifier.addProduct(product, quantity: 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 900;

    return Scaffold(
      backgroundColor: surfaceColor,
      endDrawer: isSmallScreen
          ? Drawer(
              width: 350,
              child: SafeArea(child: _buildInvoiceSidebar()),
            )
          : null,
      body: Column(
        children: [
          _buildIndustrialHeader(isSmallScreen),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (isSmallScreen) ...[
                          ProductSearchBar(
                            onProductSelected: _addToCartDirect,
                            onBarcodeInput: widget.onBarcodeScanned,
                          ),
                          const SizedBox(height: 16),
                          _buildCustomerSection(),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ProductSearchBar(
                                  onProductSelected: _addToCartDirect,
                                  onBarcodeInput: widget.onBarcodeScanned,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildCustomerSection(),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Expanded(
                          child: CartTableWidget(
                            items: widget.cartState.items,
                            getProductUnits: (id) =>
                                widget.cartNotifier.getProductUnits(id),
                            onQuantityChanged: (item, qty) {
                              widget.cartNotifier.updateQuantity(
                                item.product,
                                qty,
                                selectedUnit: item.selectedUnit,
                              );
                            },
                            onUnitChanged: (item, unit) {
                              widget.cartNotifier.updateItemUnit(
                                item.product,
                                unit,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isSmallScreen)
                  Container(
                    width: 360,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(left: BorderSide(color: onSurface, width: 2)),
                    ),
                    child: _buildInvoiceSidebar(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _buildCustomerSearchBar()),
            const SizedBox(width: 8),
            _buildAddCustomerButton(),
          ],
        ),
        if (_customerSearchController.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildCustomerDropdown(),
        ],
      ],
    );
  }

  Widget _buildIndustrialHeader(bool isSmallScreen) {
    List<Widget> headerItems = [
      const Text(
        'RETAIL POS',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: -0.5),
      ),
      const SizedBox(width: 16),
      _navItem("POS", isActive: true),
      _navItem("Orders", onTap: () => context.go('/sales-history')),
      _navItem("Customers", onTap: () => context.go('/customers')),
      _navItem("Reports", onTap: () => context.go('/reports')),
      if (!isSmallScreen) const Spacer(),
      IconButton(onPressed: () => ServiceLocator.instance.syncEngine.pull(), icon: const Icon(Icons.refresh, size: 20)),
      IconButton(onPressed: widget.cartState.items.isEmpty ? null : () => _showInvoiceModal(context), icon: const Icon(Icons.print, size: 20)),
      IconButton(onPressed: widget.onOpenInvoiceSettings, icon: const Icon(Icons.settings, size: 20)),
      if (isSmallScreen)
        Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: const Icon(Icons.shopping_cart, size: 20),
            color: const Color(0xFF006B5E),
          ),
        ),
    ];

    return Container(
      height: isSmallScreen ? null : 48,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 12 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: outlineColor)),
      ),
      child: isSmallScreen
          ? Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: headerItems,
            )
          : Row(children: headerItems),
    );
  }

  Widget _buildInvoiceSidebar() {
    final subtotal = widget.cartState.subtotal;
    final tax = widget.cartState.taxAmount;
    final total = widget.cartState.total;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: sidebarHeaderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "INVOICE\nBUILDER",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -1),
                  ),
                  const Icon(Icons.receipt_long, size: 36, color: Colors.black),
                ],
              ),
              const SizedBox(height: 8),
              _label("REF: $_invoiceRef"),
              const SizedBox(height: 12),
              _customerRow(),
            ],
          ),
        ),
        Expanded(child: _buildAdditionalCharges()),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sidebarHeaderColor,
            border: Border(top: BorderSide(color: onSurface, width: 2)),
          ),
          child: Column(
            children: [
              _totalLine("SUBTOTAL", "Rs${subtotal.toStringAsFixed(2)}"),
              _totalLine("TAX", "Rs${tax.toStringAsFixed(2)}"),
              if (widget.cartState.totalDiscount > 0)
                _totalLine("DISCOUNT", "-Rs${widget.cartState.totalDiscount.toStringAsFixed(2)}"),
              if (widget.cartState.additionalChargesTotal > 0)
                _totalLine("CHARGES", "Rs${widget.cartState.additionalChargesTotal.toStringAsFixed(2)}"),
              const Divider(height: 16),
              _totalLine("TOTAL", "Rs${total.toStringAsFixed(2)}"),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _actionButton("SAVE DRAFT", const Color(0xFF333333), onTap: () => _showInvoiceModal(context))),
                  const SizedBox(width: 8),
                  Expanded(child: _actionButton("INVOICE", const Color(0xFF006B5E), onTap: () => _showInvoiceModal(context))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _customerRow() {
    final customer = widget.cartState.selectedCustomer;
    return InkWell(
      onTap: widget.onShowAddCustomerDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: outlineColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              customer != null ? customer.name : "Walk-in Customer",
              style: TextStyle(fontSize: 12, color: customer != null ? Colors.black : Colors.grey[500]),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String title, {bool isActive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF006B5E) : Colors.grey,
            decoration: isActive ? TextDecoration.underline : null,
            decorationThickness: 2,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
      );

  Widget _buildAdditionalCharges() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label("Additional Charges"),
              TextButton.icon(
                onPressed: _addNewCharge,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Add", style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._chargeTypes.asMap().entries.map((entry) => _buildChargeRow(entry.value, entry.key)),
        ],
      ),
    );
  }

  void _addNewCharge() {
    final newChargeName = 'New Charge ${_chargeTypes.length + 1}';
    setState(() {
      _chargeTypes.add(newChargeName);
      _chargeControllers[newChargeName] = TextEditingController();
      _chargeNameControllers[newChargeName] = TextEditingController();
    });
  }

  void _removeCharge(int index) {
    final name = _chargeTypes[index];
    final amount = double.tryParse(_chargeControllers[name]?.text ?? '') ?? 0.0;
    if (amount > 0) {
      widget.cartNotifier.setAdditionalCharge(name, 0);
    }
    _chargeControllers[name]?.dispose();
    _chargeNameControllers[name]?.dispose();
    _chargeControllers.remove(name);
    _chargeNameControllers.remove(name);
    _savedCharges.remove(name);
    setState(() {
      _chargeTypes.removeAt(index);
    });
  }

  Widget _buildChargeRow(String name, int index) {
    final controller = _chargeControllers[name]!;
    final nameController = _chargeNameControllers[name]!;
    final isSaved = _savedCharges.contains(name);
    final amount = double.tryParse(controller.text) ?? 0.0;
    final displayName = nameController.text.trim().isEmpty ? name : nameController.text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          if (isSaved) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _savedCharges.remove(name)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(
                    displayName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _savedCharges.remove(name)),
              child: Container(
                width: 160,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                alignment: Alignment.centerRight,
                child: Text(
                  'Rs${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: nameController,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: "Charge name",
                    hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: outlineColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: outlineColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF006B5E), width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    _savedCharges.remove(name);
                    final oldName = name;
                    final newName = val.trim();
                    if (newName.isNotEmpty && newName != oldName) {
                      final amount = double.tryParse(controller.text) ?? 0.0;
                      if (amount > 0) {
                        widget.cartNotifier.setAdditionalCharge(oldName, 0);
                        widget.cartNotifier.setAdditionalCharge(newName, amount);
                      }
                      _chargeControllers[newName] = _chargeControllers.remove(oldName)!;
                      _chargeNameControllers[newName] = _chargeNameControllers.remove(oldName)!;
                      setState(() {
                        final idx = _chargeTypes.indexOf(oldName);
                        if (idx != -1) _chargeTypes[idx] = newName;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    prefixText: 'Rs',
                    prefixStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: outlineColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: outlineColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF006B5E), width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    _savedCharges.remove(name);
                    final amount = double.tryParse(val) ?? 0.0;
                    widget.cartNotifier.setAdditionalCharge(name, amount);
                  },
                  onSubmitted: (val) {
                    final enteredName = nameController.text.trim();
                    final enteredAmount = double.tryParse(val) ?? 0.0;
                    if (enteredName.isNotEmpty && enteredAmount > 0) {
                      widget.cartNotifier.setAdditionalCharge(name, enteredAmount);
                      setState(() => _savedCharges.add(name));
                    }
                  },
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _removeCharge(index),
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, String value) {
    final isGrandTotal = label == "TOTAL";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isGrandTotal ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: isGrandTotal ? Colors.black : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isGrandTotal ? 22 : 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: isGrandTotal ? const Color(0xFF006B5E) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String text, Color color, {VoidCallback? onTap}) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: const RoundedRectangleBorder()),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCustomerSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(Icons.person_search, color: Colors.grey[600], size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _customerSearchController,
              decoration: InputDecoration(
                hintText: 'Search customer...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                isDense: true,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              onChanged: (value) {
                ref.read(customerSearchProvider.notifier).state = value;
                setState(() {});
              },
            ),
          ),
          if (_customerSearchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
              onPressed: () {
                _customerSearchController.clear();
                ref.read(customerSearchProvider.notifier).state = '';
                setState(() {});
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildAddCustomerButton() {
    return Tooltip(
      message: 'Add Customer',
      child: InkWell(
        onTap: widget.onShowAddCustomerDialog,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF006B5E).withValues(alpha: 0.1),
            border: Border.all(color: const Color(0xFF006B5E).withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add_alt_1, size: 16, color: Color(0xFF006B5E)),
              SizedBox(width: 6),
              Text(
                'Add Customer',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF006B5E)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDropdown() {
    final customerSearch = ref.watch(customerSearchProvider);
    final customersAsync = ref.watch(posCustomerListProvider);

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: customersAsync.when(
          data: (customers) {
            final filtered = customers.where((c) {
              final q = customerSearch.toLowerCase();
              return c.name.toLowerCase().contains(q) ||
                  (c.phone?.contains(q) ?? false) ||
                  (c.email?.contains(q) ?? false);
            }).toList();

            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _customerOption(
                  name: 'Create New: "$customerSearch"',
                  details: 'Add as new customer',
                  icon: Icons.person_add,
                  onTap: () {
                    widget.onShowAddCustomerDialog();
                    _customerSearchController.clear();
                    ref.read(customerSearchProvider.notifier).state = '';
                    setState(() {});
                  },
                ),
                ...filtered.map((c) => _customerOption(
                      name: c.name,
                      details: c.phone ?? c.email ?? 'No contact',
                      icon: Icons.person,
                      onTap: () {
                        widget.cartNotifier.setCustomer(c);
                        _customerSearchController.clear();
                        ref.read(customerSearchProvider.notifier).state = '';
                        setState(() {});
                      },
                    )),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $err', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerOption({
    required String name,
    required String details,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF006B5E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: const Color(0xFF006B5E)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(details, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoiceModal(BuildContext context) {
    if (widget.cartState.items.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _RetailInvoiceModal(
        cartState: widget.cartState,
        onSaveDraft: (paymentMethod) =>
            widget.onCheckout(shouldSave: false, paymentMethod: paymentMethod),
        onFinalize: (paymentMethod) =>
            widget.onCheckout(shouldSave: true, paymentMethod: paymentMethod),
      ),
    );
  }
}

// ─── Invoice Modal ────────────────────────────────────────────────────────────

class _RetailInvoiceModal extends StatefulWidget {
  final CartState cartState;
  final void Function(String paymentMethod) onSaveDraft;
  final void Function(String paymentMethod) onFinalize;

  const _RetailInvoiceModal({
    required this.cartState,
    required this.onSaveDraft,
    required this.onFinalize,
  });

  @override
  State<_RetailInvoiceModal> createState() => _RetailInvoiceModalState();
}

class _RetailInvoiceModalState extends State<_RetailInvoiceModal> {
  String _selectedPayment = 'CASH';
  late final String _invoiceRef;

  @override
  void initState() {
    super.initState();
    _invoiceRef = 'DRAFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
  }

  static const _green = Color(0xFF006B5E);
  static const _outline = Color(0xFFC3C5D9);
  static const _headerBg = Color(0xFFEDEDFA);

  static const List<({String value, IconData icon, String label})> _paymentOptions = [
    (value: 'UPI', icon: Icons.qr_code_rounded, label: 'UPI'),
    (value: 'CASH', icon: Icons.payments_outlined, label: 'Cash'),
    (value: 'BANK_TRANSFER', icon: Icons.account_balance_outlined, label: 'Bank Transfer'),
    (value: 'CARD', icon: Icons.credit_card_outlined, label: 'Cards'),
  ];

  @override
  Widget build(BuildContext context) {
    final customer = widget.cartState.selectedCustomer;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 24 : 12, 
        vertical: 24
      ),
      child: Center(
        child: Container(
          width: screenWidth > 600 ? 540 : screenWidth * 0.95,
          constraints: const BoxConstraints(maxHeight: 720),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(_invoiceRef),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCustomerSection(customer),
                      _buildItemsSection(),
                      _buildTotalsSection(),
                      _buildPaymentSection(screenWidth < 500),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String invoiceRef) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        color: _headerBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, size: 28, color: Colors.black87),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INVOICE BUILDER',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                Text(
                  'REF: $invoiceRef',
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: Colors.grey[600], size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(CustomerEntity? customer) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _outline.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 16, color: _green),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BILL TO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
              Text(
                customer?.name ?? 'Walk-in Customer',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (customer?.phone != null)
                Text(customer!.phone!, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _outline.withValues(alpha: 0.4))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ITEMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(flex: 4, child: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey))),
              Expanded(flex: 3, child: Text('Qty × Rate', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey))),
              Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey))),
            ],
          ),
          const Divider(height: 12),
          ...widget.cartState.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      item.product.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} × Rs${item.product.price.toStringAsFixed(0)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Rs${item.total.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    final subtotal = widget.cartState.subtotal;
    final tax = widget.cartState.taxAmount;
    final total = widget.cartState.total;
    final charges = widget.cartState.additionalChargesTotal;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      color: const Color(0xFFFAF8FF),
      child: Column(
        children: [
          _modalTotalLine('SUBTOTAL', 'Rs${subtotal.toStringAsFixed(2)}', isGrand: false),
          _modalTotalLine('TAX', 'Rs${tax.toStringAsFixed(2)}', isGrand: false),
          if (widget.cartState.totalDiscount > 0)
            _modalTotalLine('DISCOUNT', '-Rs${widget.cartState.totalDiscount.toStringAsFixed(2)}', isGrand: false),
          if (charges > 0)
            _modalTotalLine('CHARGES', 'Rs${charges.toStringAsFixed(2)}', isGrand: false),
          const Divider(height: 16),
          _modalTotalLine('TOTAL', 'Rs${total.toStringAsFixed(2)}', isGrand: true),
        ],
      ),
    );
  }

  Widget _modalTotalLine(String label, String value, {required bool isGrand}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isGrand ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: isGrand ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isGrand ? 22 : 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: isGrand ? _green : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _outline.withValues(alpha: 0.4)),
          bottom: BorderSide(color: _outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRANSACTION TERMS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          isSmallScreen 
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paymentOptions.map((opt) => _buildPaymentOptionButton(opt)).toList(),
              )
            : Row(
                children: _paymentOptions.map((opt) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: opt == _paymentOptions.last ? 0 : 8),
                      child: _buildPaymentOptionButton(opt),
                    ),
                  );
                }).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionButton(({String value, IconData icon, String label}) opt) {
    final selected = _selectedPayment == opt.value;
    return InkWell(
      onTap: () => setState(() => _selectedPayment = opt.value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 100, 
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _green : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _green : _outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(opt.icon, size: 20, color: selected ? Colors.white : Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              opt.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
      decoration: const BoxDecoration(
        color: _headerBg,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onSaveDraft(_selectedPayment);
              },
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('SAVE DRAFT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF333333),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF333333)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onFinalize(_selectedPayment);
              },
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('FINALIZE INVOICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}