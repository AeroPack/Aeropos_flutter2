import 'package:flutter/material.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/core/widgets/product_image.dart';
import 'package:aeropos/core/theme/app_theme.dart';

/// Reusable cart item tile for POS layouts.
class PosCartItemTile extends StatelessWidget {
  final CartItem item;
  final CartNotifier cartNotifier;
  final void Function(CartItem item) onShowDiscount;
  final bool compact;

  const PosCartItemTile({
    super.key,
    required this.item,
    required this.cartNotifier,
    required this.onShowDiscount,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildNormal(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ProductImage(product: item.product, size: 36),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Rs ${item.total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          _buildQtyControls(compact: true),
        ],
      ),
    );
  }

  Widget _buildNormal(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ProductImage(product: item.product, size: 48),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${item.product.sku ?? "N/A"}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.grey400,
                      ),
                    ),
                    if (item.course != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.course!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                    if (item.modifiers != null &&
                        item.modifiers!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: (item.modifiers ?? [])
                            .map(
                              (m) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.grey100),
                                ),
                                child: Text(
                                  m,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              _buildQtyControls(),
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: () => cartNotifier.addProduct(
                  item.product,
                  modifiers: item.modifiers,
                  course: item.course,
                ), // In true app, this might be split, but remove is priority
                child: Container(), // Dummy for space
              ),
              GestureDetector(
                onTap: () => cartNotifier.removeProduct(
                  item.product,
                  selectedUnit: item.selectedUnit,
                  modifiers: item.modifiers,
                  course: item.course,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RATE',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.grey400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.selectedUnit != null
                          ? 'Rs${item.unitPrice.toStringAsFixed(2)}/${item.selectedUnit!.unitSymbol ?? ''}'
                          : 'Rs${item.unitPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'QTY',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.grey400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.selectedUnit != null
                          ? '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} ${item.selectedUnit!.unitSymbol ?? ''}'
                          : item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.grey400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rs${item.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyControls({bool compact = false}) {
    final iconSize = compact ? 12.0 : 16.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleBtn(
          Icons.remove,
          () => cartNotifier.updateQuantity(
            item.product,
            item.quantity - 1,
            modifiers: item.modifiers,
            course: item.course,
          ),
          iconSize,
        ),
        Container(
          width: compact ? 24 : 32,
          alignment: Alignment.center,
          child: Text(
            item.selectedUnit != null
                ? '${item.quantity.toInt()} ${item.selectedUnit!.unitSymbol ?? ''}'
                : '${item.quantity.toInt()}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 12 : 14,
              color: AppColors.text,
            ),
          ),
        ),
        _circleBtn(
          Icons.add,
          () => cartNotifier.updateQuantity(
            item.product,
            item.quantity + 1,
            modifiers: item.modifiers,
            course: item.course,
          ),
          iconSize,
          isPrimary: true,
        ),
      ],
    );
  }

  Widget _circleBtn(
    IconData icon,
    VoidCallback onTap,
    double size, {
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: size,
          color: isPrimary ? AppColors.surface : AppColors.grey600,
        ),
      ),
    );
  }

  // TODO: Uncomment when needed
  // Widget _detailCol(String label, String value, {bool isPrimary = false}) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         label,
  //         style: TextStyle(
  //           fontSize: 10,
  //           fontWeight: FontWeight.w900,
  //           letterSpacing: 0.5,
  //           color: AppColors.grey400,
  //         ),
  //       ),
  //       const SizedBox(height: 2),
  //       Text(
  //         value,
  //         style: TextStyle(
  //           fontSize: 14,
  //           fontWeight: FontWeight.w900,
  //           color: isPrimary ? AppColors.primary : AppColors.text,
  //         ),
  //       ),
  //     ],
  //   );
  // }
}
