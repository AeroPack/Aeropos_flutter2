import 'package:flutter/material.dart';
import 'package:aeropos/core/layout/pos_design_system.dart';
import '../services/customer_excel_import_service.dart';

class CustomerBulkImportPreviewScreen extends StatefulWidget {
  final List<CustomerExcelImportRow> importRows;

  const CustomerBulkImportPreviewScreen({super.key, required this.importRows});

  @override
  State<CustomerBulkImportPreviewScreen> createState() =>
      _CustomerBulkImportPreviewScreenState();
}

class _CustomerBulkImportPreviewScreenState
    extends State<CustomerBulkImportPreviewScreen> {
  final _excelService = CustomerExcelImportService();
  bool _isImporting = false;
  ImportResult? _importResult;

  List<CustomerExcelImportRow> get _validRows =>
      widget.importRows.where((r) => r.isValid).toList();
  List<CustomerExcelImportRow> get _invalidRows =>
      widget.importRows.where((r) => !r.isValid).toList();

  Future<void> _importCustomers() async {
    setState(() => _isImporting = true);

    try {
      final result = await _excelService.importCustomers(widget.importRows);
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
                    : _importCustomers,
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
                      'Phone',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Address',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Credit Limit',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: widget.importRows.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text(row.rowNumber.toString())),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: row.isValid
                                ? Colors.green[50]
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            row.isValid ? 'Valid' : 'Invalid',
                            style: TextStyle(
                              color: row.isValid
                                  ? Colors.green[700]
                                  : Colors.red[700],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(row.data['name'] ?? '')),
                      DataCell(Text(row.data['phone'] ?? '')),
                      DataCell(Text(row.data['email'] ?? '-')),
                      DataCell(Text(row.data['address'] ?? '-')),
                      DataCell(Text(row.data['credit_limit'] ?? '0')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (_invalidRows.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Errors (${_invalidRows.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                ..._invalidRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      row.errorMessage ?? 'Unknown error',
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResultScreen() {
    final result = _importResult!;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PosColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              result.skipped == 0 ? Icons.check_circle : Icons.warning,
              size: 64,
              color: result.skipped == 0 ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              result.skipped == 0
                  ? 'Import Successful'
                  : 'Import Completed with Errors',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildResultChip('Created', result.created, Colors.green),
                const SizedBox(width: 16),
                _buildResultChip('Updated', result.updated, Colors.blue),
                const SizedBox(width: 16),
                _buildResultChip('Skipped', result.skipped, Colors.red),
              ],
            ),
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.errors
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              e,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildSummaryChip(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: color)),
          Text(
            count,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
