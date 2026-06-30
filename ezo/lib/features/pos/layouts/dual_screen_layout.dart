import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/features/pos/layouts/base_pos_layout.dart';
import 'package:aeropos/features/pos/widgets/common/product_card.dart';
import 'package:aeropos/features/pos/widgets/common/category_chip.dart';
import 'package:aeropos/core/widgets/product_image.dart';

/// Dual Screen layout — cashier controls left, customer-facing right.
/// Large fonts on customer side for readability.
class DualScreenLayout extends BasePosLayout {
  const DualScreenLayout({
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
  });

  @override
  ConsumerState<DualScreenLayout> createState() => _DualScreenLayoutState();
}

class _DualScreenLayoutState extends BasePosLayoutState<DualScreenLayout> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout();
        }
        return _buildDesktopLayout();
      },
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: widget.onBack,
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 40,
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
                              hintText: 'Search products...',
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              isDense: true,
                              hintStyle: TextStyle(
                                  color: Colors.grey[400], fontSize: 13),
                            ),
                            onChanged: widget.onSearch,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: widget.cartState.items.isEmpty
                      ? null
                      : () => widget.onCheckout(shouldSave: true),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text(
                    widget.cartState.items.isEmpty
                        ? 'Empty'
                        : 'Pay  Rs ${widget.cartState.total.toInt()}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: widget.categories.when(
              data: (cats) => ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [
                  PosCategoryChip(
                    name: 'All',
                    isActive: widget.selectedCategoryId == null,
                    onTap: () => widget.onCategoryTap(null),
                  ),
                  const SizedBox(width: 6),
                  ...cats.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 6),
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
          ),
          Expanded(
            child: widget.products.when(
              data: (products) => GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: products.length,
                itemBuilder: (context, i) => PosProductCard(
                  product: products[i],
                  onTap: () => widget.onProductTap(products[i]),
                  size: PosCardSize.medium,
                ),
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // LEFT — Cashier controls (50%)
        Expanded(
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: Column(
              children: [
                // Cashier section label
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: const Row(
                    children: [
                      Icon(Icons.person, color: Color(0xFF0F172A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'CASHIER',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                // Category chips
                SizedBox(
                  height: 48,
                  child: widget.categories.when(
                    data: (cats) => ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      children: [
                        PosCategoryChip(
                          name: 'All',
                          isActive: widget.selectedCategoryId == null,
                          onTap: () => widget.onCategoryTap(null),
                        ),
                        const SizedBox(width: 6),
                        ...cats.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 6),
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
                ),
                // Product grid — 3 columns
                Expanded(
                  child: widget.products.when(
                    data: (products) => GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: products.length,
                      itemBuilder: (context, i) => PosProductCard(
                        product: products[i],
                        onTap: () => widget.onProductTap(products[i]),
                        size: PosCardSize.medium,
                      ),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
                // Cashier action buttons
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.cartState.items.isEmpty
                              ? null
                              : () => widget.onCheckout(shouldSave: true),
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text('Checkout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: widget.onOpenInvoiceSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Icon(Icons.settings, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Divider
        Container(width: 2, color: Colors.grey.shade300),

        // RIGHT — Customer display (50%)
        Expanded(
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                // Customer header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF007AFF),
                  child: const Column(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.white, size: 28),
                      SizedBox(height: 4),
                      Text(
                        'Your Order',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                // Customer cart items (large font)
                Expanded(
                  child: widget.cartState.items.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No items yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: widget.cartState.items.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 24),
                          itemBuilder: (context, i) =>
                              _customerItem(widget.cartState.items[i]),
                        ),
                ),
                // Customer total — large
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    children: [
                      _customerRow(
                        'Subtotal',
                        'Rs ${widget.cartState.subtotal.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      _customerRow(
                        'Tax',
                        'Rs ${widget.cartState.taxAmount.toStringAsFixed(2)}',
                      ),
                      if (widget.cartState.totalDiscount > 0) ...[
                        const SizedBox(height: 8),
                        _customerRow(
                          'Discount',
                          '-Rs ${widget.cartState.totalDiscount.toStringAsFixed(2)}',
                          isRed: true,
                        ),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Rs ${widget.cartState.total.toInt()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                              color: Color(0xFF007AFF),
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
      ],
    );
  }

  Widget _customerItem(CartItem item) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ProductImage(product: item.product, size: 60),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Qty: ${item.quantity}${item.selectedUnit?.unitSymbol != null ? ' ${item.selectedUnit!.unitSymbol}' : ''}  ×  Rs ${item.product.price.toInt()}',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Text(
          'Rs ${item.total.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _customerRow(String label, String value, {bool isRed = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            color: isRed ? Colors.red : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isRed ? Colors.red : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}
