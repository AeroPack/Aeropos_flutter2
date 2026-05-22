import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import 'package:http/http.dart' as http;
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/profile/presentation/providers/profile_controller.dart';
import '../../features/customers/widgets/bulk_import_dialog_stub.dart'
    if (dart.library.html) '../../features/customers/widgets/bulk_import_dialog_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TableExportActions — Reusable PDF / Excel / Print widget for any data table
// ─────────────────────────────────────────────────────────────────────────────
//
// Usage:
//   TableExportActions(
//     title: 'Product List',
//     headers: ['Name', 'SKU', 'Category', 'Price'],
//     dataRows: products.map((p) => [p.name, p.sku, p.category, p.price]).toList(),
//   )
//
// This returns a Row of 3 icon buttons: PDF, Excel, Print.
// ─────────────────────────────────────────────────────────────────────────────

class TableExportActions extends ConsumerWidget {
  /// Title shown on the report header (e.g., "Product List", "Customer List")
  final String title;

  /// Column headers for the table
  final List<String> headers;

  /// Row data — each inner list must match headers length
  final List<List<String>> dataRows;

  /// Optional: spacing between buttons (default 8)
  final double spacing;

  const TableExportActions({
    super.key,
    required this.title,
    required this.headers,
    required this.dataRows,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ExportIconButton(
          icon: Icons.picture_as_pdf,
          tooltip: 'Export PDF',
          bgColor: Colors.red.shade50,
          iconColor: Colors.red,
          onTap: () => _exportPdf(context, ref),
        ),
        SizedBox(width: spacing),
        _ExportIconButton(
          icon: Icons.table_chart_outlined,
          tooltip: 'Export Excel',
          bgColor: Colors.green.shade50,
          iconColor: Colors.green,
          onTap: () => _exportExcel(context, ref),
        ),
        SizedBox(width: spacing),
        _ExportIconButton(
          icon: Icons.print,
          tooltip: 'Print',
          bgColor: Colors.grey.shade100,
          iconColor: Colors.grey.shade700,
          onTap: () => _printTable(context, ref),
        ),
      ],
    );
  }

  // ─── Company Info Helper ─────────────────────────────────────────────────

  _CompanyInfo _getCompanyInfo(WidgetRef ref) {
    final authState = ref.read(authControllerProvider);
    final profileState = ref.read(profileControllerProvider);
    final company = authState.company;
    final profile = profileState.profile;

    return _CompanyInfo(
      name: company?.businessName ?? profile?['businessName'] ?? 'Company',
      address: company?.businessAddress ?? profile?['businessAddress'] ?? '',
      phone: company?.phone ?? profile?['companyPhone'] ?? '',
      email: company?.email ?? profile?['companyEmail'] ?? '',
      taxId: company?.taxId ?? '',
      logoUrl: profile?['logoUrl'] ?? company?.logoUrl,
    );
  }

  // ─── PDF Export ──────────────────────────────────────────────────────────

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    if (dataRows.isEmpty) {
      _showSnackBar(context, 'No data to export', Colors.orange);
      return;
    }

    try {
      _showSnackBar(context, 'Generating PDF...', const Color(0xFF0058BC));

      final company = _getCompanyInfo(ref);
      final pdfBytes = await _generatePdfDocument(company);

      if (kIsWeb) {
        await _downloadPdfWeb(pdfBytes);
      } else {
        await _savePdfDesktop(pdfBytes);
      }

      if (context.mounted) {
        _showSuccessSnackBar(context, 'PDF exported successfully');
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'PDF export failed: $e', Colors.red);
      }
    }
  }

  Future<void> _savePdfDesktop(Uint8List pdfBytes) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName:
          '${title.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      final file = File(result);
      await file.writeAsBytes(pdfBytes);
    }
  }

  Future<void> _downloadPdfWeb(Uint8List pdfBytes) async {
    try {
      final fileName =
          '${title.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.pdf';
      downloadBlobAsFile(pdfBytes, fileName, 'application/pdf');
    } catch (_) {}
  }

  Future<void> _downloadExcelWeb(Uint8List bytes) async {
    try {
      final fileName =
          '${title.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.xlsx';
      downloadBlobAsFile(
        bytes,
        fileName,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (_) {}
  }

  Future<void> _saveExcelDesktop(BuildContext context, Uint8List bytes) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel',
        fileName:
            '${title.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(bytes);
      }
    } catch (_) {}
  }

  Future<Uint8List> _generatePdfDocument(_CompanyInfo company) async {
    final pdf = pw.Document();

    // Try to load company logo
    pw.ImageProvider? logoImage;
    if (company.logoUrl != null && company.logoUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(company.logoUrl!))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {
        // Logo fetch failed, proceed without
      }
    }

    // Calculate column widths
    final colCount = headers.length;
    final colWidths = <int, pw.TableColumnWidth>{};
    for (int i = 0; i < colCount; i++) {
      colWidths[i] = const pw.FlexColumnWidth();
    }

    // Chunk rows into pages (approx 30 rows per page)
    const rowsPerPage = 30;
    final chunks = <List<List<String>>>[];
    for (var i = 0; i < dataRows.length; i += rowsPerPage) {
      chunks.add(
        dataRows.sublist(
          i,
          i + rowsPerPage > dataRows.length ? dataRows.length : i + rowsPerPage,
        ),
      );
    }

    final now = DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now());

    for (int pageIdx = 0; pageIdx < chunks.length; pageIdx++) {
      final chunk = chunks[pageIdx];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── Header with logo ──────────────────────────────────────
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 48,
                        height: 48,
                        margin: const pw.EdgeInsets.only(right: 12),
                        child: pw.Image(logoImage),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            company.name,
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (company.address.isNotEmpty)
                            pw.Text(
                              company.address,
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                          if (company.phone.isNotEmpty ||
                              company.email.isNotEmpty)
                            pw.Text(
                              [
                                company.phone,
                                company.email,
                              ].where((e) => e.isNotEmpty).join(' | '),
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          title,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Generated: $now',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          'Page ${pageIdx + 1} of ${chunks.length}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 8),

                // ── Data Table ────────────────────────────────────────────
                pw.TableHelper.fromTextArray(
                  headers: headers,
                  data: chunk,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF0058BC),
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerAlignments: {
                    for (int i = 0; i < headers.length; i++)
                      i: pw.Alignment.centerLeft,
                  },
                  cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  oddRowDecoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF8F9FF),
                  ),
                  columnWidths: colWidths,
                ),

                pw.Spacer(),

                // ── Footer ────────────────────────────────────────────────
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      company.name,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      '${dataRows.length} total records',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.Text(
                      [
                        company.phone,
                        company.email,
                      ].where((e) => e.isNotEmpty).join(' | '),
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
                if (company.taxId.isNotEmpty)
                  pw.Text(
                    'Tax ID: ${company.taxId}',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey500,
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  // ─── Excel Export ────────────────────────────────────────────────────────

  Future<void> _exportExcel(BuildContext context, WidgetRef ref) async {
    if (dataRows.isEmpty) {
      _showSnackBar(context, 'No data to export', Colors.orange);
      return;
    }

    try {
      _showSnackBar(context, 'Generating Excel...', const Color(0xFF0058BC));

      final company = _getCompanyInfo(ref);
      final excel = xl.Excel.createExcel();

      // Use title as sheet name (max 31 chars for Excel)
      final sheetName = title.length > 31 ? title.substring(0, 31) : title;
      final sheet = excel[sheetName];
      // Remove default Sheet1 if different name
      if (sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      // ── Company Header Rows ───────────────────────────────────────────
      final headerStyle = xl.CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: xl.ExcelColor.fromHexString('#0F172A'),
      );
      final subHeaderStyle = xl.CellStyle(
        fontSize: 10,
        fontColorHex: xl.ExcelColor.fromHexString('#545F73'),
      );

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = xl.TextCellValue(company.name)
        ..cellStyle = headerStyle;

      if (company.address.isNotEmpty) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
          ..value = xl.TextCellValue(company.address)
          ..cellStyle = subHeaderStyle;
      }

      final contactLine = [
        company.phone,
        company.email,
      ].where((e) => e.isNotEmpty).join(' | ');
      if (contactLine.isNotEmpty) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
          ..value = xl.TextCellValue(contactLine)
          ..cellStyle = subHeaderStyle;
      }

      // Report title + date
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4))
        ..value = xl.TextCellValue(title)
        ..cellStyle = xl.CellStyle(
          bold: true,
          fontSize: 12,
          fontColorHex: xl.ExcelColor.fromHexString('#0058BC'),
        );

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5))
        ..value = xl.TextCellValue(
          'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
        )
        ..cellStyle = subHeaderStyle;

      // ── Column Headers (Row 7) ────────────────────────────────────────
      const headerRowIndex = 7;
      final colHeaderStyle = xl.CellStyle(
        bold: true,
        fontSize: 10,
        backgroundColorHex: xl.ExcelColor.fromHexString('#0058BC'),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      );

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(
            xl.CellIndex.indexByColumnRow(
              columnIndex: i,
              rowIndex: headerRowIndex,
            ),
          )
          ..value = xl.TextCellValue(headers[i])
          ..cellStyle = colHeaderStyle;
      }

      // ── Data Rows ─────────────────────────────────────────────────────
      final dataStyle = xl.CellStyle(fontSize: 10);
      final altDataStyle = xl.CellStyle(
        fontSize: 10,
        backgroundColorHex: xl.ExcelColor.fromHexString('#F8F9FF'),
      );

      for (int rowIdx = 0; rowIdx < dataRows.length; rowIdx++) {
        final row = dataRows[rowIdx];
        final style = rowIdx.isEven ? dataStyle : altDataStyle;
        for (int colIdx = 0; colIdx < row.length; colIdx++) {
          sheet.cell(
              xl.CellIndex.indexByColumnRow(
                columnIndex: colIdx,
                rowIndex: headerRowIndex + 1 + rowIdx,
              ),
            )
            ..value = xl.TextCellValue(row[colIdx])
            ..cellStyle = style;
        }
      }

      // ── Footer row ────────────────────────────────────────────────────
      final footerRow = headerRowIndex + 1 + dataRows.length + 1;
      sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: footerRow),
        )
        ..value = xl.TextCellValue('Total Records: ${dataRows.length}')
        ..cellStyle = xl.CellStyle(bold: true, fontSize: 10);

      // ── Auto-size columns (approximate) ───────────────────────────────
      for (int i = 0; i < headers.length; i++) {
        int maxLen = headers[i].length;
        for (final row in dataRows) {
          if (i < row.length && row[i].length > maxLen) {
            maxLen = row[i].length;
          }
        }
        sheet.setColumnWidth(i, (maxLen * 1.3).clamp(10, 50).toDouble());
      }

      // ── Save ──────────────────────────────────────────────────────────
      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final uint8Bytes = Uint8List.fromList(bytes);

      if (kIsWeb) {
        await _downloadExcelWeb(uint8Bytes);
      } else {
        await _saveExcelDesktop(context, uint8Bytes);
      }

      if (context.mounted) {
        _showSuccessSnackBar(
          context,
          'Excel exported (${dataRows.length} records)',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Excel export failed: $e', Colors.red);
      }
    }
  }

  // ─── Print ──────────────────────────────────────────────────────────────

  Future<void> _printTable(BuildContext context, WidgetRef ref) async {
    if (dataRows.isEmpty) {
      _showSnackBar(context, 'No data to print', Colors.orange);
      return;
    }

    try {
      final company = _getCompanyInfo(ref);
      final pdfBytes = await _generatePdfDocument(company);

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: '$title - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      );
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Print failed: $e', Colors.red);
      }
    }
  }

  // ─── Snackbar Helpers ───────────────────────────────────────────────────

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF00875A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Export Icon Button (internal reusable)
// ─────────────────────────────────────────────────────────────────────────────

class _ExportIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ExportIconButton({
    required this.icon,
    required this.tooltip,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Company info data class (internal)
// ─────────────────────────────────────────────────────────────────────────────

class _CompanyInfo {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String taxId;
  final String? logoUrl;

  const _CompanyInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.taxId,
    this.logoUrl,
  });
}
