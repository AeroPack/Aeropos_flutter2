import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class DesignSystemsIndiaTemplate extends InvoiceTemplate {
  @override
  String get id => 'default_a4';
  @override
  String get name => 'Design Systems India';
  @override
  String get industry => 'RETAIL';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'PROFESSIONAL';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => const Color(0xFF13a4ec);
  @override
  String get metadata => 'Modern Corporate Layout';
  @override
  String? get tag => 'DEFAULT A4';

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
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with bar
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (data.showLogo) ...[
                          if (logoImage != null) ...[
                            pw.Container(
                              width: 50,
                              height: 50,
                              child: pw.Image(logoImage),
                            ),
                            pw.SizedBox(width: 12),
                          ],
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              data.businessName.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: accentColor,
                                letterSpacing: 2,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            if (data.showBusinessAddress)
                              pw.Text(
                                data.businessAddress,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            pw.Text(
                              data.businessPhone,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    color: accentColor,
                    child: pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 48),

              // Client and Meta Row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: data.showClientContact
                        ? pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'CLIENT',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(
                                data.clientName,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              pw.Text(
                                data.clientAddress,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ],
                          )
                        : pw.SizedBox(),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _pdfMetaRow(
                          'DATE:',
                          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        ),
                        if (data.paymentMethod != null)
                          _pdfMetaRow(
                            'PAYMENT:',
                            data.paymentMethod!.toUpperCase(),
                          ),
                        _pdfMetaRow('INVOICE #:', 'DS-2024-001'),
                        _pdfMetaRow('DUE DATE:', 'Next 30 Days'),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 40),

              // Items Table
              pw.Table(
                border: pw.TableBorder(
                  bottom: pw.BorderSide(color: accentColor, width: 2),
                ),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: accentColor, width: 2),
                      ),
                    ),
                    children: [
                      _pdfHeaderCell('DESCRIPTION', pw.TextAlign.left),
                      _pdfHeaderCell('QTY', pw.TextAlign.center),
                      _pdfHeaderCell('RATE', pw.TextAlign.right),
                      _pdfHeaderCell('AMOUNT', pw.TextAlign.right),
                    ],
                  ),
                  ...data.items.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 10),
                          child: pw.Text(
                            item.desc,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        _pdfDataCell(item.qty.toString(), pw.TextAlign.center),
                        _pdfDataCell(
                          item.rate.toStringAsFixed(0),
                          pw.TextAlign.right,
                        ),
                        _pdfDataCell(
                          item.amount.toStringAsFixed(0),
                          pw.TextAlign.right,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 32),

              // Totals Table
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        _pdfTotalRow(
                          'Subtotal',
                          data.subtotal.toStringAsFixed(0),
                        ),
                        pw.SizedBox(height: 8),
                        if (data.showTaxBreakdown &&
                            data.taxLabel.toUpperCase() == 'GST') ...[
                          _pdfTotalRow(
                            'SGST (${(data.taxRate / 2)}%)',
                            (data.taxAmount / 2).toStringAsFixed(0),
                          ),
                          pw.SizedBox(height: 4),
                          _pdfTotalRow(
                            'CGST (${(data.taxRate / 2)}%)',
                            (data.taxAmount / 2).toStringAsFixed(0),
                          ),
                        ] else ...[
                          _pdfTotalRow(
                            '${data.taxLabel} (${data.taxRate}%)',
                            data.taxAmount.toStringAsFixed(0),
                          ),
                        ],
                        pw.SizedBox(height: 4),
                        pw.Divider(thickness: 1, color: accentColor),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'TOTAL',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            pw.Text(
                              '₹${data.total.toStringAsFixed(0)}',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 18,
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

              // Bank info and Thanks
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PAYMENT INFORMATION',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey500,
                        ),
                      ),
                      pw.Text(
                        'Bank: State Bank of India',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        'A/C No: 9928172615',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        'IFSC: SBIN00291',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Thank you for your business!',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _pdfMetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(width: 8),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.Widget _pdfHeaderCell(String label, pw.TextAlign align) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Text(
        label,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        textAlign: align,
      ),
    );
  }

  pw.Widget _pdfDataCell(
    String value,
    pw.TextAlign align, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 10,
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
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.showLogo &&
                      (data.logoBytes != null || data.logoPath != null)) ...[
                    buildLogoWidget(data, size: 50),
                    const SizedBox(width: 12),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.businessName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: data.themeColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (data.showBusinessAddress)
                        Text(
                          data.businessAddress,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      Text(
                        data.businessPhone,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: data.themeColor,
              child: const Text(
                'INVOICE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: data.showClientContact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CLIENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: data.themeColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.clientName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          data.clientAddress,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'DATE: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  if (data.paymentMethod != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'PAYMENT: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          data.paymentMethod!.toUpperCase(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'INVOICE #: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      Text('DS-2024-001', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: data.themeColor, width: 2),
                ),
              ),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'DESCRIPTION',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'QTY',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'RATE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'AMOUNT',
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.desc,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          item.details,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      item.qty.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      item.rate.toStringAsFixed(0),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      item.amount.toStringAsFixed(0),
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
            Table(
              columnWidths: const {
                0: FixedColumnWidth(100),
                1: FixedColumnWidth(100),
              },
              children: [
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(4),
                      child: Text('Subtotal'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        data.subtotal.toStringAsFixed(0),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                if (data.showTaxBreakdown &&
                    data.taxLabel.toUpperCase() == 'GST') ...[
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          'SGST (${(data.taxRate / 2).toStringAsFixed(1)}%)',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          (data.taxAmount / 2).toStringAsFixed(0),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          'CGST (${(data.taxRate / 2).toStringAsFixed(1)}%)',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          (data.taxAmount / 2).toStringAsFixed(0),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ] else
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text('${data.taxLabel} (${data.taxRate}%)'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          data.taxAmount.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                TableRow(
                  decoration: BoxDecoration(
                    color: data.themeColor.withValues(alpha: 0.05),
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        data.total.toStringAsFixed(0),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: data.themeColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 64),
        if (data.showNotes && data.notes.isNotEmpty) ...[
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'NOTES',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: data.themeColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.notes,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: "Design Systems India Pvt. Ltd.",
      businessEmail: "billing@dsindia.in",
      businessPhone: "+91 98765 43210",
      businessAddress: "402, Business Hub, BKC, Mumbai, Maharashtra 400051",
      gstin: "27AAAAA0000A1Z5",
      clientName: "Global Tech Solutions",
      clientAddress: "12th Floor, Prestige Tech Park, Bangalore, KA 560103",
      taxLabel: "GST",
      taxRate: 18,
      themeColorArgb: const Color(0xFF13a4ec).toARGB32(),
      fontFamily: "Inter",
      items: [
        InvoiceItem(
          id: '1',
          desc: 'UI/UX Design - Dashboard',
          details: 'High-fidelity prototypes for admin panel',
          qty: 40,
          rate: 1200,
        ),
        InvoiceItem(
          id: '2',
          desc: 'React Implementation',
          details: 'Frontend components development',
          qty: 25,
          rate: 1500,
        ),
      ],
      notes:
          "Please include the invoice number in your bank transfer description. Payment is due within 15 days of the invoice date. GST is applicable as per Indian tax laws. Thank you for your business!",
      isThermal: false,
    );
  }
}
