import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class PharmacyWholesaleA5Template extends InvoiceTemplate {
  @override
  String get id => 'pharmacy_wholesale_01';
  @override
  String get name => 'Pharmacy Wholesale Bill';
  @override
  String get industry => 'PHARMACY';
  @override
  String get format => 'A5';
  @override
  String get styleName => 'PROFESSIONAL';
  @override
  String get previewImagePath => 'assets/preview_templates/pharmacy_a5_template.png';

  @override
  Color get badgeColor => const Color(0xFF008080); // Teal matching the image
  @override
  String get metadata => 'A5 grid-heavy pharmaceutical invoice';
  @override
  String? get tag => 'MEDICAL';

  // Helper colors
  final PdfColor _borderColor = PdfColors.black;
  final PdfColor _headerBgColor = const PdfColor.fromInt(0xFF008080); // Teal

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();

    // Height halved to 55mm to eliminate blank space at the bottom.
    final customFormat = PdfPageFormat(
      PdfPageFormat.a5.landscape.width,
      55 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: customFormat,
        margin: const pw.EdgeInsets.all(12),
        build: (context) {
          return wrapWithFont(
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderColor, width: 1.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // --- HEADER SECTION ---
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Seller Details (Left)
                      pw.Expanded(
                        flex: 38,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: _borderColor, width: 1)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                data.businessName,
                                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('Ph. : ${data.businessPhone} Email : ${data.businessEmail}', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('GSTIN : ${data.gstin}', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('DL No. : 20C VAD 94560, 20D VAD 93441', style: const pw.TextStyle(fontSize: 9)), // Static for now, typically mapped to data
                            ],
                          ),
                        ),
                      ),
                      // Buyer Details (Center)
                      pw.Expanded(
                        flex: 38,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: _borderColor, width: 1)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("Buyer's Detail", style: const pw.TextStyle(fontSize: 9)),
                              pw.Text(data.clientName.toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('Ph No.: ${data.clientPhone}', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('GSTIN : ${data.clientGstin}', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('DL No. : ', style: const pw.TextStyle(fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                      // Invoice Details (Right)
                      pw.Expanded(
                        flex: 24,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 4),
                              color: _headerBgColor,
                              alignment: pw.Alignment.center,
                              child: pw.Text('INVOICE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 1))),
                              child: pw.Column(
                                children: [
                                  _pdfKeyValue('Invoice No.', ': ${data.invoiceNumber.isNotEmpty ? data.invoiceNumber : "INV-001"}'),
                                  _pdfKeyValue('Date', ': ${data.invoiceDate.day}-${data.invoiceDate.month}-${data.invoiceDate.year}'),
                                  _pdfKeyValue('Due Date', ': ${data.invoiceDate.day}-${data.invoiceDate.month}-${data.invoiceDate.year}'),
                                  _pdfKeyValue('Ref. No.', ': N/A'),
                                  _pdfKeyValue('Note', ': Remarks'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // --- ITEMS TABLE SECTION ---
                  pw.Table(
                    border: pw.TableBorder.symmetric(
                      inside: pw.BorderSide(color: _borderColor, width: 0.5),
                      outside: pw.BorderSide(color: _borderColor, width: 1),
                    ),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(3), // Sr
                      1: pw.FlexColumnWidth(8), // HSN Code
                      2: pw.FlexColumnWidth(20), // Description
                      3: pw.FlexColumnWidth(8), // Pack
                      4: pw.FlexColumnWidth(5), // Mfr
                      5: pw.FlexColumnWidth(8), // Batch No
                      6: pw.FlexColumnWidth(8), // Exp Dt
                      7: pw.FlexColumnWidth(5), // Qty
                      8: pw.FlexColumnWidth(5), // Free
                      9: pw.FlexColumnWidth(6), // MRP
                      10: pw.FlexColumnWidth(7), // Rate
                      11: pw.FlexColumnWidth(5), // Dis%
                      12: pw.FlexColumnWidth(5), // GST%
                      13: pw.FlexColumnWidth(10), // Amount
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: _headerBgColor),
                        children: [
                          _pdfTh('Sr.'),
                          _pdfTh('HSN Code'),
                          _pdfTh('Description'),
                          _pdfTh('Pack'),
                          _pdfTh('Mfr'),
                          _pdfTh('Batch No.'),
                          _pdfTh('Exp Dt'),
                          _pdfTh('Qty'),
                          _pdfTh('Free'),
                          _pdfTh('MRP'),
                          _pdfTh('Rate'),
                          _pdfTh('Dis%'),
                          _pdfTh('GST%'),
                          _pdfTh('Amount'),
                        ],
                      ),
                      // Data Rows
                      ...data.items.asMap().entries.map((e) {
                        final i = e.key;
                        final item = e.value;
                        return pw.TableRow(
                          children: [
                            _pdfTd('${i + 1}', align: pw.TextAlign.center),
                            _pdfTd(item.hsnCode.isNotEmpty ? item.hsnCode : '—'), // HSN from item
                            _pdfTd(item.desc),
                            _pdfTd('100 ml', align: pw.TextAlign.center), // Placeholder Pack
                            _pdfTd('WS', align: pw.TextAlign.center), // Placeholder Mfr
                            _pdfTd('B-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}', align: pw.TextAlign.center),
                            _pdfTd('12-2026', align: pw.TextAlign.center),
                            _pdfTd(item.qty.toString(), align: pw.TextAlign.center),
                            _pdfTd('0', align: pw.TextAlign.center),
                            _pdfTd((item.rate * 1.1).toStringAsFixed(0), align: pw.TextAlign.center), // Dummy MRP
                            _pdfTd(item.rate.toStringAsFixed(2), align: pw.TextAlign.right),
                            _pdfTd('0', align: pw.TextAlign.center),
                            _pdfTd('${data.taxRate}', align: pw.TextAlign.center),
                            _pdfTd(item.amount.toStringAsFixed(2), align: pw.TextAlign.right),
                          ],
                        );
                      }),
                      // Spacer tightened
                      pw.TableRow(children: [pw.Container(height: 4)]),
                    ],
                  ),

                  // --- FOOTER SECTION ---
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Left Footer (Bank Details & Terms)
                      pw.Expanded(
                        flex: 38,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(
                              top: pw.BorderSide(color: _borderColor, width: 1),
                              right: pw.BorderSide(color: _borderColor, width: 1),
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (data.showBankDetails && data.bankName.isNotEmpty) ...[
                                pw.Text('Bank Details :', style: const pw.TextStyle(fontSize: 9)),
                                pw.Text(data.bankName, style: const pw.TextStyle(fontSize: 9)),
                                pw.Text('Ac. No. : ${data.bankAccountNo} IFSC Code : ${data.bankIfsc}', style: const pw.TextStyle(fontSize: 9)),
                              ],
                              pw.SizedBox(height: 6),
                              pw.Text('Terms & Conditions :', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text(data.notes.isNotEmpty ? data.notes : 'Subject to Jurisdiction.\nAdvance Payment before Delivery.', style: const pw.TextStyle(fontSize: 8)),
                            ],
                          ),
                        ),
                      ),
                      // Middle Footer (Tax Summary & Auth)
                      pw.Expanded(
                        flex: 38,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(
                              top: pw.BorderSide(color: _borderColor, width: 1),
                              right: pw.BorderSide(color: _borderColor, width: 1),
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              // Mini Tax Table
                              pw.Table(
                                children: [
                                  pw.TableRow(
                                    children: [
                                      pw.Text('GST %', style: const pw.TextStyle(fontSize: 8)),
                                      pw.Text('Taxable Amt', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                                      pw.Text('SGST Amt.', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                                      pw.Text('CGST Amt.', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                                      pw.Text('Tax Amt.', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                                    ],
                                  ),
                                  pw.TableRow(
                                    children: [
                                      pw.Text('${data.taxRate}%', style: const pw.TextStyle(fontSize: 8)),
                                      pw.Text(data.subtotal.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                                      pw.Text((data.taxAmount / 2).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                                      pw.Text((data.taxAmount / 2).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                                      pw.Text(data.taxAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                                    ],
                                  ),
                                ],
                              ),
                              // Auth text
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text('For ${data.businessName}', style: const pw.TextStyle(fontSize: 9)),
                                  pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                                    children: [
                                      pw.Text('Page 1 of 1', style: const pw.TextStyle(fontSize: 8)),
                                      pw.Text('Total Qty : ${data.items.fold(0.0, (sum, item) => sum + item.qty).toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right Footer (Totals)
                      pw.Expanded(
                        flex: 24,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 1)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: [
                              _pdfSummaryRow('Sub Total', ':', data.subtotal.toStringAsFixed(2)),
                              _pdfSummaryRow('Discount', ':', '0.00'),
                              _pdfSummaryRow('CGST', ':', (data.taxAmount / 2).toStringAsFixed(2)),
                              _pdfSummaryRow('SGST', ':', (data.taxAmount / 2).toStringAsFixed(2)),
                              _pdfSummaryRow('(-) Round Off', '', '0.00'),
                              pw.SizedBox(height: 8),
                              _pdfSummaryRow('Net Amount', ':', data.total.toStringAsFixed(2), isBold: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            data,
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _pdfKeyValue(String key, String value) {
    return pw.Row(
      children: [
        pw.Expanded(flex: 4, child: pw.Text(key, style: const pw.TextStyle(fontSize: 9))),
        pw.Expanded(flex: 6, child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
      ],
    );
  }

  pw.Widget _pdfTh(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      alignment: pw.Alignment.center,
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
    );
  }

  pw.Widget _pdfTd(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : (align == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
    );
  }

  pw.Widget _pdfSummaryRow(String label, String separator, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 5, child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Expanded(flex: 1, child: pw.Text(separator, style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 4, child: pw.Text(value, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        ],
      ),
    );
  }

  // --- FLUTTER PREVIEW ---

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    final borderColor = Colors.black;
    final headerBgColor = const Color(0xFF008080); // Teal matching image

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min, // Automatically wraps to exact height in UI
          children: [
            // --- HEADER SECTION ---
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Seller Details
                  Expanded(
                    flex: 38,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data.businessName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(data.businessAddress, style: const TextStyle(fontSize: 9)),
                          Text('Ph. : ${data.businessPhone} Email : ${data.businessEmail}', style: const TextStyle(fontSize: 9)),
                          Text('GSTIN : ${data.gstin}', style: const TextStyle(fontSize: 9)),
                          const Text('DL No. : 20C VAD 94560, 20D VAD 93441', style: TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                  // Buyer Details
                  Expanded(
                    flex: 38,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Buyer's Detail", style: TextStyle(fontSize: 9)),
                          Text(data.clientName.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(data.clientAddress, style: const TextStyle(fontSize: 9)),
                          Text('Ph No.: ${data.clientPhone}', style: const TextStyle(fontSize: 9)),
                          Text('GSTIN : ${data.clientGstin}', style: const TextStyle(fontSize: 9)),
                          const Text('DL No. : ', style: TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                  // Invoice Details
                  Expanded(
                    flex: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: headerBgColor,
                          alignment: Alignment.center,
                          child: const Text('INVOICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor, width: 1))),
                          child: Column(
                            children: [
                              _flutterKeyValue('Invoice No.', ': ${data.invoiceNumber.isNotEmpty ? data.invoiceNumber : "INV-001"}'),
                              _flutterKeyValue('Date', ': ${data.invoiceDate.day}-${data.invoiceDate.month}-${data.invoiceDate.year}'),
                              _flutterKeyValue('Due Date', ': ${data.invoiceDate.day}-${data.invoiceDate.month}-${data.invoiceDate.year}'),
                              _flutterKeyValue('Ref. No.', ': N/A'),
                              _flutterKeyValue('Note', ': Remarks'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- ITEMS TABLE SECTION ---
            Table(
              border: TableBorder.symmetric(
                inside: BorderSide(color: borderColor, width: 0.5),
                outside: BorderSide(color: borderColor, width: 1),
              ),
              columnWidths: const {
                0: FlexColumnWidth(3), // Sr
                1: FlexColumnWidth(8), // HSN Code
                2: FlexColumnWidth(20), // Description
                3: FlexColumnWidth(8), // Pack
                4: FlexColumnWidth(5), // Mfr
                5: FlexColumnWidth(8), // Batch No
                6: FlexColumnWidth(8), // Exp Dt
                7: FlexColumnWidth(5), // Qty
                8: FlexColumnWidth(5), // Free
                9: FlexColumnWidth(6), // MRP
                10: FlexColumnWidth(7), // Rate
                11: FlexColumnWidth(5), // Dis%
                12: FlexColumnWidth(5), // GST%
                13: FlexColumnWidth(10), // Amount
              },
              children: [
                // Header
                TableRow(
                  decoration: BoxDecoration(color: headerBgColor),
                  children: [
                    _flutterTh('Sr.'),
                    _flutterTh('HSN Code'),
                    _flutterTh('Description'),
                    _flutterTh('Pack'),
                    _flutterTh('Mfr'),
                    _flutterTh('Batch No.'),
                    _flutterTh('Exp Dt'),
                    _flutterTh('Qty'),
                    _flutterTh('Free'),
                    _flutterTh('MRP'),
                    _flutterTh('Rate'),
                    _flutterTh('Dis%'),
                    _flutterTh('GST%'),
                    _flutterTh('Amount'),
                  ],
                ),
                // Data
                ...data.items.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  return TableRow(
                    children: [
                      _flutterTd('${i + 1}', align: TextAlign.center),
                      _flutterTd(item.hsnCode.isNotEmpty ? item.hsnCode : '—'),
                      _flutterTd(item.desc),
                      _flutterTd('100 ml', align: TextAlign.center),
                      _flutterTd('WS', align: TextAlign.center),
                      _flutterTd('B-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}', align: TextAlign.center),
                      _flutterTd('12-2026', align: TextAlign.center),
                      _flutterTd(item.qty.toString(), align: TextAlign.center),
                      _flutterTd('0', align: TextAlign.center),
                      _flutterTd((item.rate * 1.1).toStringAsFixed(0), align: TextAlign.center),
                      _flutterTd(item.rate.toStringAsFixed(2), align: TextAlign.right),
                      _flutterTd('0', align: TextAlign.center),
                      _flutterTd('${data.taxRate}', align: TextAlign.center),
                      _flutterTd(item.amount.toStringAsFixed(2), align: TextAlign.right),
                    ],
                  );
                }),
                // Spacer Row
                TableRow(
                  children: List.generate(14, (index) => Container(height: 4)),
                ),
              ],
            ),

            // --- FOOTER SECTION ---
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left
                  Expanded(
                    flex: 38,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: borderColor, width: 1),
                          right: BorderSide(color: borderColor, width: 1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bank Details :', style: TextStyle(fontSize: 9)),
                          Text(data.bankName.isNotEmpty ? data.bankName : 'Bank Name', style: const TextStyle(fontSize: 9)),
                          Text('Ac. No. : ${data.bankAccountNo.isNotEmpty ? data.bankAccountNo : "—"} IFSC Code : ${data.bankIfsc.isNotEmpty ? data.bankIfsc : "—"}', style: const TextStyle(fontSize: 9)),
                          const SizedBox(height: 6),
                          const Text('Terms & Conditions :', style: TextStyle(fontSize: 9)),
                          Text(data.notes.isNotEmpty ? data.notes : 'Subject to Jurisdiction.\nAdvance Payment before Delivery.', style: const TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                  ),
                  // Center
                  Expanded(
                    flex: 38,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: borderColor, width: 1),
                          right: BorderSide(color: borderColor, width: 1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Table(
                            children: [
                              const TableRow(
                                children: [
                                  Text('GST %', style: TextStyle(fontSize: 8)),
                                  Text('Taxable Amt', style: TextStyle(fontSize: 8), textAlign: TextAlign.right),
                                  Text('SGST Amt.', style: TextStyle(fontSize: 8), textAlign: TextAlign.right),
                                  Text('CGST Amt.', style: TextStyle(fontSize: 8), textAlign: TextAlign.right),
                                  Text('Tax Amt.', style: TextStyle(fontSize: 8), textAlign: TextAlign.right),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Text('${data.taxRate}%', style: const TextStyle(fontSize: 8)),
                                  Text(data.subtotal.toStringAsFixed(2), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right),
                                  Text((data.taxAmount / 2).toStringAsFixed(2), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right),
                                  Text((data.taxAmount / 2).toStringAsFixed(2), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right),
                                  Text(data.taxAmount.toStringAsFixed(2), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('For ${data.businessName}', style: const TextStyle(fontSize: 9)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Page 1 of 1', style: TextStyle(fontSize: 8)),
                                  Text('Total Qty : ${data.items.fold(0.0, (sum, item) => sum + item.qty).toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right
                  Expanded(
                    flex: 24,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _flutterSummaryRow('Sub Total', ':', data.subtotal.toStringAsFixed(2)),
                          _flutterSummaryRow('Discount', ':', '0.00'),
                          _flutterSummaryRow('CGST', ':', (data.taxAmount / 2).toStringAsFixed(2)),
                          _flutterSummaryRow('SGST', ':', (data.taxAmount / 2).toStringAsFixed(2)),
                          _flutterSummaryRow('(-) Round Off', '', '0.00'),
                          const SizedBox(height: 8),
                          _flutterSummaryRow('Net Amount', ':', data.total.toStringAsFixed(2), isBold: true),
                        ],
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

  Widget _flutterKeyValue(String key, String value) {
    return Row(
      children: [
        Expanded(flex: 4, child: Text(key, style: const TextStyle(fontSize: 9))),
        Expanded(flex: 6, child: Text(value, style: const TextStyle(fontSize: 9))),
      ],
    );
  }

  Widget _flutterTh(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _flutterTd(String text, {TextAlign align = TextAlign.left}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      alignment: align == TextAlign.center
          ? Alignment.center
          : (align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft),
      child: Text(text, style: const TextStyle(fontSize: 8)),
    );
  }

  Widget _flutterSummaryRow(String label, String separator, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(label, style: TextStyle(fontSize: 9, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Expanded(flex: 1, child: Text(separator, style: const TextStyle(fontSize: 9))),
          Expanded(flex: 4, child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Jeqline Pharmacy',
      businessEmail: 'jeqline@gmail.com',
      businessPhone: '9727955514',
      businessAddress: 'Sakar-1, Near Mani Ratnam Complex,\nMG Road, Opp. Hanuman Temple, Vadodara.',
      gstin: '24AKPPP1343N1ZR',
      clientName: 'DR. VIJAT BHATT G',
      clientAddress: 'Virat Lane, 45-ANC/Block 45, Building No. 34, Roshni\nLane, Opp. Circuit House Vadodara Gujarat',
      clientPhone: '0265123456989',
      taxLabel: 'GST',
      taxRate: 5,
      themeColorArgb: const Color(0xFF008080).toARGB32(), // Teal
      fontFamily: 'Roboto',
      items: [
        InvoiceItem(id: '1', desc: 'Belladonna 30', details: '', qty: 10, rate: 157.14),
        InvoiceItem(id: '2', desc: 'Belladonna 30', details: '', qty: 1, rate: 157.14),
        InvoiceItem(id: '3', desc: 'Belladonna 30', details: '', qty: 100, rate: 157.14),
        InvoiceItem(id: '4', desc: '1/2 dram plastic', details: '', qty: 5, rate: 180),
      ],
      notes: 'Subject to Vadodara Jurisdiction\nAdvance Payment before Delivery.',
      isThermal: false,
    );
  }
}