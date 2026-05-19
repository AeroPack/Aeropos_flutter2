import 'package:flutter/material.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/core/theme/app_theme.dart';

/// Reusable totals display for POS layouts.
class PosTotalsDisplay extends StatelessWidget {
  final CartState cartState;
  final bool compact;
  final VoidCallback? onCheckout;
  final VoidCallback? onPrint;

  const PosTotalsDisplay({
    super.key,
    required this.cartState,
    this.compact = false,
    this.onCheckout,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 13.0 : 15.0;
    final totalFontSize = compact ? 18.0 : 22.0;

    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.grey100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                'BILLING SUMMARY',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                  color: AppColors.text.withValues(alpha: 0.6),
                ),
              ),
            ),
          _row(
            'Sub Total',
            'Rs ${cartState.subtotal.toStringAsFixed(2)}',
            fontSize: fontSize,
          ),
          _row(
            'Tax (GST)',
            'Rs ${cartState.taxAmount.toStringAsFixed(2)}',
            fontSize: fontSize,
          ),
          if (cartState.totalDiscount > 0)
            _row(
              'Discount',
              '-Rs ${cartState.totalDiscount.toStringAsFixed(2)}',
              fontSize: fontSize,
              isGreen: true,
            ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  compact ? 'GRAND TOTAL' : 'TOTAL AMOUNT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 14 : 15,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Rs ${cartState.total.toInt()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: totalFontSize,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          if (onCheckout != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: compact ? 44 : 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: cartState.items.isEmpty ? null : onCheckout,
                child: Text(
                  'COMPLETE ORDER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 13 : 15,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool isRed = false,
    bool isGreen = false,
    double fontSize = 16,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isGreen
                  ? Colors.green
                  : (isRed ? AppColors.error : AppColors.grey600),
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isGreen
                  ? Colors.green
                  : (isRed ? AppColors.error : AppColors.text),
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}
