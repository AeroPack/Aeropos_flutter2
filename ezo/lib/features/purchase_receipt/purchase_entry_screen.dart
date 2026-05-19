import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/layout/pos_design_system.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/viewModel/purchase_receipt_view_model.dart';

class PurchaseReceiptForm extends StatefulWidget {
  final PurchaseReceiptEntity? receiptToEdit;

  const PurchaseReceiptForm({this.receiptToEdit, super.key});

  @override
  State<PurchaseReceiptForm> createState() => _PurchaseReceiptFormState();
}

class _PurchaseReceiptFormState extends State<PurchaseReceiptForm> {
  final _purchaseViewModel = ServiceLocator.instance.purchaseReceiptViewModel;
  final _supplierViewModel = ServiceLocator.instance.supplierViewModel;
  final _productViewModel = ServiceLocator.instance.productViewModel;
  final _unitViewModel = ServiceLocator.instance.unitViewModel;

  final TextEditingController _dateController = TextEditingController(
    text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
  );
  final TextEditingController _supplierInvoiceController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _purchaseRateController = TextEditingController();

  SupplierEntity? _selectedSupplier;
  ProductEntity? _selectedProduct;
  UnitEntity? _selectedUnit;
  final List<Map<String, dynamic>> _selectedItems = [];
  bool _isSaving = false;
  bool _isEditMode = false;
  int? _editingItemIndex;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.receiptToEdit != null;
    if (_isEditMode) {
      _loadReceiptForEdit();
    }
  }

  Future<void> _loadReceiptForEdit() async {
    if (widget.receiptToEdit == null) return;

    final receipt = widget.receiptToEdit!;
    _dateController.text = DateFormat('dd/MM/yyyy').format(receipt.date);
    _supplierInvoiceController.text = receipt.supplierInvoiceNumber ?? '';

    final supplier = await _purchaseViewModel.getSupplierById(
      receipt.supplierId,
    );
    if (supplier != null && mounted) {
      setState(() => _selectedSupplier = supplier);
    }

    final items = await _purchaseViewModel.getItemsByReceiptId(receipt.id);
    if (mounted) {
      setState(() {
        _selectedItems.clear();
        for (final item in items) {
          _selectedItems.add({
            'id': item.id,
            'productId': item.productId,
            'productName': 'Product ${item.productId}',
            'quantity': item.quantity.toDouble(),
            'unitId': item.unitId,
            'unitName': 'Unit ${item.unitId}',
            'rate': item.price,
            'amount': item.totalPrice,
          });
        }
      });
    }
  }

  void _editItem(int index) {
    final item = _selectedItems[index];
    setState(() {
      _editingItemIndex = index;
      _selectedProduct = null;
      _selectedUnit = null;
      _quantityController.text = item['quantity'].toString();
      _purchaseRateController.text = item['rate'].toString();
    });
  }

  void _updateItem() {
    if (_editingItemIndex == null) return;

    final quantity = double.tryParse(_quantityController.text);
    final rate = double.tryParse(_purchaseRateController.text);

    if (_selectedProduct != null &&
        _selectedUnit != null &&
        quantity != null &&
        rate != null) {
      setState(() {
        _selectedItems[_editingItemIndex!] = {
          ..._selectedItems[_editingItemIndex!],
          'productId': _selectedProduct!.id,
          'productName': _selectedProduct!.name,
          'unitId': _selectedUnit!.id,
          'unitName': _selectedUnit!.name,
          'quantity': quantity,
          'rate': rate,
          'amount': quantity * rate,
        };
        _editingItemIndex = null;
        _quantityController.clear();
        _purchaseRateController.clear();
        _selectedProduct = null;
        _selectedUnit = null;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingItemIndex = null;
      _quantityController.clear();
      _purchaseRateController.clear();
      _selectedProduct = null;
      _selectedUnit = null;
    });
  }

  Widget _buildProductDropdown() {
    return StreamBuilder<List<ProductEntity>>(
      stream: _productViewModel.allProducts,
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];
        final currentProductId =
            _selectedItems[_editingItemIndex!]['productId'];
        final currentProduct = products
            .where((p) => p.id == currentProductId)
            .firstOrNull;

        return DropdownButtonFormField<ProductEntity>(
          initialValue: _selectedProduct ?? currentProduct,
          isDense: true,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          items: products
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.name, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedProduct = val),
        );
      },
    );
  }

  Widget _buildUnitDropdown() {
    return StreamBuilder<List<UnitEntity>>(
      stream: _unitViewModel.allUnits,
      builder: (context, snapshot) {
        final units = snapshot.data ?? [];
        final currentUnitId = _selectedItems[_editingItemIndex!]['unitId'];
        final currentUnit = units
            .where((u) => u.id == currentUnitId)
            .firstOrNull;

        return DropdownButtonFormField<UnitEntity>(
          initialValue: _selectedUnit ?? currentUnit,
          isDense: true,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          items: units
              .map(
                (u) => DropdownMenuItem(
                  value: u,
                  child: Text(u.name, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedUnit = val),
        );
      },
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _supplierInvoiceController.dispose();
    _searchController.dispose();
    _quantityController.dispose();
    _purchaseRateController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  double get _totalAmount {
    return _selectedItems.fold<double>(
      0,
      (sum, item) => sum + (item['amount'] as double),
    );
  }

  void _addProduct() {
    if (_selectedProduct == null) {
      _showSnackBar('Please select a product');
      return;
    }
    if (_selectedUnit == null) {
      _showSnackBar('Please select a unit');
      return;
    }
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showSnackBar('Please enter valid quantity');
      return;
    }
    final rate = double.tryParse(_purchaseRateController.text);
    if (rate == null || rate <= 0) {
      _showSnackBar('Please enter valid rate');
      return;
    }

    final existingIndex = _selectedItems.indexWhere(
      (item) => item['productId'] == _selectedProduct!.id,
    );
    if (existingIndex >= 0) {
      final existing = _selectedItems[existingIndex];
      final newQty = (existing['quantity'] as double) + quantity;
      final newAmount = newQty * rate;
      setState(() {
        _selectedItems[existingIndex] = {
          ...existing,
          'quantity': newQty,
          'rate': rate,
          'amount': newAmount,
        };
      });
    } else {
      setState(() {
        _selectedItems.add({
          'productId': _selectedProduct!.id,
          'productName': _selectedProduct!.name,
          'quantity': quantity,
          'unitId': _selectedUnit!.id,
          'unitName': _selectedUnit!.name,
          'rate': rate,
          'amount': quantity * rate,
        });
      });
    }

    _quantityController.clear();
    _purchaseRateController.clear();
    setState(() {
      _selectedProduct = null;
      _selectedUnit = null;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  Future<void> _savePurchase() async {
    if (_selectedSupplier == null) {
      _showSnackBar('Please select a supplier');
      return;
    }
    if (_selectedItems.isEmpty) {
      _showSnackBar('Please add at least one product');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final items = _selectedItems
          .map(
            (item) => PurchaseItemData(
              productId: item['productId'],
              quantity: item['quantity'],
              unitId: item['unitId'],
              price: item['rate'],
              totalPrice: item['amount'],
            ),
          )
          .toList();

      if (_isEditMode && widget.receiptToEdit != null) {
        await _purchaseViewModel.updatePurchaseWithItems(
          receiptId: widget.receiptToEdit!.id,
          supplierId: _selectedSupplier!.id,
          date: widget.receiptToEdit!.date,
          supplierInvoiceNumber: _supplierInvoiceController.text.isNotEmpty
              ? _supplierInvoiceController.text
              : null,
          totalAmount: _totalAmount,
          subtotal: _totalAmount,
          tax: 0,
          discount: 0,
          items: items,
        );
        _showSnackBar(
          'Purchase updated successfully! Total: ₹${_totalAmount.toStringAsFixed(2)}',
          isError: false,
        );
      } else {
        await _purchaseViewModel.createPurchaseWithItems(
          supplierId: _selectedSupplier!.id,
          date: DateTime.now(),
          supplierInvoiceNumber: _supplierInvoiceController.text.isNotEmpty
              ? _supplierInvoiceController.text
              : null,
          totalAmount: _totalAmount,
          subtotal: _totalAmount,
          items: items,
        );
        _showSnackBar(
          'Purchase saved successfully! Total: ₹${_totalAmount.toStringAsFixed(2)}',
          isError: false,
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      _showSnackBar('Error saving purchase: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSupplierSection(),
            const SizedBox(height: 24),
            _buildProductSelectionSection(),
            const SizedBox(height: 24),
            _buildSelectedProductsTable(),
            const SizedBox(height: 24),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => context.pop(),
            padding: const EdgeInsets.all(8),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: PosColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: PosColors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Purchase Receipt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Create new purchase entry',
                style: TextStyle(fontSize: 13, color: PosColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Supplier Details',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<SupplierEntity>>(
                  stream: _supplierViewModel.allSuppliers,
                  builder: (context, snapshot) {
                    final suppliers = snapshot.data ?? [];
                    return DropdownButtonFormField<SupplierEntity>(
                      decoration: InputDecoration(
                        labelText: 'Select Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      initialValue: _selectedSupplier,
                      items: suppliers
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text(s.name)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedSupplier = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _supplierInvoiceController,
                  decoration: InputDecoration(
                    labelText: 'Supplier Invoice No. (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      _dateController.text = DateFormat(
                        'dd/MM/yyyy',
                      ).format(date);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Products',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: StreamBuilder<List<ProductEntity>>(
                  stream: _productViewModel.allProducts,
                  builder: (context, snapshot) {
                    final products = snapshot.data ?? [];
                    return DropdownButtonFormField<ProductEntity>(
                      decoration: InputDecoration(
                        labelText: 'Select Product',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      initialValue: _selectedProduct,
                      items: products
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                '${p.name} (Stock: ${p.stockQuantity})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedProduct = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<List<UnitEntity>>(
                  stream: _unitViewModel.allUnits,
                  builder: (context, snapshot) {
                    final units = snapshot.data ?? [];
                    return DropdownButtonFormField<UnitEntity>(
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      initialValue: _selectedUnit,
                      items: units
                          .map(
                            (u) =>
                                DropdownMenuItem(value: u, child: Text(u.name)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedUnit = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _purchaseRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Rate',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedProductsTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selected Products',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                'Total: ₹${_totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: PosColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedItems.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No products selected',
                  style: TextStyle(color: PosColors.textLight),
                ),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(2),
                5: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: PosColors.background),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'S.No',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Product',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Unit',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Qty',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Amount',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(padding: EdgeInsets.all(12), child: Text('')),
                  ],
                ),
                ..._selectedItems.asMap().entries.map((entry) {
                  final isEditing = _editingItemIndex == entry.key;
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('${entry.key + 1}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: isEditing
                            ? _buildProductDropdown()
                            : Text(entry.value['productName']),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: isEditing
                            ? _buildUnitDropdown()
                            : Text(entry.value['unitName']),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: isEditing
                            ? SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: _quantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.all(8),
                                  ),
                                ),
                              )
                            : Text(entry.value['quantity'].toString()),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: isEditing
                            ? SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: _purchaseRateController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.all(8),
                                  ),
                                ),
                              )
                            : Text(
                                '₹${entry.value['amount'].toStringAsFixed(2)}',
                              ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isEditing) ...[
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                                size: 20,
                              ),
                              onPressed: _updateItem,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: _cancelEdit,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ] else ...[
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.blue,
                                size: 20,
                              ),
                              onPressed: () => _editItem(entry.key),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _removeItem(entry.key),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancel', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _isSaving ? null : _savePurchase,
          style: ElevatedButton.styleFrom(
            backgroundColor: PosColors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isEditMode ? 'Update Purchase' : 'Save Purchase',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}
