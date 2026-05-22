import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class BusinessDeliveryChallanTemplate extends InvoiceTemplate {
  @override
  String get id => 'business_delivery_challan_01';
  @override
  String get name => 'Delivery Challan Standard';
  @override
  String get industry => 'BUSINESS';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'PROFESSIONAL';
  @override
  String get previewImagePath =>
      'assets/preview_templates/delivery_challan_template.png';
  @override
  Color get badgeColor => const Color(0xFF4B3CDB); // Indigo/Purple shade from image
  @override
  String get metadata => 'Quantity-focused Delivery Challan';
  @override
  String? get tag => 'CHALLAN';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();
    final accent = PdfColor.fromInt(data.themeColorArgb);
    final borderColor = PdfColors.black;

    // Calculate total quantity
    final totalQty = data.items.fold(0.0, (sum, item) => sum + item.qty);

    pw.MemoryImage? logoImage;
    if (data.showLogo && data.logoBytes != null) {
      logoImage = pw.MemoryImage(data.logoBytes!);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return wrapWithFont(
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // 1. Header
                  pw.Container(
                    color: accent,
                    padding: const pw.EdgeInsets.symmetric(vertical: 12),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'Delivery Challan',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),

                  // 2. Company Info & Logo
                  pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Expanded(
                          flex: 6,
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                right: pw.BorderSide(color: borderColor, width: 1),
                                bottom: pw.BorderSide(color: borderColor, width: 1),
                              ),
                            ),
                            child: pw.Column(
                              children: [
                                _pdfInfoRow('Company Name:', data.businessName, borderColor),
                                _pdfInfoRow('Address:', data.businessAddress, borderColor),
                                pw.Container(height: 14, decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)))),
                                _pdfInfoRow('Phone No:', data.businessPhone, borderColor),
                                _pdfInfoRow('Email ID:', data.businessEmail, borderColor),
                                _pdfInfoRow('GSTIN:', data.gstin, borderColor, isLast: true),
                              ],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Company Logo:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 8),
                                if (data.showLogo && logoImage != null)
                                  pw.Expanded(
                                    child: pw.Center(child: pw.Image(logoImage, fit: pw.BoxFit.contain)),
                                  )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Thick Divider matching image
                  pw.Container(height: 6, color: accent),
                  pw.Container(height: 1, color: borderColor),

                  // 3. Bill To & Ship To
                  pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Expanded(
                          flex: 1,
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                right: pw.BorderSide(color: borderColor, width: 1),
                                bottom: pw.BorderSide(color: borderColor, width: 1),
                              ),
                            ),
                            child: pw.Column(
                              children: [
                                _pdfHeaderRow('Delivery Challan For:', borderColor),
                                _pdfInfoRow('Party Name:', data.clientName, borderColor),
                                _pdfInfoRow('Address:', data.clientAddress, borderColor),
                                pw.Container(height: 14, decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)))),
                                _pdfInfoRow('Phone No:', data.clientPhone, borderColor),
                                _pdfInfoRow('Email:', '', borderColor),
                                _pdfInfoRow('GSTIN:', '', borderColor),
                                pw.Container(height: 14, decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)))),
                                _pdfInfoRow('Challan No:', data.invoiceNumber.isNotEmpty ? data.invoiceNumber : 'DC-001', borderColor),
                                _pdfInfoRow('Date:', '${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', borderColor, isLast: true),
                              ],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)),
                            ),
                            child: pw.Column(
                              children: [
                                _pdfHeaderRow('Shipping To:', borderColor),
                                _pdfInfoRow('Shipping Name:', data.clientName, borderColor),
                                _pdfInfoRow('Address:', data.clientAddress, borderColor),
                                pw.Container(height: 14, decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)))),
                                _pdfInfoRow('Phone No:', data.clientPhone, borderColor),
                                _pdfInfoRow('Email:', '', borderColor),
                                _pdfInfoRow('GSTIN:', '', borderColor),
                                pw.Container(height: 14, decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)))),
                                _pdfInfoRow('Order Ref:', 'PO-N/A', borderColor),
                                _pdfInfoRow('Date:', '${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', borderColor, isLast: true),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                  // 4. Thick Divider matching image
                  pw.Container(height: 6, color: accent),
                  pw.Container(height: 1, color: borderColor),

                  // 5. Items Table
                  pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: 1),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(1),
                      1: pw.FlexColumnWidth(4),
                      2: pw.FlexColumnWidth(2),
                      3: pw.FlexColumnWidth(2),
                      4: pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _pdfTh('Sl No.'),
                          _pdfTh('Item Name'),
                          _pdfTh('HSN/SAC\nCode'),
                          _pdfTh('Quantity'),
                          _pdfTh('Unit'),
                        ],
                      ),
                      ...data.items.asMap().entries.map((e) {
                        final idx = e.key + 1;
                        final item = e.value;
                        return pw.TableRow(
                          children: [
                            _pdfTd(idx.toString(), align: pw.TextAlign.center),
                            _pdfTd(item.desc),
                            _pdfTd(' ', align: pw.TextAlign.center), // Placeholder for HSN
                            _pdfTd(item.qty.toString(), align: pw.TextAlign.center),
                            _pdfTd('PCS', align: pw.TextAlign.center),
                          ],
                        );
                      }),
                      // Add empty rows to match visual weight
                      if (data.items.length < 5)
                        ...List.generate(
                          5 - data.items.length,
                          (_) => pw.TableRow(
                            children: List.generate(5, (_) => _pdfTd(' ', height: 20)),
                          ),
                        ),
                    ],
                  ),

                  // 6. Total Row (Custom spanning)
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      color: accent,
                      border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 7, // Sl No (1) + Item Name (4) + HSN (2) = 7
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            alignment: pw.Alignment.center,
                            child: pw.Text('Total', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2, // Quantity (2)
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            alignment: pw.Alignment.center,
                            decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: borderColor, width: 1))),
                            child: pw.Text(totalQty.toString(), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2, // Unit (2)
                          child: pw.Container(
                            decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: borderColor, width: 1))),
                            child: pw.Text(''),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 7. Terms & Signature
                  pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Expanded(
                          flex: 6,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                right: pw.BorderSide(color: borderColor, width: 1),
                                bottom: pw.BorderSide(color: borderColor, width: 1),
                              ),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Terms & Conditions', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 4),
                                pw.Text(data.notes.isEmpty ? '1. Goods received in good condition.\n2. Subject to local jurisdiction.' : data.notes, style: const pw.TextStyle(fontSize: 8)),
                              ],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text('For, ${data.businessName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                ),
                                pw.SizedBox(height: 30),
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(4),
                                  decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5))),
                                  child: pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                  // 8. Received By Blocks
                  _pdfReceivedBlock(borderColor),
                  _pdfReceivedBlock(borderColor, isLast: true),
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

  pw.Widget _pdfInfoRow(String label, String value, PdfColor border, {bool isLast = false}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: isLast ? null : pw.Border(bottom: pw.BorderSide(color: border, width: 1)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: border, width: 1)),
              ),
              child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
          ),
          pw.Expanded(
            flex: 6,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfHeaderRow(String text, PdfColor border) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: pw.Alignment.centerLeft,
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: border, width: 1)),
      ),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _pdfTh(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      alignment: pw.Alignment.center,
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
    );
  }

  pw.Widget _pdfTd(String text, {pw.TextAlign align = pw.TextAlign.left, double? height}) {
    return pw.Container(
      height: height,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : (align == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  pw.Widget _pdfReceivedBlock(PdfColor border, {bool isLast = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: isLast ? null : pw.Border(bottom: pw.BorderSide(color: border, width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Received By', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Name:', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 2),
          pw.Text('Comment:', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 2),
          pw.Text('Date:', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 2),
          pw.Text('Signature:', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    final accent = Color(data.themeColorArgb);
    const borderColor = Colors.black;
    final totalQty = data.items.fold(0.0, (sum, item) => sum + item.qty);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            Container(
              color: accent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: const Text(
                'Delivery Challan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // 2. Company Info & Logo
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: borderColor, width: 1),
                          bottom: BorderSide(color: borderColor, width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          _flutterInfoRow('Company Name:', data.businessName),
                          _flutterInfoRow('Address:', data.businessAddress),
                          Container(height: 14, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: borderColor, width: 1)))),
                          _flutterInfoRow('Phone No:', data.businessPhone),
                          _flutterInfoRow('Email ID:', data.businessEmail),
                          _flutterInfoRow('GSTIN:', data.gstin, isLast: true),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Company Logo:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                          SizedBox(height: 8),
                          Expanded(
                            child: Center(
                              child: Icon(Icons.business, color: Colors.grey, size: 40),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Thick Divider
            Container(height: 6, color: accent),
            Container(height: 1, color: borderColor),

            // 3. Bill To & Ship To
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: borderColor, width: 1),
                          bottom: BorderSide(color: borderColor, width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          _flutterHeaderRow('Delivery Challan For:'),
                          _flutterInfoRow('Party Name:', data.clientName),
                          _flutterInfoRow('Address:', data.clientAddress),
                          Container(height: 14, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: borderColor, width: 1)))),
                          _flutterInfoRow('Phone No:', data.clientPhone),
                          _flutterInfoRow('Email:', ''),
                          _flutterInfoRow('GSTIN:', ''),
                          Container(height: 14, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: borderColor, width: 1)))),
                          _flutterInfoRow('Challan No:', data.invoiceNumber.isNotEmpty ? data.invoiceNumber : 'DC-001'),
                          _flutterInfoRow('Date:', '${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', isLast: true),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: Column(
                        children: [
                          _flutterHeaderRow('Shipping To:'),
                          _flutterInfoRow('Shipping Name:', data.clientName),
                          _flutterInfoRow('Address:', data.clientAddress),
                          Container(height: 14, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: borderColor, width: 1)))),
                          _flutterInfoRow('Phone No:', data.clientPhone),
                          _flutterInfoRow('Email:', ''),
                          _flutterInfoRow('GSTIN:', ''),
                          Container(height: 14, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: borderColor, width: 1)))),
                          _flutterInfoRow('Order Ref:', 'PO-N/A'),
                          _flutterInfoRow('Date:', '${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', isLast: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Thick Divider
            Container(height: 6, color: accent),
            Container(height: 1, color: borderColor),

            // 4. Items Table
            Table(
              border: TableBorder.all(color: borderColor, width: 1),
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(4),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  children: [
                    _flutterTh('Sl No.'),
                    _flutterTh('Item Name'),
                    _flutterTh('HSN/SAC\nCode'),
                    _flutterTh('Quantity'),
                    _flutterTh('Unit'),
                  ],
                ),
                ...data.items.asMap().entries.map((e) {
                  final idx = e.key + 1;
                  final item = e.value;
                  return TableRow(
                    children: [
                      _flutterTd(idx.toString(), align: TextAlign.center),
                      _flutterTd(item.desc),
                      _flutterTd(' ', align: TextAlign.center),
                      _flutterTd(item.qty.toString(), align: TextAlign.center),
                      _flutterTd('PCS', align: TextAlign.center),
                    ],
                  );
                }),
              ],
            ),

            // 5. Total Row (Custom spanning equivalent using Flex Row)
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF4B3CDB), // Force color matching the image for consistency
                border: Border(bottom: BorderSide(color: borderColor, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 72,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      child: const Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ),
                  Expanded(
                    flex: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(border: Border(left: BorderSide(color: borderColor, width: 1))),
                      child: Text(totalQty.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ),
                  Expanded(
                    flex: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: const BoxDecoration(border: Border(left: BorderSide(color: borderColor, width: 1))),
                    ),
                  ),
                ],
              ),
            ),

            // 6. Terms & Signature
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: borderColor, width: 1),
                          bottom: BorderSide(color: borderColor, width: 1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Terms & Conditions', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                          const SizedBox(height: 4),
                          Text(data.notes.isEmpty ? '1. Goods received in good condition.\n2. Subject to local jurisdiction.' : data.notes, style: const TextStyle(fontSize: 8, color: Colors.black)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text('For, ${data.businessName}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                          ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade400, width: 0.5))),
                            child: const Text('Authorized Signature', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 7. Received By Blocks
            _flutterReceivedBlock(isLast: false),
            _flutterReceivedBlock(isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _flutterInfoRow(String label, String value, {bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Colors.black, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.black, width: 1)),
              ),
              child: Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(value, style: const TextStyle(fontSize: 8, color: Colors.black), overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flutterHeaderRow(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
    );
  }

  Widget _flutterTh(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
    );
  }

  Widget _flutterTd(String text, {TextAlign align = TextAlign.left}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: align == TextAlign.center
          ? Alignment.center
          : (align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft),
      child: Text(text, style: const TextStyle(fontSize: 9, color: Colors.black)),
    );
  }

  Widget _flutterReceivedBlock({bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Colors.black, width: 1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Received By', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
          SizedBox(height: 4),
          Text('Name:', style: TextStyle(fontSize: 8, color: Colors.black)),
          SizedBox(height: 2),
          Text('Comment:', style: TextStyle(fontSize: 8, color: Colors.black)),
          SizedBox(height: 2),
          Text('Date:', style: TextStyle(fontSize: 8, color: Colors.black)),
          SizedBox(height: 2),
          Text('Signature:', style: TextStyle(fontSize: 8, color: Colors.black)),
        ],
      ),
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'UltraBuild Logistics',
      businessEmail: 'dispatch@ultrabuild.in',
      businessPhone: '+91 98765 11223',
      businessAddress: 'Plot 42, Industrial Area, Sector 5',
      gstin: '27AADCB1234F1Z9',
      clientName: 'City Construction Co.',
      clientAddress: 'Site B, Horizon Avenue, Metropolis',
      clientPhone: '9988776655',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: const Color(0xFF4B3CDB).toARGB32(),
      fontFamily: 'Roboto',
      items: [
        InvoiceItem(id: '1', desc: 'Portland Cement Bags (50kg)', details: '', qty: 120, rate: 0),
        InvoiceItem(id: '2', desc: 'TMT Steel Bars (12mm)', details: '', qty: 50, rate: 0),
        InvoiceItem(id: '3', desc: 'Fine Sand (Truckload)', details: '', qty: 2, rate: 0),
      ],
      notes: '1. Please verify goods count before signing.\n2. Damage claims must be reported within 24 hours.',
      isThermal: false,
    );
  }
}