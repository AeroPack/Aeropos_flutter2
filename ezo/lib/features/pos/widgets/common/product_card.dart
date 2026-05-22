import 'package:flutter/material.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/widgets/product_image.dart';
import 'package:aeropos/core/theme/app_theme.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:drift/drift.dart' show OrderingTerm;

enum PosCardSize { small, medium, large }

class PosProductCard extends StatefulWidget {
  final ProductEntity product;
  final VoidCallback onTap;
  final PosCardSize size;
  final bool showImage;
  final bool showPrice;
  final bool showSku;
  final bool showStock;

  const PosProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.size = PosCardSize.medium,
    this.showImage = true,
    this.showPrice = true,
    this.showSku = false,
    this.showStock = true,
  });

  @override
  State<PosProductCard> createState() => _PosProductCardState();
}

class _PosProductCardState extends State<PosProductCard> {
  List<ProductUnitEntity> _productUnits = [];
  bool _unitsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProductUnits();
  }

  Future<void> _loadProductUnits() async {
    try {
      final db = ServiceLocator.instance.database;
      final units =
          await (db.select(db.productUnits)
                ..where((t) => t.productId.equals(widget.product.id))
                ..orderBy([(t) => OrderingTerm.asc(t.conversionFactor)]))
              .get();
      if (mounted) {
        setState(() {
          _productUnits = units;
          _unitsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _unitsLoaded = true);
      }
    }
  }

  String _formatStock(num stock) {
    if (stock >= 1000) {
      return '${(stock / 1000).toStringAsFixed(1)} kg';
    } else {
      return '${stock.toInt()} g';
    }
  }

  IconData _getUnitIcon(String? symbol) {
    switch (symbol?.toLowerCase()) {
      case 'kg':
      case 'kilogram':
        return Icons.scale;
      case 'g':
      case 'gram':
        return Icons.scale_outlined;
      case 'pkt':
      case 'packet':
        return Icons.inventory_2;
      case 'pc':
      case 'piece':
        return Icons.crop_square;
      default:
        return Icons.straighten;
    }
  }

  double get _imageSize {
    switch (widget.size) {
      case PosCardSize.small:
        return 80;
      case PosCardSize.medium:
        return 100;
      case PosCardSize.large:
        return 150;
    }
  }

  double get _titleSize {
    switch (widget.size) {
      case PosCardSize.small:
        return 11;
      case PosCardSize.medium:
        return 13;
      case PosCardSize.large:
        return 15;
    }
  }

  double get _priceSize {
    switch (widget.size) {
      case PosCardSize.small:
        return 12;
      case PosCardSize.medium:
        return 14;
      case PosCardSize.large:
        return 16;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border(
            top: BorderSide(color: const Color(0xFF1976D2).withValues(alpha: 0.3), width: 2),
            left: BorderSide(color: AppColors.grey200, width: 0.5),
            right: BorderSide(color: AppColors.grey200, width: 0.5),
            bottom: BorderSide(color: AppColors.grey300, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showImage)
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: ProductImage(
                        product: widget.product,
                        size: _imageSize,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: _titleSize,
                      color: AppColors.text,
                      height: 1.2,
                    ),
                    maxLines: widget.size == PosCardSize.small ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.showSku && widget.product.sku != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        'SKU: ${widget.product.sku}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppColors.grey400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (_unitsLoaded && _productUnits.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: _productUnits.map((pu) {
                          final symbol = _getUnitSymbol(pu.unitId);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.grey100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getUnitIcon(symbol),
                                  size: 10,
                                  color: AppColors.grey600,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  symbol ?? '',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.grey600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (widget.showPrice)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Rs ${widget.product.price.toInt()}',
                        style: TextStyle(
                          color: const Color(0xFF1976D2),
                          fontWeight: FontWeight.w800,
                          fontSize: _priceSize,
                        ),
                      ),
                    ),
                  if (widget.showStock && widget.product.stockQuantity > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Stock: ${_formatStock(widget.product.stockQuantity)}',
                        style: TextStyle(
                          fontSize: 9,
                          color: widget.product.stockQuantity > 10
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w500,
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
  }

  String? _getUnitSymbol(int unitId) {
    // This will be handled in the widget since we need async
    return null;
  }
}
