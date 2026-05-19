import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/models/product_unit.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/theme/app_theme.dart';

class QuantityWithUnitDialog extends StatefulWidget {
  final ProductEntity product;
  final ProductUnit? currentUnit;
  final double currentQuantity;
  final List<ProductUnit> productUnits;
  final Function(double quantity, ProductUnit unit) onSave;

  const QuantityWithUnitDialog({
    super.key,
    required this.product,
    this.currentUnit,
    this.currentQuantity = 1.0,
    this.productUnits = const [],
    required this.onSave,
  });

  @override
  State<QuantityWithUnitDialog> createState() => _QuantityWithUnitDialogState();
}

class UnitWithName {
  final ProductUnit entity;
  final String? name;
  final String? symbol;

  UnitWithName({required this.entity, this.name, this.symbol});
}

class _QuantityWithUnitDialogState extends State<QuantityWithUnitDialog> {
  late TextEditingController _quantityController;
  List<UnitWithName> _productUnits = [];
  UnitWithName? _selectedUnit;
  double _calculatedPrice = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.currentQuantity.toString(),
    );
    _loadProductUnits();
  }

  Future<void> _loadProductUnits() async {
    final db = ServiceLocator.instance.database;

    List<UnitWithName> unitsWithNames = [];

    if (widget.productUnits.isNotEmpty) {
      for (final u in widget.productUnits) {
        final unit = await (db.select(
          db.units,
        )..where((t) => t.id.equals(u.unitId))).getSingleOrNull();
        unitsWithNames.add(
          UnitWithName(entity: u, name: unit?.name, symbol: unit?.symbol),
        );
      }
    } else {
      final dao = db.productUnitDao;
      final units = await dao.getUnitsForProduct(widget.product.id);

      for (final u in units) {
        unitsWithNames.add(
          UnitWithName(entity: u, name: u.unitName, symbol: u.unitSymbol),
        );
      }
    }

    UnitWithName? currentSelected;
    if (widget.currentUnit != null) {
      currentSelected = unitsWithNames.firstWhere(
        (u) => u.entity.id == widget.currentUnit!.id,
        orElse: () => unitsWithNames.first,
      );
    }

    setState(() {
      _productUnits = unitsWithNames;
      _selectedUnit =
          currentSelected ??
          (unitsWithNames.isNotEmpty ? unitsWithNames.first : null);
      _isLoading = false;
      _calculatePrice();
    });
  }

  void _calculatePrice() {
    if (_selectedUnit == null) {
      _calculatedPrice =
          widget.product.price *
          (double.tryParse(_quantityController.text) ?? 1);
      return;
    }

    final qty = double.tryParse(_quantityController.text) ?? 1;
    final qtyInBase = qty * _selectedUnit!.entity.conversionFactor;

    if (_selectedUnit!.entity.sellingPrice != null) {
      _calculatedPrice = _selectedUnit!.entity.sellingPrice! * qty;
      return;
    }

    final unitWithPrice =
        widget.productUnits.where((u) => u.sellingPrice != null).toList()
          ..sort((a, b) => b.conversionFactor.compareTo(a.conversionFactor));

    if (unitWithPrice.isNotEmpty && unitWithPrice.first.conversionFactor > 0) {
      final basePrice =
          unitWithPrice.first.sellingPrice! /
          unitWithPrice.first.conversionFactor;
      final rawPrice = qtyInBase * basePrice;
      _calculatedPrice = rawPrice.roundToDouble();
      return;
    }

    _calculatedPrice = widget.product.price * qty;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.scale,
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
                              'Set Quantity & Unit',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.product.name,
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
                        icon: const Icon(Icons.close, color: AppColors.grey400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (_productUnits.isNotEmpty) ...[
                    const Text(
                      'Unit',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<UnitWithName>(
                      initialValue: _selectedUnit,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: _productUnits.map((u) {
                        return DropdownMenuItem(
                          value: u,
                          child: Text(
                            '${u.name ?? 'Unit'} (${u.symbol ?? ''})',
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedUnit = val;
                          _calculatePrice();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'Quantity',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [1, 2, 5, 10].map((q) {
                      final selected =
                          double.tryParse(_quantityController.text) ==
                          q.toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _quantityController.text = q.toString();
                              _calculatePrice();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.grey50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.grey200,
                              ),
                            ),
                            child: Text(
                              '$q',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.grey700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: '1',
                      filled: true,
                      fillColor: AppColors.grey50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (_) {
                      setState(() => _calculatePrice());
                    },
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '₹${_calculatedPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            final qty = double.tryParse(_quantityController.text) ?? 1;
                            ProductUnit productUnit;

                            if (_selectedUnit != null) {
                              final unit = _selectedUnit!.entity;
                              productUnit = ProductUnit(
                                id: unit.id,
                                productId: unit.productId,
                                unitId: unit.unitId,
                                conversionFactor: unit.conversionFactor,
                                sellingPrice: unit.sellingPrice,
                                barcode: unit.barcode,
                                isDefault: unit.isDefault,
                                unitName: _selectedUnit!.name,
                                unitSymbol: _selectedUnit!.symbol,
                              );
                            } else {
                              productUnit = ProductUnit(
                                id: 0,
                                productId: widget.product.id,
                                unitId: widget.product.unitId ?? 0,
                                conversionFactor: 1.0,
                                sellingPrice: null,
                                isDefault: true,
                              );
                            }

                            widget.onSave(qty, productUnit);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Add to Cart',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}
