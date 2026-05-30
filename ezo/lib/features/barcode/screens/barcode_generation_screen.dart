import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/features/inventory/products/barcode_label_generator.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:printing/printing.dart';

import 'package:share_plus/share_plus.dart';

class _SelectedItem {
  final ProductEntity product;
  String? barcode;
  String barcodeTypeKey;
  int batchQuantity;

  _SelectedItem({
    required this.product,
    this.barcode,
    this.barcodeTypeKey = 'code128',
    this.batchQuantity = 1,
  });

  String get effectiveBarcodeValue =>
      barcode ?? product.sku ?? 'ID-${product.id}';
}

class BarcodeGenerationScreen extends StatefulWidget {
  const BarcodeGenerationScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeGenerationScreen> createState() =>
      _BarcodeGenerationScreenState();
}

class _BarcodeGenerationScreenState extends State<BarcodeGenerationScreen> {
  final Color _primaryColor = const Color(0xFF2B2D5C);
  final Color _bgColor = const Color(0xFFF3F3F7);
  final Color _borderColor = const Color(0xFFE2E2E8);

  final _searchController = TextEditingController();
  final _batchQtyController = TextEditingController(text: '1');

  List<_SelectedItem> _selectedItems = [];
  List<ProductEntity> _searchResults = [];
  bool _isSearching = false;
  bool _isGenerating = false;
  Uint8List? _generatedPdfBytes;

  String _selectedBarcodeTypeKey = 'code128';
  String _selectedLayout = '30 per sheet (A4)';
  String _selectedTemplateKey = 'standard';
  final Set<String> _selectedFields = {};

  Timer? _searchTimer;

  static const List<({String label, String key})> fieldOptions = [
    (label: 'Product Name', key: 'name'),
    (label: 'SKU', key: 'sku'),
    (label: 'Price', key: 'price'),
    (label: 'Cost', key: 'cost'),
    (label: 'Stock Qty', key: 'stock'),
    (label: 'Pack Size', key: 'packSize'),
    (label: 'HSN', key: 'hsn'),
    (label: 'GST Rate', key: 'gstRate'),
    (label: 'Description', key: 'description'),
  ];

  static const List<({String label, String key})> templateOptions = [
    (label: 'Standard', key: 'standard'),
    (label: 'Compact', key: 'compact'),
    (label: 'Barcode Only', key: 'barcode_only'),
  ];

  static const List<({String label, String key})> barcodeTypes = [
    (label: 'Code 128 (Standard)', key: 'code128'),
    (label: 'EAN-13', key: 'ean13'),
    (label: 'UPC-A', key: 'upca'),
    (label: 'QR Code', key: 'qr'),
    (label: 'Data Matrix', key: 'datamatrix'),
    (label: 'Code 39', key: 'code39'),
  ];

  String get _barcodeTypeLabel => barcodeTypes
      .firstWhere((t) => t.key == _selectedBarcodeTypeKey,
          orElse: () => barcodeTypes.first)
      .label;

  int get _totalLabels =>
      _selectedItems.fold(0, (sum, i) => sum + i.batchQuantity);

  int _labelIndex(int itemIndex, int copyIndex) {
    int idx = 0;
    for (int i = 0; i < itemIndex; i++) {
      idx += _selectedItems[i].batchQuantity;
    }
    return idx + copyIndex;
  }

  bw.Barcode _mapBarcode(String key) {
    switch (key) {
      case 'ean13':
        return bw.Barcode.ean13();
      case 'upca':
        return bw.Barcode.upcA();
      case 'qr':
        return bw.Barcode.qrCode();
      case 'datamatrix':
        return bw.Barcode.dataMatrix();
      case 'code39':
        return bw.Barcode.code39();
      default:
        return bw.Barcode.code128();
    }
  }

  bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 900;

