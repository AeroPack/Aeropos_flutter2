import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class HardwareShopA4Template extends InvoiceTemplate {
  @override
  String get id => 'hardware_shop_01';
  @override
  String get name => 'Hardware Shop Standard';
  @override
  String get industry => 'HARDWARE';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'BOXED';
  @override
  String get previewImagePath => 'assets/preview_templates/hardware_shop_a4_template.png';
  @override
  Color get badgeColor => Colors.red.shade700;
  @override
  String get metadata => 'Standard Hardware Format with Grid';
  @override
  String? get tag => 'NEW';

  final PdfColor _borderColor = PdfColors.black;
  final PdfColor _headerColor = PdfColor.fromInt(0xFFD32F2F); // Red 700

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return wrapWithFont(
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderColor, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 1. Top Header (Business Details)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          data.businessName,
                          style: pw.TextStyle(
                            color: _headerColor,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text('Phone: ${data.businessPhone}', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('Email: ${data.businessEmail}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),

                  // 2. Bill To & Invoice Details
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: _borderColor, width: 1),
                        bottom: pw.BorderSide(color: _borderColor, width: 1),
                      ),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Bill To
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                right: pw.BorderSide(color: _borderColor, width: 1),
                              ),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('BILL TO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                pw.SizedBox(height: 4),
                                pw.Text(data.clientName, style: const pw.TextStyle(fontSize: 10)),
                                pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 10)),
                                pw.Text('Phone: 9999999999', style: const pw.TextStyle(fontSize: 10)),
                                pw.Text('PAN Number: 201301', style: const pw.TextStyle(fontSize: 10)),
                                pw.Text('GSTIN: ${data.gstin.isNotEmpty ? data.gstin : "GST34567"}', style: const pw.TextStyle(fontSize: 10)),
                                pw.Text('Place of Supply: Uttar Pradesh', style: const pw.TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                        // Invoice Info
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Invoice No: 49', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                pw.SizedBox(height: 4),
                                pw.Text('Invoice Date: 13 Apr, 2026 03:23 PM', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Items Table
                  pw.Table(
                    border: pw.TableBorder(
                      verticalInside: pw.BorderSide(color: _borderColor, width: 1),
                    ),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(0.5), // #
                      1: pw.FlexColumnWidth(3.0), // Items
                      2: pw.FlexColumnWidth(1.0), // HSN
                      3: pw.FlexColumnWidth(1.2), // Quantity
                      4: pw.FlexColumnWidth(1.5), // MRP
                      5: pw.FlexColumnWidth(1.5), // Rate Per Unit
                      6: pw.FlexColumnWidth(1.5), // Tax Per Unit
                      7: pw.FlexColumnWidth(1.5), // Amount
                    },
                    children: [
                      // Table Header
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: _headerColor),
                        children: [
                          _pdfHeaderCell('#'),
                          _pdfHeaderCell('Items'),
                          _pdfHeaderCell('HSN'),
                          _pdfHeaderCell('Quantity'),
                          _pdfHeaderCell('MRP'),
                          _pdfHeaderCell('Rate Per Unit'),
                          _pdfHeaderCell('Tax Per Unit'),
                          _pdfHeaderCell('Amount'),
                        ],
                      ),
                      // Item Rows
                      ...data.items.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final item = entry.value;
                        return pw.TableRow(
                          children: [
                            _pdfCell(index.toString(), align: pw.TextAlign.center),
                            _pdfCell(item.desc),
                            _pdfCell(''),
                            _pdfCell('${item.qty} Bora'),
                            _pdfCell('₹${item.rate.toStringAsFixed(0)}'),
                            _pdfCell('₹${item.rate.toStringAsFixed(2)}'),
                            _pdfCell('₹${(item.rate * 0.03).toStringAsFixed(2)} (3)'), // Example fixed tax logic for template
                            _pdfCell('₹${item.amount.toStringAsFixed(2)}'),
                          ],
                        );
                      }),
                      // Totals Row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 1)),
                        ),
                        children: [
                          _pdfCell(''),
                          _pdfCell('Total', isBold: true, align: pw.TextAlign.right),
                          _pdfCell(''),
                          _pdfCell(data.items.fold(0.0, (sum, item) => sum + item.qty).toStringAsFixed(2), isBold: true),
                          _pdfCell(''),
                          _pdfCell(''),
                          _pdfCell(''),
                          _pdfCell('₹${data.total.toStringAsFixed(2)}', isBold: true),
                        ],
                      ),
                    ],
                  ),

                  // 4. Payment Status Row
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: _borderColor, width: 1),
                        bottom: pw.BorderSide(color: _borderColor, width: 1),
                      ),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(right: pw.BorderSide(color: _borderColor, width: 1)),
                            ),
                            child: pw.Text('Received Amount: ₹${data.total.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Balance: ₹0.00', style: const pw.TextStyle(fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 5. Remarks
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 1)),
                    ),
                    child: pw.Text('Remark: ${data.notes}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),

                  // 6. Bank Details
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Empty Left Side
                        pw.Expanded(
                          child: pw.Container(),
                        ),
                        // Right Side (Bank Info)
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(left: pw.BorderSide(color: _borderColor, width: 1)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Bank Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                pw.SizedBox(height: 12),
                                _pdfBankRow('Account holder:', 'Rahul'),
                                _pdfBankRow('Account number:', data.bankAccountNo.isNotEmpty ? data.bankAccountNo : 'Account No'),
                                _pdfBankRow('Bank:', data.bankName.isNotEmpty ? data.bankName : 'Bank Name'),
                                _pdfBankRow('Branch:', 'Delhi'),
                                _pdfBankRow('IFSC code:', data.bankIfsc.isNotEmpty ? data.bankIfsc : 'IFSC Code'),
                                _pdfBankRow('UPI ID:', '1234567890'),
                                pw.SizedBox(height: 12),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text('UPI QR:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                    pw.Container(
                                      height: 60,
                                      width: 60,
                                      child: pw.BarcodeWidget(
                                        barcode: pw.Barcode.qrCode(),
                                        data: 'upi://pay?pa=1234567890@upi&pn=Rahul',
                                      ),
                                    ),
                                  ],
                                ),
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

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  pw.Widget _pdfCell(String text, {bool isBold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 9,
        ),
      ),
    );
  }

  pw.Widget _pdfBankRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    final borderColor = Colors.black;
    final headerColor = Colors.red.shade700;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.businessName,
                  style: TextStyle(
                    color: headerColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Phone: ${data.businessPhone}', style: const TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Text('Email: ${data.businessEmail}', style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),

          // 2. Bill To & Invoice Details
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor, width: 1),
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BILL TO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(data.clientName, style: const TextStyle(fontSize: 10)),
                          Text(data.clientAddress, style: const TextStyle(fontSize: 10)),
                          const Text('Phone: 9999999999', style: TextStyle(fontSize: 10)),
                          const Text('PAN Number: 201301', style: TextStyle(fontSize: 10)),
                          Text('GSTIN: ${data.gstin.isNotEmpty ? data.gstin : "GST34567"}', style: const TextStyle(fontSize: 10)),
                          const Text('Place of Supply: Uttar Pradesh', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invoice No: 49', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          SizedBox(height: 4),
                          Text('Invoice Date: 13 Apr, 2026 03:23 PM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Items Table
          Table(
            border: TableBorder(
              verticalInside: BorderSide(color: borderColor, width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(0.5),
              1: FlexColumnWidth(3.0),
              2: FlexColumnWidth(1.0),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1.5),
              5: FlexColumnWidth(1.5),
              6: FlexColumnWidth(1.5),
              7: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: headerColor),
                children: [
                  _flutterHeaderCell('#'),
                  _flutterHeaderCell('Items'),
                  _flutterHeaderCell('HSN'),
                  _flutterHeaderCell('Quantity'),
                  _flutterHeaderCell('MRP'),
                  _flutterHeaderCell('Rate Per Unit'),
                  _flutterHeaderCell('Tax Per Unit'),
                  _flutterHeaderCell('Amount'),
                ],
              ),
              ...data.items.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final item = entry.value;
                return TableRow(
                  children: [
                    _flutterCell(index.toString(), align: TextAlign.center),
                    _flutterCell(item.desc),
                    _flutterCell(''),
                    _flutterCell('${item.qty} Bora'),
                    _flutterCell('₹${item.rate.toStringAsFixed(0)}'),
                    _flutterCell('₹${item.rate.toStringAsFixed(2)}'),
                    _flutterCell('₹${(item.rate * 0.03).toStringAsFixed(2)} (3)'),
                    _flutterCell('₹${item.amount.toStringAsFixed(2)}'),
                  ],
                );
              }),
              TableRow(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                children: [
                  _flutterCell(''),
                  _flutterCell('Total', isBold: true, align: TextAlign.right),
                  _flutterCell(''),
                  _flutterCell(data.items.fold(0.0, (sum, item) => sum + item.qty).toStringAsFixed(2), isBold: true),
                  _flutterCell(''),
                  _flutterCell(''),
                  _flutterCell(''),
                  _flutterCell('₹${data.total.toStringAsFixed(2)}', isBold: true),
                ],
              ),
            ],
          ),

          // 4. Payment Status Row
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor, width: 1),
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: Text('Received Amount: ₹${data.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Text('Balance: ₹0.00', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Remarks
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Text('Remark: ${data.notes}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          ),

          // 6. Bank Details
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Container()),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: borderColor, width: 1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bank Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 12),
                        _flutterBankRow('Account holder:', 'Rahul'),
                        _flutterBankRow('Account number:', data.bankAccountNo.isNotEmpty ? data.bankAccountNo : 'Account No'),
                        _flutterBankRow('Bank:', data.bankName.isNotEmpty ? data.bankName : 'Bank Name'),
                        _flutterBankRow('Branch:', 'Delhi'),
                        _flutterBankRow('IFSC code:', data.bankIfsc.isNotEmpty ? data.bankIfsc : 'IFSC Code'),
                        _flutterBankRow('UPI ID:', '1234567890'),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('UPI QR:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                            Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black54),
                              ),
                              child: const Icon(Icons.qr_code_2, size: 48),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flutterHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _flutterCell(String text, {bool isBold = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _flutterBankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          Text(value, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: "Ravi kumar",
      businessEmail: "ravikumar124dubey@gmail.com",
      businessPhone: "9508399874",
      businessAddress: "",
      gstin: "GST34567",
      clientName: "raman",
      clientAddress: "Noida Sector 12, W Block\nPin: 201301",
      taxLabel: "GST",
      taxRate: 18,
      themeColorArgb: Colors.red.shade700.toARGB32(),
      fontFamily: "Inter",
      items: [
        InvoiceItem(
          id: '1',
          desc: 'Tap',
          details: '',
          qty: 1,
          rate: 999,
        ),
        InvoiceItem(
          id: '2',
          desc: 'pipe',
          details: '',
          qty: 1,
          rate: 299,
        ),
        InvoiceItem(
          id: '3',
          desc: 'fevicol',
          details: '',
          qty: 1,
          rate: 499,
        ),
      ],
      notes: "",
      isThermal: false,
    );
  }
}