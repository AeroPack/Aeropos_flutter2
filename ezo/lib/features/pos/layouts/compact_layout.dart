import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/features/pos/layouts/base_pos_layout.dart';
// import 'package:aeropos/features/pos/widgets/common/product_card.dart';
import 'package:aeropos/features/pos/widgets/common/totals_display.dart';
import 'package:aeropos/features/pos/widgets/quantity_with_unit_dialog.dart';
import 'package:aeropos/features/pos/widgets/barcode_camera_overlay.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/core/database/app_database.dart';

class CompactLayout extends BasePosLayout {
  const CompactLayout({
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
  ConsumerState<CompactLayout> createState() => _CompactLayoutState();
}

class _CompactLayoutState extends BasePosLayoutState<CompactLayout> {
  final _searchController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _notesController = TextEditingController();
  bool _showNotes = false;
  bool _showBarcodeScan = false;
  String _selectedPaymentMethod = 'cash';
  final List<ProductEntity> _recentItems = [];
  final Set<int> _favoriteProductIds = {};
  bool _showFavoritesOnly = false;
  bool _mobileCartOpen = false;

  static const Color _primaryBlue = Color(0xFF1976D2);
  static const Color _primaryBlueDark = Color(0xFF0D47A1);
  static const Color _accentBlue = Color(0xFF2196F3);

  // Layout breakpoints
  static const double _mobileBreak = 600;
  static const double _tabletBreak = 960;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerSearchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Increased width thresholds to make the cards noticeably larger
  int _gridColumns(double availableWidth) {
    if (availableWidth < 400) return 2; // Mobile
    if (availableWidth < 650) return 3; // Large Mobile / Small Tablet
    if (availableWidth < 950) return 4; // Tablet portrait
    if (availableWidth < 1300) return 5; // Tablet landscape / Small Desktop
    return 6; // Large Desktop
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < _mobileBreak) {
          return _buildMobileLayout(context, constraints);
        }
        return _buildSideBySideLayout(
          context,
          cartWidth: w < _tabletBreak ? 320.0 : 380.0,
        );
      },
    );
  }

  // ─── MOBILE LAYOUT ────────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context, BoxConstraints constraints) {
    final cartOpenHeight = constraints.maxHeight * 0.88;
    final itemCount = widget.cartState.items.length;

    return Stack(
      children: [
        Column(
          children: [
            _buildMobileToolbar(),
            widget.categories.when(
              data: (cats) => _buildCategoryTabs(cats, isMobile: true),
              loading: () => const SizedBox(height: 52),
              error: (e, _) => SizedBox(height: 52, child: Center(child: Text('$e'))),
            ),
            Expanded(
              child: widget.products.when(
                data: _buildProductGrid,
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
        color: Colors.white,
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
                color: Colors.grey[300],
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: itemCount > 0 ? _primaryBlue : Colors.grey[400],
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
                      itemCount == 0 ? 'Cart is empty' : '$itemCount item${itemCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: itemCount > 0 ? Colors.black87 : Colors.grey[500],
                      ),
                    ),
                  ),
                  if (itemCount > 0) ...[
                    Text(
                      'Rs ${widget.cartState.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _primaryBlueDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  AnimatedRotation(
                    turns: _mobileCartOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: itemCount > 0 ? _primaryBlue : Colors.grey[400],
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
                  Divider(height: 1, color: Colors.grey[200]),
                  _buildCartHeader(),
                  Expanded(
                    child: widget.cartState.items.isEmpty ? _buildEmptyCart() : _buildCartItems(),
                  ),
                  if (_showNotes) _buildNotesSection(),
                  _buildQuickActionsBar(),
                  PosTotalsDisplay(
                    cartState: widget.cartState,
                    compact: true,
                  ),
                  SafeArea(top: false, child: _buildPaymentSection()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: widget.onBack,
                tooltip: 'Back',
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront, color: _primaryBlue, size: 20),
              ),
              const Spacer(),
              _mobileIconBtn(
                icon: _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                tooltip: 'Favourites',
                isActive: _showFavoritesOnly,
                onTap: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
              ),
              const SizedBox(width: 8),
              _mobileIconBtn(
                icon: Icons.person_add_alt_1,
                tooltip: 'Add Customer',
                isActive: false,
                onTap: widget.onShowAddCustomerDialog,
                iconColor: _primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildProductSearchBar(height: 44),
        ],
      ),
    );
  }

  Widget _mobileIconBtn({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final color = iconColor ?? (isActive ? _primaryBlue : Colors.grey[600]!);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? _primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? _primaryBlue : Colors.grey[200]!),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _buildProductSearchBar({double height = 38}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, color: Colors.grey[400], size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _showBarcodeScan ? 'Scan or enter barcode...' : 'Search products...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: height > 40 ? 10 : 8),
                    isDense: true,
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
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
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              onPressed: () {
                _searchController.clear();
                widget.onSearch('');
              },
            ),
          IconButton(
            icon: Icon(
              _showBarcodeScan ? Icons.qr_code_scanner : Icons.qr_code,
              size: 20,
              color: _showBarcodeScan ? _accentBlue : Colors.grey[400],
            ),
            onPressed: () {
              if (Platform.isIOS || Platform.isMacOS) {
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
            tooltip: 'Scan Barcode',
          ),
        ],
      ),
    );
  }

  // ─── TABLET / DESKTOP LAYOUT ──────────────────────────────────────────────

  Widget _buildSideBySideLayout(BuildContext context, {required double cartWidth}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildDesktopToolbar(),
              widget.categories.when(
                data: (cats) => _buildCategoryTabs(cats),
                loading: () => const SizedBox(height: 44),
                error: (e, _) => SizedBox(height: 44, child: Center(child: Text('$e'))),
              ),
              Expanded(
                child: widget.products.when(
                  data: _buildProductGrid,
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: cartWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(-5, 0),
              ),
            ],
            border: Border(left: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Column(
            children: [
              _buildCartHeader(),
              Expanded(
                child: widget.cartState.items.isEmpty ? _buildEmptyCart() : _buildCartItems(),
              ),
              if (_showNotes) _buildNotesSection(),
              _buildQuickActionsBar(),
              PosTotalsDisplay(
                cartState: widget.cartState,
                compact: true,
              ),
              _buildPaymentSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: widget.onBack,
            tooltip: 'Back',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront, color: _primaryBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(Icons.search, color: Colors.grey[400], size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: _showBarcodeScan ? 'Scan or enter barcode...' : 'Search products...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      onChanged: widget.onSearch,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showBarcodeScan ? Icons.qr_code_scanner : Icons.qr_code,
                      size: 18,
                      color: _showBarcodeScan ? _accentBlue : Colors.grey[400],
                    ),
                    onPressed: () => setState(() => _showBarcodeScan = !_showBarcodeScan),
                    tooltip: 'Scan Barcode',
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
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
          const SizedBox(width: 8),
          _compactToolbarBtn(
            Icons.favorite_border,
            'Favorites',
            () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
            isActive: _showFavoritesOnly,
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(Icons.person_search, color: Colors.grey[400], size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _customerSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search customer...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      onChanged: (value) {
                        ref.read(customerSearchProvider.notifier).state = value;
                      },
                    ),
                  ),
                  if (_customerSearchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                      onPressed: () {
                        _customerSearchController.clear();
                        ref.read(customerSearchProvider.notifier).state = '';
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: _buildAddCustomerButton()),
        ],
      ),
    );
  }

  // ─── CATEGORY TABS ────────────────────────────────────────────────────────

  Widget _buildCategoryTabs(List<dynamic> categories, {bool isMobile = false}) {
    return Container(
      height: isMobile ? 52.0 : 44.0,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _compactTabItem(
            'ALL PRODUCTS',
            widget.selectedCategoryId == null,
            () => widget.onCategoryTap(null),
            isMobile: isMobile,
          ),
          ...categories.map(
            (c) => _compactTabItem(
              c.name.toUpperCase(),
              widget.selectedCategoryId == c.id,
              () => widget.onCategoryTap(c.id),
              isMobile: isMobile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactTabItem(String label, bool active, VoidCallback onTap, {bool isMobile = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        margin: EdgeInsets.only(right: 8, top: isMobile ? 8 : 6, bottom: isMobile ? 8 : 6),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 6 : 4),
        decoration: BoxDecoration(
          color: active ? _primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _primaryBlue : Colors.grey[200]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.grey[700],
            fontSize: isMobile ? 12 : 11,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ─── PRODUCT GRID & CUSTOM 3D MODERN PRODUCT CARD ─────────────────────────

  Widget _buildProductGrid(List<ProductEntity> products) {
    final displayProducts = _showFavoritesOnly
        ? products.where((p) => _favoriteProductIds.contains(p.id)).toList()
        : products;

    if (displayProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showFavoritesOnly ? Icons.favorite_border : Icons.inventory_2_outlined,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _showFavoritesOnly ? 'No favorites added' : 'No products found',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _showFavoritesOnly ? 'Tap ♡ on products to add to favorites' : 'Try different search or category',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridColumns(constraints.maxWidth),
          childAspectRatio: 0.82, // Taller ratio for larger looking cards
          crossAxisSpacing: 16,
          mainAxisSpacing: 18, // Extra vertical space for the 3D shadow lift
        ),
        itemCount: displayProducts.length,
        itemBuilder: (_, i) => _buildModernProductCard(displayProducts[i]),
      ),
    );
  }

  Widget _buildModernProductCard(ProductEntity product) {
    final isFavorite = _favoriteProductIds.contains(product.id);
    final inCart = widget.cartState.items.any((i) => i.product.id == product.id);

    double price = 0.0;
    int stock = 0;
    String? imageUrl;
    try { price = (product as dynamic).price?.toDouble() ?? 0.0; } catch (_) {}
    try { stock = (product as dynamic).stock ?? (product as dynamic).quantity ?? 0; } catch (_) {}
    try { imageUrl = (product as dynamic).imageUrl ?? (product as dynamic).image; } catch (_) {}

    // 3D Theme Variables
    final Color cardBorderColor = inCart ? _primaryBlue : const Color(0xFFE2E8F0); // Beautiful Slate 200
    final Color cardShadowColor = inCart ? _primaryBlue.withValues(alpha: 0.3) : const Color(0xFFCBD5E1); // Slate 300

    return GestureDetector(
      onTap: () => _addToCart(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cardBorderColor,
            width: 1.5,
          ),
          boxShadow: [
            // Soft ambient blur
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
            // Solid 3D Base Shadow
            BoxShadow(
              color: cardShadowColor,
              blurRadius: 0,
              offset: const Offset(0, 5), // Creating the thick 3D bottom edge
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Image Section (Expands to fill available top space) ---
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.grey[50],
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : _buildDummyImage(product.name),
                    ),
                  ),
                  
                  // Top Left: Stock Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildStockBadge(stock),
                  ),

                  // Top Right: Favorite Button
                  Positioned(
                    top: 6,
                    right: 6,
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
                          color: Colors.white.withValues(alpha: 0.95),
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
                          color: isFavorite ? Colors.redAccent : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // --- Info Section (Shrink-wraps to remove awkward spacing) ---
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.2,
                      color: Color(0xFF1E293B), // Slate 800 - elegant dark
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // SKU (Optional & Subtle)
                  if (product.sku != null && product.sku!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${product.sku}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8), // Slate 400
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Tight Spacing directly to the price
                  const SizedBox(height: 8),
                  
                  // Price & Action Button Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Rs ${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _primaryBlueDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: inCart ? _primaryBlue : const Color(0xFFF1F5F9), // Slate 100
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: inCart ? _primaryBlueDark : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Icon(
                          inCart ? Icons.check : Icons.add,
                          size: 16,
                          color: inCart ? Colors.white : _primaryBlue,
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
    );
  }

  Widget _buildDummyImage(String productName) {
    final initial = productName.isNotEmpty ? productName[0].toUpperCase() : '?';
    // Dynamic soft beautiful pastel gradients based on name length
    final colorIndex = productName.length % Colors.primaries.length;
    final color = Colors.primaries[colorIndex];
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 32, color: color.withValues(alpha: 0.6)),
            const SizedBox(height: 6),
            Text(
              initial,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBadge(int stock) {
    final bool outOfStock = stock <= 0;
    final bool lowStock = stock > 0 && stock <= 5;
    
    final Color bgColor = outOfStock ? Colors.redAccent : (lowStock ? Colors.orange : Colors.teal);
    final String label = outOfStock ? 'Out of Stock' : '$stock in stock';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _addToCart(ProductEntity product) {
    widget.onProductTap(product);
    setState(() {
      _recentItems.removeWhere((p) => p.id == product.id);
      _recentItems.insert(0, product);
      if (_recentItems.length > 8) _recentItems.removeLast();
    });
  }

  // ─── CART WIDGETS (shared between mobile sheet and desktop panel) ─────────

  Widget _buildCartHeader() {
    final customer = widget.cartState.selectedCustomer;
    final itemCount = widget.cartState.items.length;
    final itemTotal = widget.cartState.total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          if (customer != null) ...[
            Icon(Icons.person, size: 16, color: _primaryBlue),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                customer.name,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _primaryBlue),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else ...[
            const Text(
              'CART',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _primaryBlue),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$itemCount item${itemCount != 1 ? 's' : ''}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _primaryBlue),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rs ${itemTotal.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _primaryBlueDark),
          ),
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
            color: _primaryBlue.withValues(alpha: 0.1),
            border: Border.all(color: _primaryBlue.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add_alt_1, size: 16, color: _primaryBlue),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Add Customer',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primaryBlue),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Cart is empty',
            style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap products to add them to cart',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: widget.cartState.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, i) => _compactCartItemTile(widget.cartState.items[i]),
    );
  }

  Widget _compactCartItemTile(CartItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rs ${item.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: _primaryBlueDark),
              ),
            ],
          ),
          if (item.product.sku != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'SKU: ${item.product.sku}',
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
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
                      ? '${item.manualDiscount.toStringAsFixed(0)}% OFF'
                      : 'Rs ${item.manualDiscount.toStringAsFixed(2)} OFF',
                  style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _compactQtyButton(
                Icons.remove,
                () => widget.cartNotifier.updateQuantity(item.product, item.quantity - 1),
              ),
              GestureDetector(
                onTap: () => _showQuantityDialog(item),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}${item.selectedUnit?.unitSymbol != null ? ' ${item.selectedUnit!.unitSymbol}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              _compactQtyButton(
                Icons.add,
                () => widget.cartNotifier.updateQuantity(item.product, item.quantity + 1),
              ),
              const Spacer(),
              _compactIconBtn(
                Icons.local_offer_outlined,
                'Discount',
                () => widget.onShowItemDiscount(item),
              ),
              const SizedBox(width: 4),
              _compactIconBtn(
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

  Widget _compactQtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _primaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _primaryBlue.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 16, color: _primaryBlue),
      ),
    );
  }

  Widget _compactIconBtn(
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
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: isDestructive ? Colors.amber : Colors.grey[500],
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: TextField(
        controller: _notesController,
        maxLines: 2,
        onChanged: (value) => widget.cartNotifier.setNotes(value),
        decoration: InputDecoration(
          hintText: 'Add order notes (e.g., special instructions, gift wrap)...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          contentPadding: const EdgeInsets.all(10),
          isDense: true,
          prefixIcon: Icon(Icons.note_outlined, size: 16, color: Colors.grey[400]),
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[100]!),
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _compactQuickAction(Icons.receipt, 'Split', widget.onSplitBill)),
          Expanded(child: _compactQuickAction(Icons.print, 'Print', widget.onPrintReceipt)),
          Expanded(child: _compactQuickAction(Icons.pause_circle_outline, 'Hold', widget.onOrderHold)),
          Expanded(child: _compactQuickAction(Icons.history, 'Recall', widget.onRecallOrder)),
          Expanded(
            child: _compactQuickAction(
              Icons.note_add_outlined,
              'Notes',
              () => setState(() => _showNotes = !_showNotes),
              isActive: _showNotes,
            ),
          ),
          Expanded(
            child: _compactQuickAction(
              Icons.delete_sweep_outlined,
              'Clear',
              widget.onReset,
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactQuickAction(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool isDestructive = false,
    bool isActive = false,
  }) {
    final isDisabled = onTap == null;
    final color = isDisabled
        ? Colors.grey[300]!
        : isDestructive
            ? Colors.deepOrange
            : isActive
                ? _primaryBlue
                : Colors.grey[600]!;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? _primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    final isEmpty = widget.cartState.items.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          if (!isEmpty) ...[
            Row(
              children: [
                Expanded(child: _compactPaymentChip('Cash', Icons.payments_outlined, 'cash')),
                const SizedBox(width: 8),
                Expanded(child: _compactPaymentChip('Card', Icons.credit_card, 'card')),
                const SizedBox(width: 8),
                Expanded(child: _compactPaymentChip('QR/UPI', Icons.qr_code, 'qr_upi')),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isEmpty
                  ? null
                  : () => widget.onCheckout(
                        shouldSave: true,
                        paymentMethod: _selectedPaymentMethod,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: Colors.grey[200],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getPaymentIcon(_selectedPaymentMethod), size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      isEmpty
                          ? 'Cart is empty'
                          : 'PROCEED TO PAYMENT  •  Rs ${widget.cartState.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3),
                      overflow: TextOverflow.ellipsis,
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
      case 'cash': return Icons.payments_outlined;
      case 'card': return Icons.credit_card;
      case 'qr_upi': return Icons.qr_code;
      default: return Icons.payment;
    }
  }

  Widget _compactPaymentChip(String label, IconData icon, String method) {
    final selected = _selectedPaymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primaryBlue : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _primaryBlue : Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DESKTOP TOOLBAR HELPERS ──────────────────────────────────────────────

  Widget _compactToolbarBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? _primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(color: isActive ? _primaryBlue : Colors.grey[200]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isActive ? _primaryBlue : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? _primaryBlue : Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}