  @override
  void initState() {
    super.initState();
    _selectedFields.addAll({'name', 'price'});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _batchQtyController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // ── Product Search ────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _searchTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        final db = ServiceLocator.instance.database;
        final results = await db.getFilteredProducts(query: query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _addProduct(ProductEntity product) async {
    if (_selectedItems.any((i) => i.product.id == product.id)) return;

    final dao = ServiceLocator.instance.database.productUnitDao;
    final units = await dao.getUnitsForProduct(product.id);
    final barcode = units.isNotEmpty ? units.first.barcode : null;
    final defaultQty = int.tryParse(_batchQtyController.text) ?? 1;

    setState(() {
      _selectedItems.add(_SelectedItem(
        product: product,
        barcode: barcode,
        barcodeTypeKey: _selectedBarcodeTypeKey,
        batchQuantity: defaultQty,
      ));
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
      _generatedPdfBytes = null;
    });
  }

  void _updateBatchQty(int index, String value) {
    final qty = int.tryParse(value);
    if (qty != null && qty > 0 && index < _selectedItems.length) {
      setState(() {
        _selectedItems[index].batchQuantity = qty;
        _generatedPdfBytes = null;
      });
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void _resetForm() {
    setState(() {
      _selectedItems = [];
      _searchResults = [];
      _searchController.clear();
      _batchQtyController.text = '1';
      _generatedPdfBytes = null;
      _selectedFields.clear();
      _selectedFields.addAll({'name', 'price'});
      _selectedTemplateKey = 'standard';
      _selectedBarcodeTypeKey = 'code128';
    });
  }

  // ── Field Resolution ──────────────────────────────────────────────────────

  Map<String, String> _resolveFields(ProductEntity product) {
    final map = <String, String>{};
    for (final key in _selectedFields) {
      switch (key) {
        case 'name':
          map['Product Name'] = product.name;
        case 'sku':
          if (product.sku != null) map['SKU'] = product.sku!;
        case 'price':
          map['Price'] = 'Rs${product.price.toStringAsFixed(2)}';
        case 'cost':
          if (product.cost != null) {
            map['Cost'] = 'Rs${product.cost!.toStringAsFixed(2)}';
          }
        case 'stock':
          map['Stock'] = product.stockQuantity.toString();
        case 'packSize':
          if (product.packSize != null) map['Pack Size'] = product.packSize!;
        case 'hsn':
          if (product.hsn != null) map['HSN'] = product.hsn!;
        case 'gstRate':
          if (product.gstRate != null) map['GST Rate'] = '${product.gstRate}%';
        case 'description':
          if (product.description != null && product.description!.isNotEmpty) {
            map['Description'] = product.description!;
          }
      }
    }
    return map;
  }

  // ── PDF Generation ────────────────────────────────────────────────────────

  Future<void> _generateBarcodes() async {
    if (_selectedItems.isEmpty) return;
    setState(() => _isGenerating = true);

    try {
      final labels = _selectedItems
          .map((item) => LabelSpec(
                productName: item.product.name,
                barcodeValue: item.effectiveBarcodeValue,
                sellingPrice: null,
                quantity: item.batchQuantity,
                barcodeTypeKey: item.barcodeTypeKey,
                templateKey: _selectedTemplateKey,
                dynamicFields: _resolveFields(item.product),
              ))
          .toList();

      final pdfBytes = await generateBatchBarcodeLabels(labels: labels);
      if (mounted) {
        setState(() => _generatedPdfBytes = pdfBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barcodes generated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── Export / Print ────────────────────────────────────────────────────────

  Future<void> _printLabels() async {
    if (_generatedPdfBytes == null) {
      await _generateBarcodes();
      if (_generatedPdfBytes == null) return;
    }
    await Printing.layoutPdf(
        onLayout: (_) async => _generatedPdfBytes!);
  }

  Future<void> _downloadPdf() async {
    if (_generatedPdfBytes == null) {
      await _generateBarcodes();
      if (_generatedPdfBytes == null) return;
    }
    try {
      await Share.shareXFiles(
        [
          XFile.fromData(
            _generatedPdfBytes!,
            name: 'barcodes.pdf',
            mimeType: 'application/pdf',
          ),
        ],
        text: 'Barcode Labels',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    final buffer = StringBuffer('S.No,Product Name,Barcode,Symbology,Batch Qty\n');
    for (int i = 0; i < _selectedItems.length; i++) {
      final item = _selectedItems[i];
      buffer.writeln(
          '${i + 1},"${item.product.name}","${item.effectiveBarcodeValue}","$_barcodeTypeLabel",${item.batchQuantity}');
    }
    try {
      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'barcodes.csv',
            mimeType: 'text/csv',
          ),
        ],
        text: 'Barcode Labels CSV',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return Scaffold(
      backgroundColor: _bgColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 16.0 : 40.0,
          vertical: mobile ? 24.0 : 40.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildGenerationParameters(mobile),
            const SizedBox(height: 24),
            _buildPreviewAndManage(mobile),
            const SizedBox(height: 24),
            _buildExportSection(mobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Barcode Generation',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Generate, preview, and export barcodes for inventory items',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      ],
    );
  }

  // ── Generation Parameters ─────────────────────────────────────────────────

  Widget _buildGenerationParameters(bool mobile) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generation Parameters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (mobile) ...[
            _buildProductSearch(),
            const SizedBox(height: 16),
            _buildBarcodeTypeDropdown(),
            const SizedBox(height: 16),
            _buildBatchQtyField(),
            const SizedBox(height: 16),
            _buildLayoutDropdown(),
            const SizedBox(height: 16),
            _buildTemplateDropdown(),
          ] else ...[
            Row(
              children: [
                Expanded(flex: 3, child: _buildProductSearch()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildBarcodeTypeDropdown()),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _buildBatchQtyField()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildLayoutDropdown()),
                const SizedBox(width: 16),
                Expanded(child: _buildTemplateDropdown()),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text('Include Fields on Label (max 3)',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: fieldOptions.map((opt) {
              final selected = _selectedFields.contains(opt.key);
              return FilterChip(
                label: Text(opt.label, style: const TextStyle(fontSize: 13)),
                selected: selected,
                onSelected: (add) {
                  setState(() {
                    if (add && _selectedFields.length >= 3) return;
                    if (add) {
                      _selectedFields.add(opt.key);
                    } else {
                      _selectedFields.remove(opt.key);
                    }
                    _generatedPdfBytes = null;
                  });
                },
                backgroundColor: _bgColor,
                selectedColor: _primaryColor.withOpacity(0.1),
                checkmarkColor: _primaryColor,
                side: BorderSide(
                  color: selected ? _primaryColor : _borderColor,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _selectedItems.isEmpty ? null : _resetForm,
                child: const Text('Reset',
                    style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: (_selectedItems.isEmpty || _isGenerating)
                    ? null
                    : _generateBarcodes,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.barcode_reader, size: 18),
                label: Text(_isGenerating
                    ? 'Generating…'
                    : 'Generate Barcodes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Selection',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by name or SKU...',
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
            prefixIcon:
                const Icon(Icons.search, color: Colors.grey, size: 20),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _primaryColor),
            ),
          ),
        ),
        if (_searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, i) {
                final product = _searchResults[i];
                final alreadyAdded =
                    _selectedItems.any((s) => s.product.id == product.id);
                return ListTile(
                  dense: true,
                  title: Text(product.name,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(product.sku ?? 'No SKU',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                  trailing: alreadyAdded
                      ? const Icon(Icons.check, color: Colors.green, size: 18)
                      : const Icon(Icons.add_circle_outline,
                          color: Colors.black54, size: 18),
                  onTap: alreadyAdded ? null : () => _addProduct(product),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBarcodeTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Barcode Type',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBarcodeTypeKey,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _borderColor),
            ),
          ),
          items: barcodeTypes
              .map((t) => DropdownMenuItem(
                    value: t.key,
                    child: Text(t.label, style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedBarcodeTypeKey = val;
                _generatedPdfBytes = null;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildBatchQtyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Default Batch Qty',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: _batchQtyController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1',
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Labels per Page Layout',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedLayout,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _borderColor),
            ),
          ),
          items: ['30 per sheet (A4)', '24 per sheet (A4)']
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item, style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedLayout = val);
          },
        ),
      ],
    );
  }

  Widget _buildTemplateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Label Template',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedTemplateKey,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _borderColor),
            ),
          ),
          items: templateOptions
              .map((t) => DropdownMenuItem(
                    value: t.key,
                    child: Text(t.label, style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedTemplateKey = val;
                _generatedPdfBytes = null;
              });
            }
          },
        ),
      ],
    );
  }

  // ── Preview & Manage ──────────────────────────────────────────────────────

  Widget _buildPreviewAndManage(bool mobile) {
    return _buildCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Preview & Manage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF353945),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$_totalLabels Labels',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_selectedItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No products selected',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[500])),
                    Text('Search and select products above',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[400])),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                    const Color(0xFFFAFAFB)),
                columnSpacing: mobile ? 24 : 48,
                horizontalMargin: 20,
                dataRowHeight: 70,
                columns: const [
                  DataColumn(
                      label: Text('S.No',
                          style: TextStyle(color: Colors.grey))),
                  DataColumn(
                      label: Text('Product Name',
                          style: TextStyle(color: Colors.grey))),
                  DataColumn(
                      label: Text('Barcode',
                          style: TextStyle(color: Colors.grey))),
                  DataColumn(
                      label: Text('Symbology',
                          style: TextStyle(color: Colors.grey))),
                  DataColumn(
                      label: Text('Batch Qty',
                          style: TextStyle(color: Colors.grey))),
                  DataColumn(
                      label: Text('Preview',
                          style: TextStyle(color: Colors.grey))),
                  DataColumn(
                      label: Text('Actions',
                          style: TextStyle(color: Colors.grey))),
                ],
                rows: List.generate(_selectedItems.length,
                    (index) => _buildDataRow(index, mobile)),
              ),
            ),
          if (_selectedItems.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Showing ${_selectedItems.length} of ${_selectedItems.length} items',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabelPreview(_SelectedItem item) {
    switch (_selectedTemplateKey) {
      case 'compact':
        return SizedBox(
          width: 90,
          height: 45,
          child: bw.BarcodeWidget(
            barcode: _mapBarcode(item.barcodeTypeKey),
            data: item.effectiveBarcodeValue,
            width: 90,
            height: 45,
            drawText: false,
          ),
        );
      case 'barcode_only':
        return SizedBox(
          width: 90,
          height: 55,
          child: bw.BarcodeWidget(
            barcode: _mapBarcode(item.barcodeTypeKey),
            data: item.effectiveBarcodeValue,
            width: 90,
            height: 55,
            drawText: false,
          ),
        );
      default:
        return SizedBox(
          width: 90,
          height: 35,
          child: bw.BarcodeWidget(
            barcode: _mapBarcode(item.barcodeTypeKey),
            data: item.effectiveBarcodeValue,
            width: 90,
            height: 35,
            drawText: false,
          ),
        );
    }
  }

  DataRow _buildDataRow(int index, bool mobile) {
    final item = _selectedItems[index];
    final hasBarcode = item.effectiveBarcodeValue.isNotEmpty;
    final typeLabel = barcodeTypes
            .firstWhere((t) => t.key == item.barcodeTypeKey,
                orElse: () => barcodeTypes.first)
            .label;

    return DataRow(cells: [
      DataCell(Text('${index + 1}'.padLeft(2, '0'),
          style: const TextStyle(color: Colors.grey))),
      DataCell(SizedBox(
          width: 150,
          child: Text(item.product.name,
              style: const TextStyle(fontWeight: FontWeight.w500)))),
      DataCell(Text(item.effectiveBarcodeValue,
          style: TextStyle(
              color: hasBarcode ? null : Colors.orange,
              fontStyle: hasBarcode ? null : FontStyle.italic))),
      DataCell(Text(typeLabel)),
      DataCell(
        SizedBox(
          width: 60,
          child: TextField(
            keyboardType: TextInputType.number,
            controller: TextEditingController(
                text: item.batchQuantity.toString()),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _borderColor),
              ),
            ),
            onChanged: (value) => _updateBatchQty(index, value),
          ),
        ),
      ),
      DataCell(
        hasBarcode
            ? _buildLabelPreview(item)
            : Tooltip(
                message: 'No barcode assigned to this product',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text('No barcode',
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange[700])),
                  ],
                ),
              ),
      ),
      DataCell(
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _removeItem(index),
        ),
      ),
    ]);
  }

  // ── Export Section ────────────────────────────────────────────────────────

  Widget _buildExportSection(bool mobile) {
    return _buildCard(
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildActionButtons(mobile),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButtons(mobile),
              ],
            ),
    );
  }

  Widget _buildActionButtons(bool mobile) {
    final hasPdf = _generatedPdfBytes != null;
    final hasItems = _selectedItems.isNotEmpty;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildOutlinedBtn(
          'Export CSV',
          Icons.download_outlined,
          onPressed: hasItems ? _exportCsv : null,
        ),
        _buildDangerBtn(
          'Download PDF',
          Icons.picture_as_pdf_outlined,
          onPressed: hasPdf
              ? _downloadPdf
              : (hasItems ? _generateBarcodes : null),
        ),
        _buildPrimaryBtn(
          'Print All${hasItems ? " ($_totalLabels)" : ""}',
          Icons.print_outlined,
          onPressed: hasPdf
              ? _printLabels
              : (hasItems ? _generateBarcodes : null),
        ),
      ],
    );
  }

  // ── Shared Builder Helpers ────────────────────────────────────────────────

  Widget _buildOutlinedBtn(String text, IconData icon,
      {VoidCallback? onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: Colors.grey[700]),
      label: Text(text, style: TextStyle(color: Colors.grey[800])),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        side: BorderSide(color: _borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildDangerBtn(String text, IconData icon,
      {VoidCallback? onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: Colors.red[700]),
      label: Text(text, style: TextStyle(color: Colors.red[700])),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFCE8E8),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildPrimaryBtn(String text, IconData icon,
      {VoidCallback? onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null
            ? _primaryColor.withValues(alpha: 0.4)
            : _primaryColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildCard(
      {required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }
}
