import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/features/pos/layouts/base_pos_layout.dart';
import 'package:aeropos/features/pos/widgets/common/category_chip.dart';
import 'package:aeropos/features/pos/widgets/quantity_with_unit_dialog.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/core/database/app_database.dart';

class TouchLayout extends BasePosLayout {
  const TouchLayout({
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
    this.onSplitBill,
    this.onPrintReceipt,
    this.onOrderHold,
    this.onRecallOrder,
  });

  final VoidCallback? onSplitBill;
  final VoidCallback? onPrintReceipt;
  final VoidCallback? onOrderHold;
  final VoidCallback? onRecallOrder;

  @override
  ConsumerState<TouchLayout> createState() => _TouchLayoutState();
}

class _TouchLayoutState extends BasePosLayoutState<TouchLayout> {
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  bool _showNotes = false;
  bool _showCustomerSearch = false;
  bool _showFavoritesOnly = false;
  bool _showRecentOnly = false;
  final List<ProductEntity> _recentItems = [];
  final Set<int> _favoriteProductIds = {};
  String _selectedPaymentMethod = 'cash';
  final _customerSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Row(
        children: [
          Expanded(flex: 4, child: _buildCartPanel()),
          Expanded(flex: 7, child: _buildProductPanel()),
        ],
      ),
    );
  }

  Widget _buildCartPanel() {
    final cart = widget.cartState;
    final customer = cart.selectedCustomer;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCartHeader(customer),
          if (_showCustomerSearch) _buildCustomerSearchPanel(),
          Expanded(child: _buildCartItems()),
          if (_showNotes) _buildNotesSection(),
          _buildQuickActions(),
          _buildTotalsSection(cart),
          _buildPaymentSection(cart),
        ],
      ),
    );
  }

  Widget _buildCartHeader(CustomerEntity? customer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT ORDER',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${widget.cartState.items.length} items',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _actionIconBtn(
                Icons.person_add_outlined,
                'Add Customer',
                widget.onShowAddCustomerDialog,
                showBadge: customer == null,
              ),
              const SizedBox(width: 8),
              _actionIconBtn(Icons.history, 'Recall', widget.onRecallOrder),
            ],
          ),
          if (customer != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customer.name,
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      widget.cartNotifier.setCustomer(null);
                      _customerSearchController.clear();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionIconBtn(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    bool showBadge = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              if (showBadge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSearchPanel() {
    final customerSearch = ref.watch(customerSearchProvider);
    final customersAsync = ref.watch(posCustomerListProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _customerSearchController,
                    onChanged: (val) =>
                        ref.read(customerSearchProvider.notifier).state = val,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search customer...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (customerSearch.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: customersAsync.when(
                data: (customers) => ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline, size: 20),
                      title: const Text(
                        'Walk-in Customer',
                        style: TextStyle(fontSize: 13),
                      ),
                      dense: true,
                      onTap: () {
                        widget.cartNotifier.setCustomer(null);
                        ref.read(customerSearchProvider.notifier).state = '';
                        setState(() => _showCustomerSearch = false);
                      },
                    ),
                    ...customers.map(
                      (c) => ListTile(
                        leading: const Icon(Icons.person, size: 20),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        dense: true,
                        onTap: () {
                          widget.cartNotifier.setCustomer(c);
                          ref.read(customerSearchProvider.notifier).state = '';
                          setState(() => _showCustomerSearch = false);
                        },
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    if (widget.cartState.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cart is Empty',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap products to add them here',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: widget.cartState.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildCartItem(widget.cartState.items[i]),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                    ),
                    if (item.product.sku != null)
                      Text(
                        'SKU: ${item.product.sku}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Rs ${item.product.price.toStringAsFixed(0)} × ${item.quantity}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        if (item.manualDiscount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF16A34A,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.isPercentDiscount
                                  ? '-${item.manualDiscount.toStringAsFixed(0)}%'
                                  : '-Rs ${item.manualDiscount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                'Rs ${item.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _qtyButton(
                Icons.remove,
                () => widget.cartNotifier.updateQuantity(
                  item.product,
                  item.quantity - 1,
                ),
              ),
              GestureDetector(
                onTap: () => _showQuantityDialog(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    '${item.quantity}${item.selectedUnit?.unitSymbol != null ? ' ${item.selectedUnit!.unitSymbol}' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              _qtyButton(
                Icons.add,
                () => widget.cartNotifier.updateQuantity(
                  item.product,
                  item.quantity + 1,
                ),
              ),
              const Spacer(),
              _itemActionBtn(
                Icons.local_offer_outlined,
                () => widget.onShowItemDiscount(item),
              ),
              const SizedBox(width: 8),
              _itemActionBtn(
                Icons.delete_outline,
                () => widget.cartNotifier.removeProduct(
                  item.product,
                  selectedUnit: item.selectedUnit,
                ),
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon, color: const Color(0xFF3B82F6), size: 18),
      ),
    );
  }

  Widget _itemActionBtn(
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (isDestructive ? Colors.red : Colors.white).withValues(
            alpha: 0.1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.white70,
          size: 18,
        ),
      ),
    );
  }

  void _showQuantityDialog(CartItem item) {
    showDialog(
      context: context,
      builder: (ctx) => QuantityWithUnitDialog(
        product: item.product,
        currentUnit: item.selectedUnit,
        currentQuantity: item.quantity,
        productUnits: const [],
        onSave: (qty, unit) {
          widget.cartNotifier.updateQuantity(
            item.product,
            qty,
            selectedUnit: unit,
            modifiers: item.modifiers,
            course: item.course,
          );
        },
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_outlined,
                size: 16,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              const Text(
                'Order Notes',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Add notes...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _quickActionBtn(Icons.receipt, 'Split', widget.onSplitBill),
          ),
          Expanded(
            child: _quickActionBtn(Icons.print, 'Print', widget.onPrintReceipt),
          ),
          Expanded(
            child: _quickActionBtn(
              Icons.pause_circle,
              'Hold',
              widget.onOrderHold,
            ),
          ),
          Expanded(
            child: _quickActionBtn(
              Icons.note_add,
              'Notes',
              () => setState(() => _showNotes = !_showNotes),
            ),
          ),
          Expanded(
            child: _quickActionBtn(
              Icons.delete_sweep,
              'Clear',
              widget.onReset,
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionBtn(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: (isDestructive ? Colors.red : Colors.white).withValues(
            alpha: 0.1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? Colors.red : Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDestructive ? Colors.red : Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSection(CartState cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _totalRow(
            'Subtotal',
            'Rs ${cart.subtotal.toStringAsFixed(0)}',
            subtitle: '${cart.items.length} items',
          ),
          if (cart.itemDiscounts > 0)
            _totalRow(
              'Discounts',
              '- Rs ${cart.itemDiscounts.toStringAsFixed(0)}',
              valueColor: const Color(0xFF16A34A),
            ),
          if (cart.overallDiscount > 0)
            _totalRow(
              'Order Discount',
              '- Rs ${cart.overallDiscountAmount.toStringAsFixed(0)}',
              valueColor: const Color(0xFF16A34A),
            ),
          _totalRow('Tax', 'Rs ${cart.taxAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'TOTAL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: cart.total),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Text(
                    'Rs ${value.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    String value, {
    Color? valueColor,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(CartState cart) {
    final isEmpty = cart.items.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          if (!isEmpty) ...[
            Row(
              children: [
                _paymentChip('Cash', Icons.payments_outlined, 'cash'),
                const SizedBox(width: 8),
                _paymentChip('Card', Icons.credit_card, 'card'),
                const SizedBox(width: 8),
                _paymentChip('UPI', Icons.qr_code_2, 'qr_upi'),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: isEmpty
                  ? null
                  : () => widget.onCheckout(
                      shouldSave: true,
                      paymentMethod: _selectedPaymentMethod,
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getPaymentIcon(_selectedPaymentMethod),
                    size: 26,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEmpty
                        ? 'Cart is empty'
                        : 'PAY Rs ${cart.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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

  Widget _paymentChip(String label, IconData icon, String method) {
    final selected = _selectedPaymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPaymentMethod = method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF3B82F6)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF3B82F6)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : Colors.white70,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_outlined;
      case 'card':
        return Icons.credit_card;
      case 'qr_upi':
        return Icons.qr_code_2;
      default:
        return Icons.payment;
    }
  }

  Widget _buildProductPanel() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          _buildProductToolbar(),
          _buildCategoryChips(),
          Expanded(child: _buildProductGrid()),
        ],
      ),
    );
  }

  Widget _buildProductToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.search,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search products...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          onChanged: widget.onSearch,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            widget.onSearch('');
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _toolbarBtn(
                Icons.favorite_outline,
                'Favorites',
                () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                isActive: _showFavoritesOnly,
              ),
              const SizedBox(width: 8),
              _toolbarBtn(
                Icons.history,
                'Recent',
                () => setState(() => _showRecentOnly = !_showRecentOnly),
                isActive: _showRecentOnly,
              ),
              const SizedBox(width: 8),
              _toolbarBtn(
                Icons.settings_outlined,
                'Settings',
                widget.onOpenInvoiceSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolbarBtn(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: widget.categories.when(
        data: (cats) => ListView(
          scrollDirection: Axis.horizontal,
          children: [
            PosCategoryChip(
              name: 'All',
              isActive: widget.selectedCategoryId == null,
              onTap: () => widget.onCategoryTap(null),
              icon: Icons.grid_view,
            ),
            const SizedBox(width: 8),
            ...cats.map(
              (c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PosCategoryChip(
                  name: c.name,
                  isActive: widget.selectedCategoryId == c.id,
                  onTap: () => widget.onCategoryTap(c.id),
                ),
              ),
            ),
          ],
        ),
        loading: () => const SizedBox(),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _buildProductGrid() {
    return widget.products.when(
      data: (products) {
        List<ProductEntity> displayProducts = products;

        if (_showFavoritesOnly) {
          displayProducts = products
              .where((p) => _favoriteProductIds.contains(p.id))
              .toList();
        } else if (_showRecentOnly) {
          displayProducts = _recentItems;
        }

        if (displayProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showFavoritesOnly
                      ? Icons.favorite_border
                      : _showRecentOnly
                      ? Icons.history
                      : Icons.inventory_2_outlined,
                  size: 80,
                  color: const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 16),
                Text(
                  _showFavoritesOnly
                      ? 'No favorites yet'
                      : _showRecentOnly
                      ? 'No recent items'
                      : 'No products found',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _showFavoritesOnly
                      ? 'Tap the heart on products to add favorites'
                      : _showRecentOnly
                      ? 'Items you add will appear here'
                      : 'Try a different search',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: displayProducts.length,
          itemBuilder: (_, i) => _buildProductCard(displayProducts[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildProductCard(ProductEntity product) {
    final isFavorite = _favoriteProductIds.contains(product.id);
    final inCart = widget.cartState.items.any(
      (i) => i.product.id == product.id,
    );

    return Stack(
      children: [
        GestureDetector(
          onTap: () => _addToCart(product),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Rs ${product.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          if (inCart) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Added',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isFavorite) {
                  _favoriteProductIds.remove(product.id);
                } else {
                  _favoriteProductIds.add(product.id);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: isFavorite ? Colors.red : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _addToCart(ProductEntity product) {
    widget.onProductTap(product);
    setState(() {
      _recentItems.removeWhere((p) => p.id == product.id);
      _recentItems.insert(0, product);
      if (_recentItems.length > 10) {
        _recentItems.removeLast();
      }
    });
  }
}
