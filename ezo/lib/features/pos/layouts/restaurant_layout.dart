import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/features/pos/layouts/base_pos_layout.dart';
import 'package:aeropos/features/pos/widgets/common/product_card.dart';
import 'package:aeropos/features/pos/widgets/common/totals_display.dart';
import 'package:aeropos/features/pos/widgets/quantity_with_unit_dialog.dart';
import 'package:aeropos/features/pos/widgets/barcode_camera_overlay.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/core/theme/app_theme.dart';
import 'package:aeropos/core/database/app_database.dart';

class RestaurantLayout extends BasePosLayout {
  const RestaurantLayout({
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
    this.onBarcodeScanned,
  });

  final VoidCallback? onSplitBill;
  final VoidCallback? onPrintReceipt;
  final VoidCallback? onOrderHold;
  final VoidCallback? onRecallOrder;
  final Future<void> Function(String)? onBarcodeScanned;

  @override
  ConsumerState<RestaurantLayout> createState() => _RestaurantLayoutState();
}

class _RestaurantLayoutState extends BasePosLayoutState<RestaurantLayout> {
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  final _customerSearchController = TextEditingController();
  bool _showNotes = false;
  bool _showBarcodeScan = false;
  bool _showCustomerSearch = false;
  String _selectedPaymentMethod = 'cash';
  final List<ProductEntity> _recentItems = [];
  final Set<int> _favoriteProductIds = {};
  bool _showFavoritesOnly = false;
  bool _showRecentOnly = false;
  bool _mobileCartOpen = false;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout(constraints);
        }
        return _buildDesktopLayout();
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Column(
            children: [
              _buildToolbar(),
              widget.categories.when(
                data: (cats) => _buildCategoryTabs(cats),
                loading: () => const SizedBox(height: 48),
                error: (e, _) =>
                    SizedBox(height: 48, child: Center(child: Text('$e'))),
              ),
              Expanded(
                child: widget.products.when(
                  data: (products) => _buildProductGrid(products),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 420,
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.text.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(-5, 0),
              ),
            ],
            border: Border(left: BorderSide(color: AppColors.grey200)),
          ),
          child: Column(
            children: [
              _buildCustomerSection(),
              Expanded(
                child: widget.cartState.items.isEmpty
                    ? _buildEmptyCart()
                    : _buildCartItems(),
              ),
              if (_showNotes) _buildNotesSection(),
              _buildQuickActionsBar(),
              PosTotalsDisplay(
                cartState: widget.cartState,
                onCheckout: () => widget.onCheckout(shouldSave: true),
              ),
              _buildPaymentSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints) {
    final cartOpenHeight = constraints.maxHeight * 0.88;
    final itemCount = widget.cartState.items.length;

    return Stack(
      children: [
        Column(
          children: [
            _buildToolbar(),
            widget.categories.when(
              data: (cats) => _buildCategoryTabs(cats),
              loading: () => const SizedBox(height: 48),
              error: (e, _) =>
                  SizedBox(height: 48, child: Center(child: Text('$e'))),
            ),
            Expanded(
              child: widget.products.when(
                data: (products) => _buildProductGrid(products),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            const SizedBox(height: 72),
          ],
        ),
        if (_mobileCartOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _mobileCartOpen = false),
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: 0,
          left: 0,
          right: 0,
          height: _mobileCartOpen ? cartOpenHeight : 72,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: _buildMobileCartPanel(itemCount),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCartPanel(int itemCount) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 2),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _mobileCartOpen = !_mobileCartOpen),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: itemCount > 0
                          ? AppColors.accent
                          : AppColors.grey400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$itemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      itemCount == 0
                          ? 'Cart is empty'
                          : '$itemCount item${itemCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: itemCount > 0
                            ? AppColors.text
                            : AppColors.grey500,
                      ),
                    ),
                  ),
                  if (itemCount > 0) ...[
                    Text(
                      'Rs ${widget.cartState.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  AnimatedRotation(
                    turns: _mobileCartOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: itemCount > 0
                          ? AppColors.accent
                          : AppColors.grey400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_mobileCartOpen)
            Expanded(
              child: Column(
                children: [
                  Divider(height: 1, color: AppColors.grey200),
                  _buildCustomerSection(),
                  Expanded(
                    child: widget.cartState.items.isEmpty
                        ? _buildEmptyCart()
                        : _buildCartItems(),
                  ),
                  if (_showNotes) _buildNotesSection(),
                  _buildQuickActionsBar(),
                  PosTotalsDisplay(
                    cartState: widget.cartState,
                    onCheckout: () => widget.onCheckout(shouldSave: true),
                  ),
                  SafeArea(top: false, child: _buildPaymentSection()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.grey100)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: widget.onBack,
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, color: AppColors.grey400, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: _showBarcodeScan
                            ? 'Scan or enter barcode...'
                            : 'Search products, SKU...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        isDense: true,
                        hintStyle: TextStyle(
                          color: AppColors.grey400,
                          fontSize: 14,
                        ),
                      ),
                      onChanged: (query) {
                        final barcodePattern = RegExp(r'^\d{4,}$');
                        if (barcodePattern.hasMatch(query)) {
                          widget.onBarcodeScanned?.call(query);
                          _searchController.clear();
                          return;
                        }
                        widget.onSearch(query);
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showBarcodeScan
                          ? Icons.qr_code_scanner
                          : Icons.barcode_reader,
                      size: 20,
                      color: _showBarcodeScan
                          ? AppColors.accent
                          : AppColors.grey400,
                    ),
                    onPressed: () {
                      if (defaultTargetPlatform == TargetPlatform.iOS ||
                          defaultTargetPlatform == TargetPlatform.macOS) {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => BarcodeCameraOverlay(
                            onScanned: widget.onBarcodeScanned,
                          ),
                        );
                      } else {
                        setState(() => _showBarcodeScan = !_showBarcodeScan);
                      }
                    },
                    tooltip: 'Toggle barcode mode',
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.grey400,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearch('');
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _toolbarBtn(
            Icons.favorite_outline,
            'Favorites',
            () => setState(() {
              _showFavoritesOnly = !_showFavoritesOnly;
              _showRecentOnly = false;
            }),
            isActive: _showFavoritesOnly,
          ),
          const SizedBox(width: 8),
          _toolbarBtn(
            Icons.history,
            'Recent',
            () => setState(() {
              _showRecentOnly = !_showRecentOnly;
              _showFavoritesOnly = false;
            }),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.accent.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isActive ? AppColors.accent : AppColors.grey200,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? AppColors.accent : AppColors.grey600,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(List<dynamic> categories) {
    return Container(
      height: 52,
      color: AppColors.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _tabItem(
            'All',
            widget.selectedCategoryId == null,
            () => widget.onCategoryTap(null),
          ),
          ...categories.map(
            (c) => _tabItem(
              c.name,
              widget.selectedCategoryId == c.id,
              () => widget.onCategoryTap(c.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? AppShadows.md : null,
          border: Border.all(
            color: active ? AppColors.primary : AppColors.grey200,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: active ? AppColors.surface : AppColors.grey600,
            fontSize: 11,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<ProductEntity> products) {
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
              size: 64,
              color: AppColors.grey200,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _showFavoritesOnly
                  ? 'No favorites yet'
                  : _showRecentOnly
                  ? 'No recent items'
                  : 'No products found',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: 0.4),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _showFavoritesOnly
                  ? 'Tap the heart icon on products to add favorites'
                  : _showRecentOnly
                  ? 'Items you add will appear here'
                  : 'Try a different search or category',
              style: TextStyle(color: AppColors.grey400, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (_, i) => _buildProductCard(displayProducts[i]),
    );
  }

  Widget _buildProductCard(ProductEntity product) {
    final isFavorite = _favoriteProductIds.contains(product.id);
    final inCart = widget.cartState.items.any(
      (i) => i.product.id == product.id,
    );

    return Stack(
      children: [
        PosProductCard(
          product: product,
          onTap: () => _addToCart(product),
          size: PosCardSize.large,
          showSku: true,
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
              padding: const EdgeInsets.all(4),
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
                size: 16,
                color: isFavorite ? Colors.red : AppColors.grey400,
              ),
            ),
          ),
        ),
        if (inCart)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, size: 14, color: Colors.white),
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

  Widget _buildCustomerSection() {
    final customer = widget.cartState.selectedCustomer;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(bottom: BorderSide(color: AppColors.grey200)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    setState(() => _showCustomerSearch = !_showCustomerSearch),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: customer != null
                        ? Colors.green.withValues(alpha: 0.1)
                        : AppColors.grey100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: customer != null
                          ? Colors.green.withValues(alpha: 0.3)
                          : AppColors.grey200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        customer != null ? Icons.person : Icons.person_search,
                        size: 16,
                        color: customer != null
                            ? Colors.green
                            : AppColors.grey500,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          customer?.name ?? 'Customer',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: customer != null
                                ? Colors.green.shade700
                                : AppColors.grey500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (customer != null)
                GestureDetector(
                  onTap: () {
                    widget.cartNotifier.setCustomer(null);
                    _customerSearchController.clear();
                    ref.read(customerSearchProvider.notifier).state = '';
                    setState(() => _showCustomerSearch = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
        if (_showCustomerSearch) _buildCustomerSearchPanel(),
      ],
    );
  }

  Widget _buildCustomerSearchPanel() {
    final customer = widget.cartState.selectedCustomer;
    final customerSearch = ref.watch(customerSearchProvider);
    final customersAsync = ref.watch(posCustomerListProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.grey200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customer != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF16A34A),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (customer.phone != null)
                          Text(
                            customer.phone!,
                            style: TextStyle(
                              color: const Color(
                                0xFF16A34A,
                              ).withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(Icons.search, size: 18, color: AppColors.grey400),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _customerSearchController,
                    onChanged: (val) =>
                        ref.read(customerSearchProvider.notifier).state = val,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search customer...',
                      hintStyle: TextStyle(
                        color: AppColors.grey400,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Add New Customer',
                  child: InkWell(
                    onTap: () {
                      setState(() => _showCustomerSearch = false);
                      widget.onShowAddCustomerDialog();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add, size: 18, color: AppColors.accent),
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
                border: Border.all(color: AppColors.grey200),
              ),
              child: customersAsync.when(
                data: (customers) => ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    _customerOption(
                      name: 'Walk-in Customer',
                      phone: null,
                      icon: Icons.person_outline,
                      onTap: () {
                        widget.cartNotifier.setCustomer(null);
                        ref.read(customerSearchProvider.notifier).state = '';
                        setState(() => _showCustomerSearch = false);
                      },
                    ),
                    ...customers.map(
                      (c) => _customerOption(
                        name: c.name,
                        phone: c.phone,
                        icon: Icons.person,
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
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _customerOption({
    required String name,
    required String? phone,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: AppColors.grey600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (phone != null)
                    Text(
                      phone,
                      style: TextStyle(fontSize: 11, color: AppColors.grey400),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: AppColors.grey200,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Cart is Empty',
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap products to add them here',
            style: TextStyle(color: AppColors.grey400, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: widget.cartState.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _cartItemTile(widget.cartState.items[i]),
    );
  }

  Widget _cartItemTile(CartItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.product.sku != null)
                      Text(
                        'SKU: ${item.product.sku}',
                        style: TextStyle(
                          color: AppColors.grey400,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'Rs ${item.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (item.manualDiscount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.isPercentDiscount
                      ? '-${item.manualDiscount.toStringAsFixed(0)}%'
                      : '-Rs ${item.manualDiscount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
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
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Text(
                    '${item.quantity}${item.selectedUnit?.unitSymbol != null ? ' ${item.selectedUnit!.unitSymbol}' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
              _iconBtn(
                Icons.local_offer_outlined,
                'Discount',
                () => widget.onShowItemDiscount(item),
              ),
              const SizedBox(width: 4),
              _iconBtn(
                Icons.delete_outline,
                'Remove',
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 16, color: AppColors.accent),
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: isDestructive ? Colors.red : AppColors.grey500,
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_outlined, size: 16, color: AppColors.grey500),
              const SizedBox(width: 6),
              Text(
                'Order Notes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add notes for this order...',
              hintStyle: TextStyle(color: AppColors.grey400, fontSize: 13),
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.grey200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.grey200),
              ),
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        border: Border(
          top: BorderSide(color: AppColors.grey100),
          bottom: BorderSide(color: AppColors.grey100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _quickActionButton(
            icon: Icons.receipt,
            label: 'Split Bill',
            onTap: widget.onSplitBill,
          ),
          _quickActionButton(
            icon: Icons.print,
            label: 'Print',
            onTap: widget.onPrintReceipt,
          ),
          _quickActionButton(
            icon: Icons.pause_circle_outline,
            label: 'Hold',
            onTap: widget.onOrderHold,
          ),
          _quickActionButton(
            icon: Icons.history,
            label: 'Recall',
            onTap: widget.onRecallOrder,
          ),
          _quickActionButton(
            icon: Icons.note_add_outlined,
            label: 'Notes',
            onTap: () => setState(() => _showNotes = !_showNotes),
          ),
          _quickActionButton(
            icon: Icons.delete_sweep_outlined,
            label: 'Clear',
            onTap: widget.onReset,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? Colors.red : AppColors.accent,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: isDestructive ? Colors.red : AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    final isEmpty = widget.cartState.items.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          if (!isEmpty) ...[
            Text(
              'PAYMENT METHOD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: AppColors.grey400,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _paymentMethodChip(
                    'Cash',
                    Icons.payments_outlined,
                    'cash',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _paymentMethodChip('Card', Icons.credit_card, 'card'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _paymentMethodChip(
                    'QR / UPI',
                    Icons.qr_code_2,
                    'qr_upi',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isEmpty
                  ? null
                  : () => widget.onCheckout(
                      shouldSave: true,
                      paymentMethod: _selectedPaymentMethod,
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: AppColors.grey200,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getPaymentIcon(_selectedPaymentMethod), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isEmpty
                        ? 'Cart is empty'
                        : 'Pay Rs ${widget.cartState.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

  Widget _paymentMethodChip(String label, IconData icon, String method) {
    final selected = _selectedPaymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.grey50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.grey200,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : AppColors.grey500,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
