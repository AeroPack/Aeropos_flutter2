import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class RestaurantA4InvoiceTemplate extends InvoiceTemplate {
  @override
  String get id => 'restaurant_bill_a4';
  @override
  String get name => 'Standard Restaurant Bill';
  @override
  String get industry => 'FOOD & BEVERAGE';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'MINIMALIST';
  @override
  String get previewImagePath =>
      'assets/preview_templates/restaurant_a4_template.png';
  @override
  Color get badgeColor => const Color(0xFFD32F2F); // Vibrant Red
  @override
  String get metadata => 'A4 optimized, Restaurant format';
  @override
  String? get tag => 'BILLING';

  // --- PDF GENERATION ---
  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromInt(data.themeColorArgb);
    const textColor = PdfColors.grey900;
    final tableBorder = pw.TableBorder.all(color: primaryColor, width: 1);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(
          24,
        ), // Reduced margins to maximize space
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min, // Wrap content tightly
            children: [
              // 1. Top Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                ), // Tighter padding
                color: primaryColor,
                child: pw.Text(
                  'Restaurant Bill',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              pw.SizedBox(height: 12), // Reduced spacing
              // 2. Restaurant Info Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfDetailRow('Restaurant Name :', data.businessName),
                      pw.SizedBox(height: 2),
                      _pdfDetailRow('Address :', data.businessAddress),
                      pw.SizedBox(height: 2),
                      _pdfDetailRow('Phone Number :', data.businessPhone),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfDetailRow('GSTIN No :', data.gstin.isNotEmpty ? data.gstin : "N/A"),
                      pw.SizedBox(height: 2),
                      _pdfDetailRow(
                        'Invoice no :',
                        data.invoiceNumber.isNotEmpty ? data.invoiceNumber : 'INV-001',
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // 3. Bill To Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 8,
                ),
                color: primaryColor,
                child: pw.Text(
                  'Bill To:',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),

              // 4. Customer Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfDetailRow('Name :', data.clientName),
                      pw.SizedBox(height: 2),
                      _pdfDetailRow('Address :', data.clientAddress),
                      pw.SizedBox(height: 2),
                      _pdfDetailRow('Phone No :', data.clientPhone.isNotEmpty ? data.clientPhone : "N/A"),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfDetailRow('GSTIN :', 'N/A'),
                      pw.SizedBox(height: 2),
                      _pdfDetailRow('State :', 'Local'),
                      pw.SizedBox(height: 2),
                      _pdfDetailRow(
                        'Date :',
                        '${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}',
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // 5. Items Table
              pw.Table(
                border: tableBorder,
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.0),
                  1: pw.FlexColumnWidth(3.5),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                  4: pw.FlexColumnWidth(2.0),
                  5: pw.FlexColumnWidth(2.0),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      _pdfHeaderCell('S.No'),
                      _pdfHeaderCell(
                        'Goods Description',
                        align: pw.TextAlign.left,
                      ),
                      _pdfHeaderCell('HSN'),
                      _pdfHeaderCell('QTY'),
                      _pdfHeaderCell('MRP'),
                      _pdfHeaderCell('Amount'),
                    ],
                  ),
                  // Table Body
                  ...data.items.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final item = entry.value;
                    return pw.TableRow(
                      children: [
                        _pdfBodyCell(
                          '${index + 1}',
                          align: pw.TextAlign.center,
                        ),
                        _pdfBodyCell(item.desc, align: pw.TextAlign.left),
                        _pdfBodyCell(
                          '9963',
                          align: pw.TextAlign.center,
                        ), // Dummy Restaurant HSN
                        _pdfBodyCell('${item.qty}', align: pw.TextAlign.center),
                        _pdfBodyCell(
                          item.rate.toStringAsFixed(2),
                          align: pw.TextAlign.center,
                        ),
                        _pdfBodyCell(
                          item.amount.toStringAsFixed(2),
                          align: pw.TextAlign.center,
                        ),
                      ],
                    );
                  }),
                  // Removed empty spacer rows to compress UI
                ],
              ),

              // 6. Bottom Calculations Block
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: primaryColor),
                    right: pw.BorderSide(color: primaryColor),
                    bottom: pw.BorderSide(color: primaryColor),
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw
                      .CrossAxisAlignment
                      .stretch, // Ensures both columns stretch to match height
                  children: [
                    // Left side: Amount in words
                    pw.Expanded(
                      flex: 75,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            right: pw.BorderSide(color: primaryColor),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Amount in words',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Rupees ${data.total.toInt()} Only',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: textColor,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right side: Calculations
                    pw.Expanded(
                      flex: 40,
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          _pdfCalcRow(
                            'Discount :',
                            '0.00',
                            primaryColor,
                            showBottomBorder: true,
                          ),
                          _pdfCalcRow(
                            'SGST :',
                            (data.taxAmount / 2).toStringAsFixed(2),
                            primaryColor,
                            showBottomBorder: true,
                          ),
                          _pdfCalcRow(
                            'CGST :',
                            (data.taxAmount / 2).toStringAsFixed(2),
                            primaryColor,
                            showBottomBorder: true,
                          ),
                          _pdfCalcRow(
                            'Service Tax :',
                            '0.00',
                            primaryColor,
                            showBottomBorder: true,
                          ),
                          pw.Expanded(
                            // Push Total to the bottom to fill space evenly
                            child: pw.Container(
                              color: PdfColor.fromInt(
                                ((0.1 * 255).round() << 24) |
                                    ((primaryColor.red * 255).round() << 16) |
                                    ((primaryColor.green * 255).round() << 8) |
                                    (primaryColor.blue * 255).round(),
                              ),
                              child: _pdfCalcRow(
                                'Total :',
                                data.total.toStringAsFixed(2),
                                primaryColor,
                                showBottomBorder: false,
                                isBold: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  // --- PDF Helper Widgets ---
  pw.Widget _pdfHeaderCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        vertical: 6,
        horizontal: 4,
      ), // Tighter vertical padding
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfBodyCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        vertical: 6,
        horizontal: 6,
      ), // Tighter padding, removed hardcoded heights
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
      ),
    );
  }

  pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 80,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _pdfCalcRow(
    String label,
    String value,
    PdfColor borderColor, {
    bool showBottomBorder = true,
    bool isBold = false,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: showBottomBorder
            ? pw.Border(bottom: pw.BorderSide(color: borderColor))
            : null,
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 1,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 6,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: borderColor)),
              ),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 6,
              ),
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FLUTTER PREVIEW ---
  @override
  Widget buildFlutterPreview(InvoiceData data) {
    final primaryColor = Color(data.themeColorArgb);
    const textColor = Colors.black87;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:
            MainAxisSize.min, // Prevents expanding to fill empty space
        children: [
          // Top Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: primaryColor,
            child: const Text(
              'Restaurant Bill',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Restaurant Info Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _flutterDetailRow('Restaurant Name :', data.businessName),
                    const SizedBox(height: 2),
                    _flutterDetailRow('Address :', data.businessAddress),
                    const SizedBox(height: 2),
                    _flutterDetailRow('Phone Number :', data.businessPhone),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _flutterDetailRow(
                      'GSTIN No :',
                      data.gstin.isNotEmpty ? data.gstin : "N/A",
                      alignEnd: true,
                    ),
                    const SizedBox(height: 2),
                    _flutterDetailRow(
                      'Invoice no :',
                      data.invoiceNumber.isNotEmpty ? data.invoiceNumber : 'INV-001',
                      alignEnd: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bill To Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: primaryColor,
            child: const Text(
              'Bill To:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Customer Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _flutterDetailRow('Name :', data.clientName),
                    const SizedBox(height: 2),
                    _flutterDetailRow('Address :', data.clientAddress),
                    const SizedBox(height: 2),
                    _flutterDetailRow('Phone No :', data.clientPhone.isNotEmpty ? data.clientPhone : "N/A"),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _flutterDetailRow('GSTIN :', 'N/A', alignEnd: true),
                    const SizedBox(height: 2),
                    _flutterDetailRow('State :', 'Local', alignEnd: true),
                    const SizedBox(height: 2),
                    _flutterDetailRow('Date :', '${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', alignEnd: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Items Table
          Table(
            border: TableBorder.all(color: primaryColor, width: 1),
            columnWidths: const {
              0: FlexColumnWidth(1.0),
              1: FlexColumnWidth(3.0),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1.5),
              5: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: primaryColor),
                children: [
                  _flutterHeaderCell('S.No'),
                  _flutterHeaderCell(
                    'Goods Description',
                    align: TextAlign.left,
                  ),
                  _flutterHeaderCell('HSN'),
                  _flutterHeaderCell('QTY'),
                  _flutterHeaderCell('MRP'),
                  _flutterHeaderCell('Amount'),
                ],
              ),
              ...data.items.asMap().entries.map((entry) {
                final int index = entry.key;
                final item = entry.value;
                return TableRow(
                  children: [
                    _flutterBodyCell('${index + 1}', align: TextAlign.center),
                    _flutterBodyCell(item.desc, align: TextAlign.left),
                    _flutterBodyCell('9963', align: TextAlign.center),
                    _flutterBodyCell('${item.qty}', align: TextAlign.center),
                    _flutterBodyCell(
                      item.rate.toStringAsFixed(0),
                      align: TextAlign.center,
                    ),
                    _flutterBodyCell(
                      item.amount.toStringAsFixed(0),
                      align: TextAlign.center,
                    ),
                  ],
                );
              }),
              // Removed empty spacer rows to compress UI
            ],
          ),

          // Bottom Calculations Block
          IntrinsicHeight(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: primaryColor),
                  right: BorderSide(color: primaryColor),
                  bottom: BorderSide(color: primaryColor),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side: Words
                  Expanded(
                    flex: 64, // Matches relative width
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: primaryColor)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amount in words',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rupees ${data.total.toInt()} Only',
                            style: const TextStyle(
                              fontSize: 8,
                              color: textColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right side: Totals
                  Expanded(
                    flex: 36,
                    child: Column(
                      children: [
                        _flutterCalcRow(
                          'Discount :',
                          '0.00',
                          primaryColor,
                          showBottomBorder: true,
                        ),
                        _flutterCalcRow(
                          'SGST :',
                          (data.taxAmount / 2).toStringAsFixed(2),
                          primaryColor,
                          showBottomBorder: true,
                        ),
                        _flutterCalcRow(
                          'CGST :',
                          (data.taxAmount / 2).toStringAsFixed(2),
                          primaryColor,
                          showBottomBorder: true,
                        ),
                        _flutterCalcRow(
                          'Service Tax :',
                          '0.00',
                          primaryColor,
                          showBottomBorder: true,
                        ),
                        Expanded(
                          child: Container(
                            color: primaryColor.withOpacity(0.1),
                            child: _flutterCalcRow(
                              'Total :',
                              data.total.toStringAsFixed(2),
                              primaryColor,
                              showBottomBorder: false,
                              isBold: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Flutter Helper Widgets ---
  Widget _flutterHeaderCell(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _flutterBodyCell(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 7, color: Colors.black87),
      ),
    );
  }

  Widget _flutterDetailRow(
    String label,
    String value, {
    bool alignEnd = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 8, color: Colors.black87),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _flutterCalcRow(
    String label,
    String value,
    Color borderColor, {
    bool showBottomBorder = true,
    bool isBold = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: showBottomBorder
            ? Border(bottom: BorderSide(color: borderColor))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: borderColor)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DUMMY DATA ---
  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Spice Symphony',
      businessEmail: 'contact@spicesymphony.com',
      businessPhone: '+91 98765 12345',
      businessAddress: 'Plot 42, Food Street, New Delhi - 110001',
      gstin: '07AABCB1234Z1Z5',
      clientName: 'Rahul Verma',
      clientAddress: 'Block C, Vasant Kunj, New Delhi',
      clientPhone: '+91 91234 56789',
      taxLabel: 'GST',
      taxRate: 5, // Typical Restaurant GST in India
      themeColorArgb: 0xFFD32F2F, // Deep Red
      fontFamily: 'Helvetica',
      items: [
        InvoiceItem(
          id: '1',
          desc: 'Paneer Butter Masala',
          details: '',
          qty: 1,
          rate: 350,
        ),
        InvoiceItem(
          id: '2',
          desc: 'Garlic Naan',
          details: '',
          qty: 4,
          rate: 50,
        ),
        InvoiceItem(
          id: '3',
          desc: 'Dal Makhani',
          details: '',
          qty: 1,
          rate: 280,
        ),
        InvoiceItem(
          id: '4',
          desc: 'Fresh Lime Soda',
          details: '',
          qty: 2,
          rate: 90,
        ),
      ],
      notes: 'Thank you for dining with us!',
      isThermal: false,
    );
  }
}
