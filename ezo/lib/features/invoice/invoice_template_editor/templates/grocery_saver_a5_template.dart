import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class GroceryTaxInvoiceTemplate extends InvoiceTemplate {
  @override
  String get id => 'grocery_tax_a5_01';
  @override
  String get name => 'Grocery Standard Tax Invoice';
  @override
  String get industry => 'GROCERY';
  @override
  String get format => 'A5';
  @override
  String get styleName => 'PROFESSIONAL';
  @override
  String get previewImagePath =>
      'assets/preview_templates/grocery_saver_a5_template.png';
  @override
  Color get badgeColor => Colors.blue.shade600;
  @override
  String get metadata => 'A5 format optimized';
  @override
  String? get tag => 'TAX INVOICE';

  final PdfColor _headerColor = PdfColor.fromHex('#D9F0FA');
  final PdfColor _bannerColor = PdfColor.fromHex('#7DCCEF');

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return wrapWithFont(
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                mainAxisSize: pw.MainAxisSize.min, // Wrap content tightly
                children: [
                  // Top Header Section
                  pw.Container(
                    color: _headerColor,
                    padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 6,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(data.businessName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                              pw.SizedBox(height: 4),
                              pw.Text('Address: ${data.businessAddress}', style: const pw.TextStyle(fontSize: 11)),
                              pw.Text('Phone No.: ${data.businessPhone}', style: const pw.TextStyle(fontSize: 11)),
                              pw.Text('GSTIN No.: ${data.gstin}', style: const pw.TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('Email: ${data.businessEmail}', style: const pw.TextStyle(fontSize: 11)),
                              pw.SizedBox(height: 2),
                              pw.Text('State: Local', style: const pw.TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tax Invoice Banner
                  pw.Container(
                    color: _bannerColor,
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.symmetric(horizontal: pw.BorderSide(color: PdfColors.black, width: 1)),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
                      ),
                    ),
                  ),

                  // Bill & Invoice Details
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left: Bill Details
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Bill To', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                              pw.SizedBox(height: 6),
                              pw.Text('Party Name: ${data.clientName}', style: const pw.TextStyle(fontSize: 11)),
                              pw.Text('Address: ${data.clientAddress}', style: const pw.TextStyle(fontSize: 11)),
                              pw.Text('Phone No.: ${data.clientPhone.isNotEmpty ? data.clientPhone : "N/A"}', style: const pw.TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        // Right: Invoice Details
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Invoice Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                              pw.SizedBox(height: 6),
                              pw.Text('Invoice No.: ${data.invoiceNumber.isNotEmpty ? data.invoiceNumber : "INV-001"}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Invoice Date: ${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', style: const pw.TextStyle(fontSize: 11)),
                              pw.Text('Time: ${data.invoiceDate.hour}:${data.invoiceDate.minute.toString().padLeft(2, '0')}', style: const pw.TextStyle(fontSize: 11)),
                              pw.Text('Place of Supply: Local', style: const pw.TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Table
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                    columnWidths: const {
                      0: pw.FixedColumnWidth(40),
                      1: pw.FlexColumnWidth(3),
                      2: pw.FixedColumnWidth(60),
                      3: pw.FixedColumnWidth(40),
                      4: pw.FixedColumnWidth(40),
                      5: pw.FixedColumnWidth(60),
                      6: pw.FixedColumnWidth(50),
                      7: pw.FixedColumnWidth(70),
                    },
                    children: [
                      // Table Header
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          _pdfHeaderCell('Sl. No.'),
                          _pdfHeaderCell('Item Name', align: pw.TextAlign.left),
                          _pdfHeaderCell('HSN'),
                          _pdfHeaderCell('QTY'),
                          _pdfHeaderCell('Unit'),
                          _pdfHeaderCell('Price'),
                          _pdfHeaderCell('GST %'),
                          _pdfHeaderCell('Amount', align: pw.TextAlign.right),
                        ],
                      ),
                      // Table Items
                      ...data.items.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        return pw.TableRow(
                          children: [
                            _pdfItemCell(idx.toString(), align: pw.TextAlign.center),
                            _pdfItemCell(item.desc),
                            _pdfItemCell('1900', align: pw.TextAlign.center),
                            _pdfItemCell(item.qty.toString(), align: pw.TextAlign.center),
                            _pdfItemCell('PCS', align: pw.TextAlign.center),
                            _pdfItemCell(item.rate.toStringAsFixed(2), align: pw.TextAlign.right),
                            _pdfItemCell('${data.taxRate}%', align: pw.TextAlign.center),
                            _pdfItemCell(item.amount.toStringAsFixed(2), align: pw.TextAlign.right),
                          ],
                        );
                      }),
                      // Table Total Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                        children: [
                          _pdfItemCell(''),
                          _pdfItemCell('Total', isBold: true),
                          _pdfItemCell(''),
                          _pdfItemCell(data.items.fold(0.0, (sum, item) => sum + item.qty).toString(), align: pw.TextAlign.center, isBold: true),
                          _pdfItemCell(''),
                          _pdfItemCell(''),
                          _pdfItemCell(''),
                          _pdfItemCell(data.subtotal.toStringAsFixed(2), align: pw.TextAlign.right, isBold: true),
                        ],
                      ),
                    ],
                  ),

                  // Bottom Section
                  pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Left Bottom (Amount in words, terms)
                        pw.Expanded(
                          flex: 6,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Notes:\n${data.notes}', style: const pw.TextStyle(fontSize: 10)),
                              ),
                              pw.Container(
                                color: _headerColor,
                                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.symmetric(horizontal: pw.BorderSide(color: PdfColors.black, width: 1)),
                                ),
                                child: pw.Text('Invoice Amount In Words:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Rupees ${data.total.toInt()} Only.', style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
                              ),
                              pw.Container(
                                color: _headerColor,
                                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.symmetric(horizontal: pw.BorderSide(color: PdfColors.black, width: 1)),
                                ),
                                child: pw.Text('Terms and Conditions:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('1. Goods once sold will not be taken back.\n2. Interest @ 18% p.a. will be charged if not paid within due date.', style: const pw.TextStyle(fontSize: 10)),
                              ),
                            ],
                          ),
                        ),
                        // Right Bottom (Totals & Signature)
                        pw.Expanded(
                          flex: 4,
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border(left: pw.BorderSide(color: PdfColors.black, width: 1)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                _pdfSummaryRow('Sub Total', data.subtotal.toStringAsFixed(2)),
                                _pdfSummaryRow('Discount', '0.00'),
                                _pdfSummaryRow('${data.taxLabel} Amount', data.taxAmount.toStringAsFixed(2)),
                                _pdfSummaryRow('Total Amount', data.total.toStringAsFixed(2), isBold: true),
                                _pdfSummaryRow('Received', data.total.toStringAsFixed(2)),
                                _pdfSummaryRow('Balance Amount', '0.00', showBottomBorder: true, isBold: true),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(12),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                                    children: [
                                      pw.Text('For ${data.businessName}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                      pw.SizedBox(height: 30), // Signature space
                                      pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 10)),
                                    ]
                                  ),
                                )
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

  pw.Widget _pdfHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _pdfItemCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  pw.Widget _pdfSummaryRow(String label, String value, {bool showBottomBorder = false, bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: showBottomBorder
          ? pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)))
          : null,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    final Color headerColor = const Color(0xFFD9F0FA);
    final Color bannerColor = const Color(0xFF7DCCEF);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header Section
            Container(
              color: headerColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        const SizedBox(height: 4),
                        Text('Address: ${data.businessAddress}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                        Text('Phone No.: ${data.businessPhone}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                        Text('GSTIN No.: ${data.gstin}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Email: ${data.businessEmail}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                        const SizedBox(height: 2),
                        const Text('State: Local', style: TextStyle(fontSize: 11, color: Colors.black)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tax Invoice Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: bannerColor,
                border: const Border.symmetric(horizontal: BorderSide(color: Colors.black, width: 1)),
              ),
              child: const Center(
                child: Text(
                  'TAX INVOICE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5, color: Colors.black),
                ),
              ),
            ),

            // Bill & Invoice Details
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bill To', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                        const SizedBox(height: 6),
                        Text('Party Name: ${data.clientName}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                        Text('Address: ${data.clientAddress}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                        Text('Phone No.: ${data.clientPhone.isNotEmpty ? data.clientPhone : "N/A"}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Invoice Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                        const SizedBox(height: 6),
                        Text('Invoice No.: ${data.invoiceNumber.isNotEmpty ? data.invoiceNumber : "INV-001"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text('Invoice Date: ${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                        Text('Time: ${data.invoiceDate.hour}:${data.invoiceDate.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                        const Text('Place of Supply: Local', style: TextStyle(fontSize: 11, color: Colors.black)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Table
            Table(
              border: TableBorder.all(color: Colors.black, width: 1),
              columnWidths: const {
                0: FixedColumnWidth(40),
                1: FlexColumnWidth(3),
                2: FixedColumnWidth(60),
                3: FixedColumnWidth(40),
                4: FixedColumnWidth(40),
                5: FixedColumnWidth(60),
                6: FixedColumnWidth(50),
                7: FixedColumnWidth(70),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    _flutterHeaderCell('Sl. No.'),
                    _flutterHeaderCell('Item Name', align: TextAlign.left),
                    _flutterHeaderCell('HSN'),
                    _flutterHeaderCell('QTY'),
                    _flutterHeaderCell('Unit'),
                    _flutterHeaderCell('Price'),
                    _flutterHeaderCell('GST %'),
                    _flutterHeaderCell('Amount', align: TextAlign.right),
                  ],
                ),
                ...data.items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return TableRow(
                    children: [
                      _flutterItemCell(idx.toString(), align: TextAlign.center),
                      _flutterItemCell(item.desc),
                      _flutterItemCell('1900', align: TextAlign.center),
                      _flutterItemCell(item.qty.toString(), align: TextAlign.center),
                      _flutterItemCell('PCS', align: TextAlign.center),
                      _flutterItemCell(item.rate.toStringAsFixed(2), align: TextAlign.right),
                      _flutterItemCell('${data.taxRate}%', align: TextAlign.center),
                      _flutterItemCell(item.amount.toStringAsFixed(2), align: TextAlign.right),
                    ],
                  );
                }),
                // Total Row
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    _flutterItemCell(''),
                    _flutterItemCell('Total', isBold: true),
                    _flutterItemCell(''),
                    _flutterItemCell(data.items.fold(0.0, (sum, item) => sum + item.qty).toString(), align: TextAlign.center, isBold: true),
                    _flutterItemCell(''),
                    _flutterItemCell(''),
                    _flutterItemCell(''),
                    _flutterItemCell(data.subtotal.toStringAsFixed(2), align: TextAlign.right, isBold: true),
                  ],
                ),
              ],
            ),

            // Bottom Section
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Bottom
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Notes:\n${data.notes}', style: const TextStyle(fontSize: 10, color: Colors.black)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: headerColor,
                            border: const Border.symmetric(horizontal: BorderSide(color: Colors.black, width: 1)),
                          ),
                          child: const Text('Invoice Amount In Words:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Rupees ${data.total.toInt()} Only.', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: headerColor,
                            border: const Border.symmetric(horizontal: BorderSide(color: Colors.black, width: 1)),
                          ),
                          child: const Text('Terms and Conditions:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('1. Goods once sold will not be taken back.\n2. Interest @ 18% p.a. will be charged if not paid within due date.', style: TextStyle(fontSize: 10, color: Colors.black)),
                        ),
                      ],
                    ),
                  ),
                  // Right Bottom
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.black, width: 1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _flutterSummaryRow('Sub Total', data.subtotal.toStringAsFixed(2)),
                          _flutterSummaryRow('Discount', '0.00'),
                          _flutterSummaryRow('${data.taxLabel} Amount', data.taxAmount.toStringAsFixed(2)),
                          _flutterSummaryRow('Total Amount', data.total.toStringAsFixed(2), isBold: true),
                          _flutterSummaryRow('Received', data.total.toStringAsFixed(2)),
                          _flutterSummaryRow('Balance Amount', '0.00', showBottomBorder: true, isBold: true),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('For ${data.businessName}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                                const SizedBox(height: 30),
                                const Text('Authorized Signatory', style: TextStyle(fontSize: 10, color: Colors.black)),
                              ],
                            ),
                          )
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

  Widget _flutterHeaderCell(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
      ),
    );
  }

  Widget _flutterItemCell(String text, {TextAlign align = TextAlign.left, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black),
      ),
    );
  }

  Widget _flutterSummaryRow(String label, String value, {bool showBottomBorder = false, bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: showBottomBorder
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1)))
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
        ],
      ),
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: "Fresh Mart Grocery Store",
      businessEmail: "hello@freshmart.com",
      businessPhone: "+91 9876543210",
      businessAddress: "Shop No. 42, Main Market, City Center",
      gstin: "07AABCB1234Z1Z5",
      clientName: "Rahul Sharma",
      clientAddress: "Block A, Residential Complex, City",
      clientPhone: "9988776655",
      taxLabel: "GST",
      taxRate: 18,
      themeColorArgb: Colors.blue.toARGB32(),
      fontFamily: "Roboto",
      items: [
        InvoiceItem(
          id: '1',
          desc: 'Aashirvaad Whole Wheat Atta 5kg',
          details: 'SKU: 1002',
          qty: 2,
          rate: 220,
        ),
        InvoiceItem(
          id: '2',
          desc: 'Fortune Sunflower Oil 1L',
          details: 'SKU: 5542',
          qty: 3,
          rate: 145,
        ),
        InvoiceItem(
          id: '3',
          desc: 'Tata Salt 1kg',
          details: 'SKU: 0021',
          qty: 4,
          rate: 25,
        ),
        InvoiceItem(
          id: '4',
          desc: 'Madhur Sugar 1kg',
          details: 'SKU: 1088',
          qty: 2,
          rate: 45,
        ),
      ],
      notes: "Thank you for shopping with us! Fresh groceries delivered.",
      isThermal: false,
    );
  }
}