import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/core/models/product_unit.dart';

class CartTableWidget extends StatefulWidget {
  final List<CartItem> items;
  final void Function(CartItem item, double qty) onQuantityChanged;
  final void Function(CartItem item, ProductUnit unit) onUnitChanged;
  final List<ProductUnit>? Function(int productId) getProductUnits;

  const CartTableWidget({
    super.key,
    required this.items,
    required this.onQuantityChanged,
    required this.onUnitChanged,
    required this.getProductUnits,
  });

  @override
  State<CartTableWidget> createState() => _CartTableWidgetState();
}

class _CartTableWidgetState extends State<CartTableWidget> {
  final Map<int, TextEditingController> _qtyControllers = {};

  @override
  void dispose() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(CartItem item) {
    final key = item.product.id;
    if (!_qtyControllers.containsKey(key)) {
      _qtyControllers[key] = TextEditingController(text: item.quantity.toStringAsFixed(0));
    } else {
      final c = _qtyControllers[key]!;
      if (c.text != item.quantity.toStringAsFixed(0)) {
        c.text = item.quantity.toStringAsFixed(0);
      }
    }
    return _qtyControllers[key]!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFC3C5D9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 56, color: Colors.grey[200]),
              const SizedBox(height: 16),
              Text(
                "Search for products to add",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[400]),
              ),
              const SizedBox(height: 6),
              Text(
                "Type in the search bar above to find products",
                style: TextStyle(fontSize: 13, color: Colors.grey[300]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC3C5D9)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: widget.items.length,
              itemBuilder: (ctx, i) => _buildRow(widget.items[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final outlineColor = const Color(0xFFC3C5D9);
    final bgColor = const Color(0xFFEDEDFA);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: outlineColor)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      ),
      child: Row(
        children: [
          _headerCell("Product Name", flex: 3),
          _headerCell("HSN", flex: 2),
          _headerCell("Price", flex: 2),
          _headerCell("Taxable Amt", flex: 2),
          _headerCell("Unit", flex: 3),
          _headerCell("Qty", flex: 2),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRow(CartItem item) {
    final outlineColor = const Color(0xFFC3C5D9);
    final controller = _getController(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: outlineColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.manualDiscount > 0)
                  Text(
                    item.isPercentDiscount
                        ? "-${item.manualDiscount.toStringAsFixed(0)}%"
                        : "-\u20b9${item.manualDiscount.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 10, color: Colors.orange),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.product.hsn ?? '-',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "\u20b9${item.calculatedPrice.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "\u20b9${item.subtotal.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildUnitCell(item, outlineColor),
          ),
          Expanded(
            flex: 2,
            child: _QtyControl(
              controller: controller,
              onChanged: (qty) {
                widget.onQuantityChanged(item, qty);
                controller.text = qty.toInt().toString();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _unitLabel(CartItem item) {
    final unit = item.selectedUnit;
    if (unit == null) return 'unit';
    final name = unit.unitName ?? '';
    final symbol = unit.unitSymbol ?? '';
    if (name.isEmpty && symbol.isEmpty) return 'unit';
    return symbol.isNotEmpty ? "$name ($symbol)" : name;
  }

  Widget _buildUnitCell(CartItem item, Color outlineColor) {
    final units = widget.getProductUnits(item.product.id) ?? [];
    final hasChoice = units.length > 1;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: outlineColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              _unitLabel(item),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasChoice) const Icon(Icons.unfold_more, size: 14, color: Colors.grey),
        ],
      ),
    );

    if (!hasChoice) return chip;

    return PopupMenuButton<int>(
      initialValue: item.selectedUnit?.id,
      onSelected: (unitId) {
        final unit = units.firstWhere(
          (u) => u.id == unitId,
          orElse: () => units.first,
        );
        widget.onUnitChanged(item, unit);
      },
      padding: EdgeInsets.zero,
      itemBuilder: (context) => units.map((u) {
        final name = u.unitName ?? '';
        final symbol = u.unitSymbol ?? '';
        final label = symbol.isNotEmpty
            ? '$name ($symbol)'
            : name.isNotEmpty
                ? name
                : 'unit';
        return PopupMenuItem<int>(
          value: u.id,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      child: chip,
    );
  }
}

class _QtyControl extends StatefulWidget {
  final TextEditingController controller;
  final void Function(double qty) onChanged;

  const _QtyControl({required this.controller, required this.onChanged});

  @override
  State<_QtyControl> createState() => _QtyControlState();
}

class _QtyControlState extends State<_QtyControl> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _increment() {
    final current = double.tryParse(_controller.text) ?? 1;
    widget.onChanged(current + 1);
  }

  void _decrement() {
    final current = double.tryParse(_controller.text) ?? 1;
    if (current > 0) {
      widget.onChanged(current - 1); // reaches 0 → CartNotifier.updateQuantity removes the item
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC3C5D9)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _decrement,
            child: Container(
              width: 32,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey[200]!)),
              ),
              child: const Icon(Icons.remove, size: 14, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus) {
                  final val = double.tryParse(_controller.text);
                  if (val != null && val >= 0) {
                    widget.onChanged(val);
                  }
                }
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  isDense: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onSubmitted: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed >= 0) {
                    widget.onChanged(parsed);
                  }
                },
              ),
            ),
          ),
          InkWell(
            onTap: _increment,
            child: Container(
              width: 32,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey[200]!)),
              ),
              child: const Icon(Icons.add, size: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}