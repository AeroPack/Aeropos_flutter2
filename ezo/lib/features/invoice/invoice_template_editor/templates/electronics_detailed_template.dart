import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class ElectronicsDetailedTemplate extends InvoiceTemplate {
  @override
  String get id => 'electronics_8';
  @override
  String get name => 'Electronics Detailed Invoice';
  @override
  String get industry => 'ELECTRONICS';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'DETAILED';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => Colors.grey.shade700;
  @override
  String get metadata => 'Specs & IMEI Columns';
  @override
  String? get tag => 'PRO GRADE';

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
              // Header with large INVOICE text
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (data.showLogo) ...[
                        if (logoImage != null)
                          pw.Container(
                            width: 48,
                            height: 48,
                            child: pw.Image(logoImage),
                          )
                        else
                          pw.Container(
                            width: 48,
                            height: 48,
                            decoration: pw.BoxDecoration(
                              color: accentColor,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                'E',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                          ),
                        pw.SizedBox(height: 16),
                      ],
                      pw.Text(
                        data.businessName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (data.showBusinessAddress)
                        pw.Text(
                          data.businessAddress,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 40,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey100,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'INV-2024-001',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (data.paymentMethod != null)
                        pw.Text(
                          'PAYMENT: ${data.paymentMethod!.toUpperCase()}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      pw.Text(
                        '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (data.showClientContact) ...[
                pw.SizedBox(height: 40),
                pw.Row(
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
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          data.clientAddress,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
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
                  bottom: pw.BorderSide(color: PdfColors.grey900, width: 1.5),
                ),
                children: [
                  pw.TableRow(
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
                          padding: const pw.EdgeInsets.symmetric(vertical: 12),
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
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey400,
                                  ),
                                ),
                            ],
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

              pw.SizedBox(height: 24),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.SizedBox(
                    width: 180,
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
                            'SGST (${(data.taxRate / 2).toStringAsFixed(1)}%)',
                            (data.taxAmount / 2).toStringAsFixed(0),
                          ),
                          pw.SizedBox(height: 4),
                          _pdfTotalRow(
                            'CGST (${(data.taxRate / 2).toStringAsFixed(1)}%)',
                            (data.taxAmount / 2).toStringAsFixed(0),
                          ),
                        ] else ...[
                          _pdfTotalRow(
                            '${data.taxLabel} (${data.taxRate}%)',
                            data.taxAmount.toStringAsFixed(0),
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

              // Footer notes / terms
              if (data.showNotes && data.notes.isNotEmpty) ...[
                pw.Text(
                  'TERMS & CONDITIONS',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  data.notes,
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _pdfHeaderCell(String label, pw.TextAlign align) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
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
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
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
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
        ),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 500;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data.showLogo) ...[
                        if (data.logoBytes != null || data.logoPath != null)
                          buildLogoWidget(data, size: 48)
                        else
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: data.themeColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'E',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        data.businessName,
                        style: TextStyle(
                          fontSize: isSmall ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (data.showBusinessAddress)
                        Text(
                          data.businessAddress,
                          style: TextStyle(
                            fontSize: isSmall ? 10 : 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'INVOICE',
                      style: TextStyle(
                        fontSize: isSmall ? 24 : 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade100,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'INV-2024-001',
                      style: TextStyle(
                        fontSize: isSmall ? 12 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (data.paymentMethod != null)
                      Text(
                        'PAYMENT: ${data.paymentMethod!.toUpperCase()}',
                        style: TextStyle(
                          fontSize: isSmall ? 10 : 12,
                          fontWeight: FontWeight.bold,
                          color: data.themeColor,
                        ),
                      ),
                    Text(
                      '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
                      style: TextStyle(
                        fontSize: isSmall ? 10 : 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (data.showClientContact) ...[
              const SizedBox(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BILL TO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.clientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    data.clientAddress,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            // Rest of implementation... (collapsed for brevity but keeping structure)
            _buildItemTable(data, isSmall),
            const SizedBox(height: 32),
            _buildTotals(data),
            if (data.showNotes && data.notes.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'TERMS & CONDITIONS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
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
      },
    );
  }

  Widget _buildItemTable(InvoiceData data, bool isSmall) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade900, width: 2),
            ),
          ),
          children: const [
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'DESCRIPTION',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'QTY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'RATE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'AMOUNT',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (!isSmall)
                      Text(
                        item.details,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(item.qty.toString(), textAlign: TextAlign.center),
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotals(InvoiceData data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 200,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(color: Colors.grey)),
                  Text(data.subtotal.toStringAsFixed(0)),
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
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text((data.taxAmount / 2).toStringAsFixed(0)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CGST (${(data.taxRate / 2).toStringAsFixed(1)}%)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text((data.taxAmount / 2).toStringAsFixed(0)),
                  ],
                ),
              ] else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${data.taxLabel} (${data.taxRate}%)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(data.taxAmount.toStringAsFixed(0)),
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
                    data.total.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: data.themeColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: "ElectroTech Solutions",
      businessEmail: "contact@electrotech.com",
      businessPhone: "+91 80 1234 5678",
      businessAddress:
          "123 Silicon Valley Road, Tech Park, Bangalore, KA - 560001",
      gstin: "29AAAAA0000A1Z5",
      clientName: "Walk-in Customer",
      clientAddress: "Bangalore, India",
      taxLabel: "GST",
      taxRate: 18,
      themeColorArgb: Colors.black.toARGB32(),
      fontFamily: "Mono",
      items: [
        InvoiceItem(
          id: '1',
          desc: 'Logitech MX Master 3S',
          details: 'SN: MX29384756',
          qty: 1,
          rate: 8500,
        ),
        InvoiceItem(
          id: '2',
          desc: 'USB-C Hub 7-in-1',
          details: 'SN: UH992102',
          qty: 2,
          rate: 1200,
        ),
      ],
      notes:
          "Warranty Terms:\n1. 1-year manufacturer warranty from date of invoice.\n2. Physical damage or water exposure voids warranty.",
      isThermal: false,
    );
  }
}
