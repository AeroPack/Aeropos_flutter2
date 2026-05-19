import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:aeropos/core/layout/pos_design_system.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/customer_excel_import_service.dart';
import '../screens/bulk_import_preview_screen.dart';
import 'bulk_import_dialog_stub.dart'
    if (dart.library.html) 'bulk_import_dialog_web.dart';

class CustomerBulkImportDialog extends StatefulWidget {
  const CustomerBulkImportDialog({super.key});

  @override
  State<CustomerBulkImportDialog> createState() =>
      _CustomerBulkImportDialogState();
}

class _CustomerBulkImportDialogState extends State<CustomerBulkImportDialog> {
  final _excelService = CustomerExcelImportService();
  bool _isLoading = false;

  // Pre-generate template bytes when dialog opens (synchronous)
  List<int>? _templateBytes;
  List<int>? _templateHeadersOnlyBytes;

  @override
  void initState() {
    super.initState();
    _pregenerateTemplates();
  }

  void _pregenerateTemplates() {
    try {
      // Generate template with sample data
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Customers'];

      final headers = _excelService.templateHeaders;
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = excel_lib.TextCellValue(headers[i]);
      }

      final sampleData = _excelService.sampleData;
      for (var i = 0; i < sampleData.length; i++) {
        final cell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
        );
        cell.value = excel_lib.TextCellValue(sampleData[i]);
      }

      _templateBytes = excel.encode();

      // Generate headers-only template
      final excel2 = excel_lib.Excel.createExcel();
      final sheet2 = excel2['Customers'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet2.cell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = excel_lib.TextCellValue(headers[i]);
      }
      _templateHeadersOnlyBytes = excel2.encode();
    } catch (e) {
      // Templates will be generated on demand if this fails
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        List<int>? bytes;
        File? dartFile;

        if (file.bytes != null) {
          bytes = file.bytes;
        } else if (file.path != null) {
          dartFile = File(file.path!);
        }

        if (bytes != null || dartFile != null) {
          final rows = await _excelService.parseExcelFileData(bytes, dartFile);

          if (!mounted) return;

          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  CustomerBulkImportPreviewScreen(importRows: rows),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reading file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Use pre-generated template bytes (synchronous - preserves user gesture)
  void _downloadTemplate() {
    final bytes = _templateBytes;
    if (bytes == null || bytes.isEmpty) {
      _showTemplateInfoDialog();
      return;
    }

    _saveExcelFile(bytes, 'customer_import_template.xlsx');
  }

  Future<void> _saveExcelFile(List<int> bytes, String fileName) async {
    if (kIsWeb) {
      downloadBlobAsFile(
        bytes,
        fileName,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template downloaded!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Customer Import Template',
        text: 'Download the customer import template',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      await _saveAndDownloadTemplateFallback(bytes, fileName);
    }
  }

  Future<void> _saveAndDownloadTemplateFallback(
    List<int> bytes,
    String fileName,
  ) async {
    try {
      Directory? tempDir;
      try {
        tempDir = await getTemporaryDirectory();
      } catch (e) {
        tempDir = Directory.systemTemp;
      }

      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([
        XFile(filePath),
      ], subject: 'Customer Import Template');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template downloaded!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please restart the app and try again'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Use pre-generated headers-only template (synchronous - preserves user gesture)
  void _downloadHeaderOnlyTemplate() {
    final bytes = _templateHeadersOnlyBytes;
    if (bytes == null || bytes.isEmpty) {
      _showTemplateInfoDialog();
      return;
    }

    _saveExcelFile(bytes, 'customer_import_template_headers_only.xlsx');
  }

  void _showTemplateInfoDialog() {
    final headers = _excelService.templateHeaders;
    final sampleData = _excelService.sampleData;
    final csvContent = headers.join(',') + '\n' + sampleData.join(',');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excel Template'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Template Format (CSV):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  csvContent,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Instructions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Copy the data above'),
              const Text('2. Open Excel / Google Sheets'),
              const Text('3. Paste as CSV or create columns'),
              const Text('4. Save as .xlsx file'),
              const SizedBox(height: 16),
              const Text(
                'Or use this header row:',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              SelectableText(
                headers.join(', '),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: PosColors.textLight,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadHeaderOnlyTemplate();
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download Empty Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PosColors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PosColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.upload_file,
                    color: PosColors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk Import Customers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upload Excel file to import customers',
                        style: TextStyle(
                          color: PosColors.textLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Supported file formats:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildFileTypeChip('.xlsx', 'Excel'),
                const SizedBox(width: 8),
                _buildFileTypeChip('.xls', 'Excel'),
                const SizedBox(width: 8),
                _buildFileTypeChip('.csv', 'CSV'),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'What happens during import:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const _ImportFeatureItem(
              icon: Icons.check_circle,
              color: Colors.green,
              text: 'Updates existing customers by phone number',
            ),
            const _ImportFeatureItem(
              icon: Icons.check_circle,
              color: Colors.green,
              text: 'Creates new customers if phone not found',
            ),
            const _ImportFeatureItem(
              icon: Icons.check_circle,
              color: Colors.green,
              text: 'Skips invalid rows and shows errors',
            ),
            const _ImportFeatureItem(
              icon: Icons.check_circle,
              color: Colors.green,
              text: 'Preview before final import',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download Template'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickFile,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file, size: 18),
                    label: Text(_isLoading ? 'Loading...' : 'Choose File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PosColors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTypeChip(String extension, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PosColors.border),
      ),
      child: Text('$extension ($label)', style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ImportFeatureItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ImportFeatureItem({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

void showCustomerBulkImportDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const CustomerBulkImportDialog(),
  );
}
