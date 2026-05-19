import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class RetailBasicTemplate extends InvoiceTemplate {
  @override
  String get id => '1';
  @override
  String get name => 'Retail Basic';
  @override
  String get industry => 'RETAIL';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'COMPACT';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1586281380349-632531db7ed4?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => Colors.blue;
  @override
  String get metadata => 'Standard Retail Format';
  @override
  String? get tag => 'POPULAR';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();

    final accentColor = PdfColor.fromInt(data.themeColorArgb);

    pw.MemoryImage? logoImage;
    if (data.showLogo && data.logoBytes != null) {
      logoImage = pw.MemoryImage(data.logoBytes!);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (data.showLogo) ...[
                        if (logoImage != null) ...[
                          pw.Container(
                            width: 60,
                            height: 60,
                            child: pw.Image(logoImage),
                          ),
                          pw.SizedBox(width: 12),
                        ],
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            data.businessName,
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          if (data.showBusinessAddress)
                            pw.Text(
                              data.businessAddress,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          pw.Text(
                            data.businessPhone,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey300,
                    ),
                  ),
                ],
              ),

              pw.Divider(height: 48, thickness: 1, color: PdfColors.grey200),

              // Billing Info
              if (data.showClientContact) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILL TO',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey500,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          data.clientName,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          data.clientAddress,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        ),
                        pw.Text('Invoice #: INV-001'),
                        if (data.paymentMethod != null)
                          pw.Text(
                            'Payment: ${data.paymentMethod!.toUpperCase()}',
                          ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        ),
                        pw.Text('Invoice #: INV-001'),
                        if (data.paymentMethod != null)
                          pw.Text(
                            'Payment: ${data.paymentMethod!.toUpperCase()}',
                          ),
                      ],
                    ),
                  ],
                ),
              ],

              pw.SizedBox(height: 32),

              // Items Table
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                    color: PdfColors.grey100,
                    width: 0.5,
                  ),
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                    children: [
                      _pdfCell(
                        'DESCRIPTION',
                        isHeader: true,
                        align: pw.TextAlign.left,
                      ),
                      _pdfCell(
                        'QTY',
                        isHeader: true,
                        align: pw.TextAlign.center,
                      ),
                      _pdfCell(
                        'RATE',
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                      _pdfCell(
                        'TOTAL',
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  ...data.items.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.desc,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              if (item.details.isNotEmpty)
                                pw.Text(
                                  item.details,
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _pdfCell(
                          item.qty.toString(),
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          item.rate.toStringAsFixed(2),
                          align: pw.TextAlign.right,
                        ),
                        _pdfCell(
                          item.amount.toStringAsFixed(2),
                          align: pw.TextAlign.right,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 32),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.SizedBox(
                    width: 200,
                    child: pw.Column(
                      children: [
                        _pdfTotalRow(
                          'Subtotal',
                          data.subtotal.toStringAsFixed(2),
                        ),
                        pw.SizedBox(height: 8),
                        if (data.showTaxBreakdown &&
                            data.taxLabel.toUpperCase() == 'GST') ...[
                          _pdfTotalRow(
                            'SGST (${(data.taxRate / 2).toStringAsFixed(1)}%)',
                            (data.taxAmount / 2).toStringAsFixed(2),
                          ),
                          pw.SizedBox(height: 4),
                          _pdfTotalRow(
                            'CGST (${(data.taxRate / 2).toStringAsFixed(1)}%)',
                            (data.taxAmount / 2).toStringAsFixed(2),
                          ),
                        ] else ...[
                          _pdfTotalRow(
                            '${data.taxLabel} (${data.taxRate}%)',
                            data.taxAmount.toStringAsFixed(2),
                          ),
                        ],
                        pw.Divider(
                          height: 24,
                          thickness: 1,
                          color: PdfColors.grey200,
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Total',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            pw.Text(
                              data.total.toStringAsFixed(2),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 16,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              if (data.showNotes && data.notes.isNotEmpty) ...[
                pw.Divider(color: PdfColors.grey200),
                pw.SizedBox(height: 8),
                pw.Text(
                  'NOTES',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.Text(data.notes, style: const pw.TextStyle(fontSize: 10)),
              ],
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 10,
          fontWeight: (isHeader || isBold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey500 : PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _pdfTotalRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (data.showLogo &&
                    (data.logoBytes != null || data.logoPath != null)) ...[
                  buildLogoWidget(data, size: 60),
                  const SizedBox(width: 12),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.businessName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: data.themeColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (data.showBusinessAddress)
                      Text(
                        data.businessAddress,
                        style: const TextStyle(fontSize: 12),
                      ),
                    Text(
                      data.businessPhone,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const Text(
              'INVOICE',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w100),
            ),
          ],
        ),
        const Divider(height: 48, thickness: 2),
        if (data.showClientContact) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BILL TO',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.clientName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data.clientAddress,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  ),
                  const Text('Invoice #: INV-001'),
                  if (data.paymentMethod != null)
                    Text('Payment: ${data.paymentMethod!.toUpperCase()}'),
                ],
              ),
            ],
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  ),
                  const Text('Invoice #: INV-001'),
                  if (data.paymentMethod != null)
                    Text('Payment: ${data.paymentMethod!.toUpperCase()}'),
                ],
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),
        Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade200),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade50),
              children: const [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'DESCRIPTION',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'QTY',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'RATE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            ...data.items.map(
              (item) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.desc,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          item.details,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      item.qty.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      item.rate.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      item.amount.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: 200,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text(data.subtotal.toStringAsFixed(2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (data.showTaxBreakdown &&
                      data.taxLabel.toUpperCase() == 'GST') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SGST (${(data.taxRate / 2).toStringAsFixed(1)}%)',
                        ),
                        Text((data.taxAmount / 2).toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CGST (${(data.taxRate / 2).toStringAsFixed(1)}%)',
                        ),
                        Text((data.taxAmount / 2).toStringAsFixed(2)),
                      ],
                    ),
                  ] else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${data.taxLabel} (${data.taxRate}%)'),
                        Text(data.taxAmount.toStringAsFixed(2)),
                      ],
                    ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        data.total.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: data.themeColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        if (data.showNotes && data.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'NOTES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.notes,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ],
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: "Retail Basic Store",
      businessEmail: "store@retailbasic.com",
      businessPhone: "+91 99999 88888",
      businessAddress: "Shop No 5, Market Area, City Center",
      gstin: "27RETAIL1234Z1Z",
      clientName: "Customer",
      clientAddress: "Nearby Street",
      taxLabel: "GST",
      taxRate: 18,
      themeColorArgb: Colors.blue.toARGB32(),
      fontFamily: "Inter",
      items: [
        InvoiceItem(
          id: '1',
          desc: 'Basic T-Shirt',
          details: 'Size: L, Color: Blue',
          qty: 2,
          rate: 499,
        ),
        InvoiceItem(
          id: '2',
          desc: 'Denim Jeans',
          details: 'Size: 32',
          qty: 1,
          rate: 1299,
        ),
      ],
      notes: "Thank you for shopping with us!\nReturns accepted within 7 days.",
      isThermal: false,
    );
  }
}
