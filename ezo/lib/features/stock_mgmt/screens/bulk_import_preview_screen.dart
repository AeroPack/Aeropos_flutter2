import 'package:flutter/material.dart';
import 'package:aeropos/core/layout/pos_design_system.dart';
import '../services/excel_import_service.dart';

class BulkImportPreviewScreen extends StatefulWidget {
  final List<ExcelImportRow> importRows;

  const BulkImportPreviewScreen({super.key, required this.importRows});

  @override
  State<BulkImportPreviewScreen> createState() =>
      _BulkImportPreviewScreenState();
}

class _BulkImportPreviewScreenState extends State<BulkImportPreviewScreen> {
  final _excelService = ExcelImportService();
  bool _isImporting = false;
  ImportResult? _importResult;

  List<ExcelImportRow> get _validRows =>
      widget.importRows.where((r) => r.isValid).toList();
  List<ExcelImportRow> get _invalidRows =>
      widget.importRows.where((r) => !r.isValid).toList();

  Future<void> _importProducts() async {
    setState(() => _isImporting = true);

    try {
      final result = await _excelService.importProducts(widget.importRows);
      setState(() => _importResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        title: const Text('Import Preview'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _importResult != null
          ? _buildResultScreen()
          : _buildPreviewScreen(),
    );
  }

  Widget _buildPreviewScreen() {
    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              _buildSummaryChip(
                'Total Rows',
                widget.importRows.length.toString(),
                PosColors.blue,
              ),
              const SizedBox(width: 12),
              _buildSummaryChip(
                'Valid',
                _validRows.length.toString(),
                Colors.green,
              ),
              const SizedBox(width: 12),
              _buildSummaryChip(
                'Invalid',
                _invalidRows.length.toString(),
                Colors.red,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _validRows.isEmpty || _isImporting
                    ? null
                    : _importProducts,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload, size: 18),
                label: Text(
                  _isImporting
                      ? 'Importing...'
                      : 'Import Valid (${_validRows.length})',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.all(PosColors.background),
                columns: const [
                  DataColumn(
                    label: Text(
                      '#',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'SKU',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Price',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Stock',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Error',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: widget.importRows.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          row.rowNumber.toString(),
                          style: const TextStyle(color: PosColors.textLight),
                        ),
                      ),
                      DataCell(
                        Icon(
                          row.isValid ? Icons.check_circle : Icons.error,
                          color: row.isValid ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                      DataCell(Text(row.data['name'] ?? '-')),
                      DataCell(Text(row.data['sku'] ?? '-')),
                      DataCell(Text(row.data['price'] ?? '-')),
                      DataCell(Text(row.data['stock_quantity'] ?? '0')),
                      DataCell(Text(row.data['category_name'] ?? '-')),
                      DataCell(
                        Text(
                          row.errorMessage ?? '-',
                          style: TextStyle(
                            color: row.isValid
                                ? PosColors.textLight
                                : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: color, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _importResult!.skipped == 0 && _importResult!.errors.isEmpty
                  ? Icons.check_circle
                  : Icons.warning,
              color:
                  _importResult!.skipped == 0 && _importResult!.errors.isEmpty
                  ? Colors.green
                  : Colors.orange,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              'Import Complete',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildResultChip(
                  'Created',
                  _importResult!.created.toString(),
                  Colors.green,
                  Icons.add_circle,
                ),
                const SizedBox(width: 16),
                _buildResultChip(
                  'Updated',
                  _importResult!.updated.toString(),
                  Colors.blue,
                  Icons.edit,
                ),
                const SizedBox(width: 16),
                _buildResultChip(
                  'Skipped',
                  _importResult!.skipped.toString(),
                  Colors.red,
                  Icons.skip_next,
                ),
              ],
            ),
            if (_importResult!.errors.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(
                  maxHeight: 200,
                  maxWidth: 500,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Errors:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._importResult!.errors
                          .take(10)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $e',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                      if (_importResult!.errors.length > 10)
                        Text(
                          '... and ${_importResult!.errors.length - 10} more',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PosColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultChip(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
