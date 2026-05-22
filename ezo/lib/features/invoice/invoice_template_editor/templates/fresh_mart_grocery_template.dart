import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../helpers/thermal_utils.dart';
import '../models.dart';

class FreshMartGroceryTemplate extends InvoiceTemplate {
  @override
  String get id => 'fresh_mart_10';
  @override
  String get name => 'Fresh Mart Grocery';
  @override
  String get industry => 'GROCERY';
  @override
  String get format => 'THERMAL';
  @override
  String get styleName => 'COMPACT';
  @override
  String get previewImagePath =>
      'assets/preview_templates/fresh_mart_grocery_template.png';
  @override
  Color get badgeColor => Colors.green.shade600;
  @override
  String get metadata => '58mm/72mm/80mm optimized';
  @override
  String? get tag => 'GROCERY SPECIAL';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();

    final mmWidth = thermalWidthInPoints(data.thermalWidth);
    final rollFormat = PdfPageFormat(mmWidth, double.infinity, marginAll: 10);

    pw.MemoryImage? logoImage;
    if (data.showLogo && data.logoBytes != null) {
      logoImage = pw.MemoryImage(data.logoBytes!);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: rollFormat,
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo
              if (data.showLogo) ...[
                if (logoImage != null)
                  pw.Container(
                    width: 40,
                    height: 40,
                    child: pw.Image(logoImage),
                  )
                else
                  pw.Container(
                    width: 40,
                    height: 40,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'LOGO',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                pw.SizedBox(height: 12),
              ],

              // Business Details
              pw.Text(
                data.businessName,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (data.showBusinessAddress)
                pw.Text(
                  data.businessAddress,
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              pw.Text(
                '${data.taxLabel} IN: ${data.gstin}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColors.black),

              // Meta info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date: ${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Time: ${data.invoiceDate.hour}:${data.invoiceDate.minute.toString().padLeft(2, '0')}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Inv No: ET-88291',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  if (data.paymentMethod != null)
                    pw.Text(
                      'Payment: ${data.paymentMethod!.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    )
                  else
                    pw.Text(
                      'Cashier: Admin',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                ],
              ),

              pw.Divider(thickness: 1, color: PdfColors.black),

              // Items Table
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _pdfCell('Item', pw.TextAlign.left, isBold: true),
                      _pdfCell('Qty', pw.TextAlign.center, isBold: true),
                      _pdfCell('Rate', pw.TextAlign.right, isBold: true),
                      _pdfCell('Amt', pw.TextAlign.right, isBold: true),
                    ],
                  ),
                  ...data.items.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Text(
                            item.desc,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        _pdfCell(item.qty.toString(), pw.TextAlign.center),
                        _pdfCell(
                          item.rate.toStringAsFixed(2),
                          pw.TextAlign.right,
                        ),
                        _pdfCell(
                          item.amount.toStringAsFixed(2),
                          pw.TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Divider(thickness: 1, color: PdfColors.black, height: 16),

              // Totals
              _pdfTotalRow('Subtotal:', data.subtotal.toStringAsFixed(2)),
              if (data.showTaxBreakdown &&
                  data.taxLabel.toUpperCase() == 'GST') ...[
                _pdfTotalRow(
                  'SGST (${(data.taxRate / 2).toStringAsFixed(1)}%):',
                  (data.taxAmount / 2).toStringAsFixed(2),
                ),
                _pdfTotalRow(
                  'CGST (${(data.taxRate / 2).toStringAsFixed(1)}%):',
                  (data.taxAmount / 2).toStringAsFixed(2),
                ),
              ] else ...[
                _pdfTotalRow(
                  '${data.taxLabel} (${data.taxRate}%):',
                  data.taxAmount.toStringAsFixed(2),
                ),
              ],
              pw.Container(
                height: 0.5,
                color: PdfColors.black,
                margin: const pw.EdgeInsets.symmetric(vertical: 2),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'GRAND TOTAL',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Rs ${data.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.Divider(thickness: 1, color: PdfColors.black, height: 16),

              // Footer
              pw.Text(
                'Thank you for shopping!',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (data.showNotes && data.notes.isNotEmpty)
                pw.Text(data.notes, style: pw.TextStyle(fontSize: 8)),

              pw.SizedBox(height: 20),
              pw.Text(
                '--- Powering local stores ---',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _pdfCell(String label, pw.TextAlign align, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _pdfTotalRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    return SizedBox(
      width: 300,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.showLogo) ...[
              Center(
                child: data.logoBytes != null || data.logoPath != null
                    ? buildLogoWidget(data, size: 50)
                    : Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: const Center(
                          child: Text(
                            'LOGO',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              data.businessName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (data.showBusinessAddress)
              Text(
                data.businessAddress,
                style: const TextStyle(fontSize: 8),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              '${data.taxLabel} IN: ${data.gstin}',
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: Colors.black,
              margin: const EdgeInsets.symmetric(vertical: 6),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date: ${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}',
                  style: const TextStyle(fontSize: 8),
                ),
                Text(
                  'Time: ${data.invoiceDate.hour}:${data.invoiceDate.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 8),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Inv No: ET-88291', style: TextStyle(fontSize: 8)),
                if (data.paymentMethod != null)
                  Text(
                    'Payment: ${data.paymentMethod!.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  const Text('Cashier: Admin', style: TextStyle(fontSize: 8)),
              ],
            ),
            Container(
              height: 1,
              color: Colors.black,
              margin: const EdgeInsets.symmetric(vertical: 6),
            ),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FixedColumnWidth(40),
                2: FixedColumnWidth(50),
                3: FixedColumnWidth(50),
              },
              children: [
                const TableRow(
                  children: [
                    Text(
                      'Item',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Qty',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Rate',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    Text(
                      'Amt',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
                ...data.items.map(
                  (item) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          item.desc,
                          style: const TextStyle(fontSize: 9),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        item.qty.toString(),
                        style: const TextStyle(fontSize: 9),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        item.rate.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 9),
                        textAlign: TextAlign.right,
                      ),
                      Text(
                        item.amount.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 9),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              height: 1,
              color: Colors.black,
              margin: const EdgeInsets.symmetric(vertical: 6),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:', style: TextStyle(fontSize: 9)),
                Text(
                  data.subtotal.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 9),
                ),
              ],
            ),
            if (data.showTaxBreakdown &&
                data.taxLabel.toUpperCase() == 'GST') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SGST (${(data.taxRate / 2).toStringAsFixed(1)}%):',
                    style: const TextStyle(fontSize: 8),
                  ),
                  Text(
                    (data.taxAmount / 2).toStringAsFixed(2),
                    style: const TextStyle(fontSize: 8),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CGST (${(data.taxRate / 2).toStringAsFixed(1)}%):',
                    style: const TextStyle(fontSize: 8),
                  ),
                  Text(
                    (data.taxAmount / 2).toStringAsFixed(2),
                    style: const TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${data.taxLabel} (${data.taxRate}%):',
                    style: const TextStyle(fontSize: 8),
                  ),
                  Text(
                    data.taxAmount.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 8),
                  ),
                ],
              ),
            Container(
              height: 1,
              color: Colors.black,
              margin: const EdgeInsets.symmetric(vertical: 6),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  data.total.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              height: 1,
              color: Colors.black,
              margin: const EdgeInsets.symmetric(vertical: 6),
            ),
            if (data.showNotes && data.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                data.notes,
                style: const TextStyle(fontSize: 7),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.black,
              margin: const EdgeInsets.symmetric(vertical: 6),
            ),
            const Text(
              'Thank You!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const Text(
              'Please Visit Again',
              style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            Container(
              width: 160,
              height: 24,
              color: Colors.black,
              child: const Center(
                child: Text(
                  '|||||| || |||| ||| ||| |||||',
                  style: TextStyle(fontSize: 7, color: Colors.white),
                ),
              ),
            ),
            const Text('ET-88291-2024', style: TextStyle(fontSize: 7)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: "Fresh Mart Grocery",
      businessEmail: "info@freshmart.com",
      businessPhone: "+91 22 9876 5432",
      businessAddress: "123 Market Street, Downtown, City, State - 400001",
      gstin: "27AABCF1234Z1Z5",
      clientName: "Walk-in Customer",
      clientAddress: "Local Area",
      taxLabel: "GST",
      taxRate: 18,
      themeColorArgb: Colors.black.toARGB32(),
      fontFamily: "Mono",
      items: [
        InvoiceItem(
          id: '1',
          desc: 'Basmati Rice (Gold)',
          details: 'SKU: 1002',
          qty: 5,
          rate: 90,
        ),
        InvoiceItem(
          id: '2',
          desc: 'Organic Sunflower Oil',
          details: 'SKU: 5542',
          qty: 2,
          rate: 185,
        ),
        InvoiceItem(
          id: '3',
          desc: 'Fresh Tomato',
          details: 'SKU: 0021',
          qty: 1.5,
          rate: 40,
        ),
        InvoiceItem(
          id: '4',
          desc: 'Sugar Crystal',
          details: 'SKU: 1088',
          qty: 2,
          rate: 45,
        ),
      ],
      notes:
          "SAVE PAPER - GO GREEN\nGST AMOUNT INCLUDED IN MRP WHERE APPLICABLE\nNO RETURNS WITHOUT VALID BILL\nEXCHANGE WITHIN 24HRS FOR PERISHABLES",
      isThermal: true,
    );
  }
}
