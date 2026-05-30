import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/features/pos/state/cart_state.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/features/pos/widgets/barcode_camera_overlay.dart';

class ProductSearchBar extends ConsumerStatefulWidget {
  final void Function(ProductEntity product) onProductSelected;
  final void Function(String)? onBarcodeInput;

  const ProductSearchBar({
    super.key,
    required this.onProductSelected,
    this.onBarcodeInput,
  });

  @override
  ConsumerState<ProductSearchBar> createState() => _ProductSearchBarState();
}

class _ProductSearchBarState extends ConsumerState<ProductSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSuggestions = false;
  int _selectedIndex = -1;
  List<ProductEntity> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _showSuggestions = false);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static final _barcodePattern = RegExp(r'^\d{4,}$');

  void _onSearchChanged(String query) {
    if (_barcodePattern.hasMatch(query)) {
      widget.onBarcodeInput?.call(query);
      _controller.clear();
      return;
    }
    ref.read(productSearchProvider.notifier).state = query;
    setState(() {
      _showSuggestions = query.isNotEmpty;
      _selectedIndex = -1;
    });
  }

  void _selectSuggestion(ProductEntity product) {
    if (!_showSuggestions) return; // guard against double-fire from onTapDown
    _controller.clear();
    ref.read(productSearchProvider.notifier).state = '';
    setState(() {
      _showSuggestions = false;
      _selectedIndex = -1;
      _suggestions = [];
    });
    widget.onProductSelected(product);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_showSuggestions || _suggestions.isEmpty) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
           event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        if (isShift) {
          final targetIndex = _selectedIndex >= 0 ? _selectedIndex : 0;
          if (targetIndex < _suggestions.length) {
            _selectSuggestion(_suggestions[targetIndex]);
          }
        } else {
          setState(() {
            if (_suggestions.length > 1) {
              _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
            } else if (_suggestions.length == 1) {
              _selectedIndex = 0;
            }
          });
        }
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (_suggestions.length > 1) {
            _selectedIndex = (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
          } else {
            _selectedIndex = 0;
          }
        });
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
          _selectSuggestion(_suggestions[_selectedIndex]);
          return KeyEventResult.handled;
        }
        if (_suggestions.isNotEmpty) {
          _selectSuggestion(_suggestions[0]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }

      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _showSuggestions = false;
          _selectedIndex = -1;
        });
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(posProductListProvider);

    // Rebuild the live suggestion list only while the dropdown is open.
    // Mutating _suggestions here (for keyboard nav) is intentional but
    // guarded to prevent overwriting the cleared state set by _selectSuggestion.
    if (_showSuggestions && productsAsync.hasValue && productsAsync.value != null) {
      final query = ref.read(productSearchProvider).toLowerCase();
      _suggestions = productsAsync.value!
          .where((p) => p.name.toLowerCase().contains(query))
          .take(8)
          .toList();
    } else if (!_showSuggestions) {
      _suggestions = [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onKeyEvent: _handleKeyEvent,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Search products by name...",
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (Platform.isIOS || Platform.isMacOS)
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        builder: (_) => BarcodeCameraOverlay(
                          onScanned: widget.onBarcodeInput,
                        ),
                      ),
                    ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                    ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF006B5E), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        if (_showSuggestions && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                // NeverScrollableScrollPhysics prevents the DragGestureRecognizer
                // from entering the arena and swallowing mouse-click tap events.
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length,
                itemBuilder: (ctx, i) {
                  final product = _suggestions[i];
                  final isSelected = i == _selectedIndex;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // onTapDown fires on pointer-down, before gesture arena
                    // resolution and before focus-change processing — reliable
                    // for desktop mouse clicks unlike onTap (pointer-up).
                    onTapDown: (_) => _selectSuggestion(product),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF006B5E).withValues(alpha: 0.08) : Colors.transparent,
                        border: i < _suggestions.length - 1
                            ? Border(bottom: BorderSide(color: Colors.grey[100]!))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              product.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? const Color(0xFF006B5E) : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _stockColor(product.stockQuantity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${product.stockQuantity}",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _stockTextColor(product.stockQuantity),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _stockColor(int qty) {
    if (qty == 0) return Colors.red[50]!;
    if (qty < 200) return Colors.orange[50]!;
    return Colors.green[50]!;
  }

  Color _stockTextColor(int qty) {
    if (qty == 0) return Colors.red[700]!;
    if (qty < 200) return Colors.orange[700]!;
    return Colors.green[700]!;
  }
}