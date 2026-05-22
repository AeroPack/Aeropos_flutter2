import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class QuotationBusinessTemplate extends InvoiceTemplate {
  @override
  String get id => 'quotation_business_01';
  @override
  String get name => 'Business Quotation Format';
  @override
  String get industry => 'BUSINESS';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'PROFESSIONAL';
  @override
  String get previewImagePath =>
      'assets/preview_templates/proforma_invoice_a4_template.png';
  @override
  Color get badgeColor => Colors.deepPurple;
  @override
  String get metadata => 'Quotation layout with color blocks';
  @override
  String? get tag => 'QUOTATION';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();
    
    // Theme colors
    final accent = PdfColor.fromInt(data.themeColorArgb);
    // Approximate a light shade for the background blocks by using an RGB blend
    final lightAccent = PdfColor(
      accent.red + (1.0 - accent.red) * 0.9,
      accent.green + (1.0 - accent.green) * 0.9,
      accent.blue + (1.0 - accent.blue) * 0.9,
    );
    final borderColor = PdfColors.grey400;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return wrapWithFont(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top Header Block
                pw.Container(
                  width: double.infinity,
                  color: accent,
                  padding: const pw.EdgeInsets.symmetric(vertical: 12),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Quotation Format',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),

                // Company Info
                pw.Text('Company Name: ${data.businessName}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Address: ${data.businessAddress}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),
                pw.Text('Phone No: ${data.businessPhone}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Email Id: ${data.businessEmail}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('GSTIN No: ${data.gstin}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 12),

                // Divider
                pw.Divider(color: accent, thickness: 2),
                pw.SizedBox(height: 12),

                // Bill To & Quote Info
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Bill To:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('Name: ${data.clientName}', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Address: ${data.clientAddress}', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 8),
                          pw.Text('Contact No: ${data.clientPhone}', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Email Id: ${data.clientName.toLowerCase().replaceAll(' ', '')}@email.com', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('GSTIN No: ', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Quotation No: ${data.invoiceNumber.isNotEmpty ? data.invoiceNumber : "QT-001"}', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 4),
                          pw.Text('Date: ${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 8),
                          pw.Text('Payment Due Date: Immediate', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Valid For: 30 Days', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // Quote prepared by bar
                pw.Container(
                  width: double.infinity,
                  color: lightAccent,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(
                    'Quote prepared by: Admin',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ),

                // Items Table
                pw.Table(
                  border: pw.TableBorder.all(color: borderColor, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(6),
                    1: pw.FlexColumnWidth(34),
                    2: pw.FlexColumnWidth(8),
                    3: pw.FlexColumnWidth(10),
                    4: pw.FlexColumnWidth(14),
                    5: pw.FlexColumnWidth(8),
                    6: pw.FlexColumnWidth(20),
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: accent),
                      children: [
                        _thPdf('Sl. No.', accent),
                        _thPdf('Description', accent),
                        _thPdf('Unit', accent),
                        _thPdf('Quantity', accent),
                        _thPdf('Price/Unit', accent),
                        _thPdf('GST (%)', accent),
                        _thPdf('Amount', accent),
                      ],
                    ),
                    // Item Rows
                    ...data.items.asMap().entries.map((e) {
                      final idx = e.key + 1;
                      final item = e.value;
                      return pw.TableRow(
                        children: [
                          _tdPdf(idx.toString(), align: pw.TextAlign.center),
                          _tdPdf(item.desc),
                          _tdPdf('PCS', align: pw.TextAlign.center),
                          _tdPdf(item.qty.toString(), align: pw.TextAlign.center),
                          _tdPdf(item.rate.toStringAsFixed(2), align: pw.TextAlign.right),
                          _tdPdf('${data.taxRate}', align: pw.TextAlign.center),
                          _tdPdf(item.amount.toStringAsFixed(2), align: pw.TextAlign.right),
                        ],
                      );
                    }),
                    // Adding one empty row for formatting parity with image
                    if (data.items.length < 5)
                      pw.TableRow(
                        children: List.generate(7, (index) => _tdPdf(' ')),
                      ),
                  ],
                ),

                // Total Bar (Merged columns mapped by splitting table widths 80% to 20%)
                pw.Table(
                  border: pw.TableBorder(
                    left: pw.BorderSide(color: borderColor, width: 0.5),
                    right: pw.BorderSide(color: borderColor, width: 0.5),
                    bottom: pw.BorderSide(color: borderColor, width: 0.5),
                    verticalInside: pw.BorderSide(color: borderColor, width: 0.5),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(80),
                    1: pw.FlexColumnWidth(20),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: accent),
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6),
                          alignment: pw.Alignment.center,
                          child: pw.Text('Total', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(data.subtotal.toStringAsFixed(2), style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),

                // Summary & Footer Section
                pw.Table(
                  border: pw.TableBorder(
                    left: pw.BorderSide(color: borderColor, width: 0.5),
                    right: pw.BorderSide(color: borderColor, width: 0.5),
                    bottom: pw.BorderSide(color: borderColor, width: 0.5),
                    horizontalInside: pw.BorderSide(color: borderColor, width: 0.5),
                    verticalInside: pw.BorderSide(color: borderColor, width: 0.5),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(80),
                    1: pw.FlexColumnWidth(20),
                  },
                  children: [
                    // Amount in words and Final Amount block
                    pw.TableRow(
                      children: [
                        pw.Container(
                          height: 64,
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Amount in words:\nRupees ${data.total.toInt()} Only', style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Container(
                              height: 20,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: pw.Text('Discount:', style: const pw.TextStyle(fontSize: 9)),
                            ),
                            pw.Container(
                              height: 20,
                              color: accent,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: pw.Text('Final Amount', style: pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                            ),
                            pw.Container(
                              height: 24,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(data.total.toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Special notes and Blank box
                    pw.TableRow(
                      children: [
                        pw.Container(
                          height: 45,
                          padding: const pw.EdgeInsets.all(8),
                          color: lightAccent,
                          child: pw.Text('Special notes and instructions\n${data.notes}', style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Container(
                          height: 45,
                          color: lightAccent,
                        ),
                      ],
                    ),
                    // Declarations and Signature line
                    pw.TableRow(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          color: accent,
                          child: pw.Text('Declaration', style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          color: accent,
                          alignment: pw.Alignment.center,
                          child: pw.Text('Seal & Signature', style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            data,
          );
        },
      ),
    );
    return pdf;
  }

  pw.Widget _thPdf(String text, PdfColor bg) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _tdPdf(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : (align == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    final accent = Color(data.themeColorArgb);
    // Mimic the lightened background block color natively
    final lightAccent = Color.alphaBlend(accent.withValues(alpha: 0.1), Colors.white);
    final borderColor = Colors.grey.shade400;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            color: accent,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: const Text(
              'Quotation Format',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          // Company Details
          Text('Company Name: ${data.businessName}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Text('Address: ${data.businessAddress}', style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 8),
          Text('Phone No: ${data.businessPhone}', style: const TextStyle(fontSize: 10)),
          Text('Email Id: ${data.businessEmail}', style: const TextStyle(fontSize: 10)),
          Text('GSTIN No: ${data.gstin}', style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 12),

          Divider(color: accent, thickness: 2, height: 2),
          const SizedBox(height: 12),

          // Bill To & Quote Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bill To:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Name: ${data.clientName}', style: const TextStyle(fontSize: 10)),
                    Text('Address: ${data.clientAddress}', style: const TextStyle(fontSize: 10)),
                    const SizedBox(height: 8),
                    Text('Contact No: ${data.clientPhone}', style: const TextStyle(fontSize: 10)),
                    Text('Email Id: ${data.clientName.toLowerCase().replaceAll(' ', '')}@email.com', style: const TextStyle(fontSize: 10)),
                    const Text('GSTIN No: ', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quotation No: ${data.invoiceNumber.isNotEmpty ? data.invoiceNumber : "QT-001"}', style: const TextStyle(fontSize: 10)),
                    const SizedBox(height: 4),
                    Text('Date: ${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', style: const TextStyle(fontSize: 10)),
                    const SizedBox(height: 8),
                    const Text('Payment Due Date: Immediate', style: TextStyle(fontSize: 10)),
                    const Text('Valid For: 30 Days', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Prepared by
          Container(
            width: double.infinity,
            color: lightAccent,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: const Text(
              'Quote prepared by: Admin',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),

          // Items Table
          Table(
            border: TableBorder.all(color: borderColor, width: 0.5),
            columnWidths: const {
              0: FlexColumnWidth(6),
              1: FlexColumnWidth(34),
              2: FlexColumnWidth(8),
              3: FlexColumnWidth(10),
              4: FlexColumnWidth(14),
              5: FlexColumnWidth(8),
              6: FlexColumnWidth(20),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: accent),
                children: [
                  _thFlutter('Sl. No.', accent),
                  _thFlutter('Description', accent),
                  _thFlutter('Unit', accent),
                  _thFlutter('Quantity', accent),
                  _thFlutter('Price/Unit', accent),
                  _thFlutter('GST (%)', accent),
                  _thFlutter('Amount', accent),
                ],
              ),
              ...data.items.asMap().entries.map((e) {
                final idx = e.key + 1;
                final item = e.value;
                return TableRow(
                  children: [
                    _tdFlutter(idx.toString(), align: TextAlign.center),
                    _tdFlutter(item.desc),
                    _tdFlutter('PCS', align: TextAlign.center),
                    _tdFlutter(item.qty.toString(), align: TextAlign.center),
                    _tdFlutter(item.rate.toStringAsFixed(2), align: TextAlign.right),
                    _tdFlutter('${data.taxRate}', align: TextAlign.center),
                    _tdFlutter(item.amount.toStringAsFixed(2), align: TextAlign.right),
                  ],
                );
              }),
              if (data.items.length < 5)
                TableRow(
                  children: List.generate(7, (index) => _tdFlutter(' ')),
                ),
            ],
          ),

          // Total Bar
          Table(
            border: TableBorder(
              left: BorderSide(color: borderColor, width: 0.5),
              right: BorderSide(color: borderColor, width: 0.5),
              bottom: BorderSide(color: borderColor, width: 0.5),
              verticalInside: BorderSide(color: borderColor, width: 0.5),
            ),
            columnWidths: const {
              0: FlexColumnWidth(80),
              1: FlexColumnWidth(20),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: accent),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    child: const Text('Total', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    alignment: Alignment.centerRight,
                    child: Text(data.subtotal.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),

          // Footer Details Table
          Table(
            border: TableBorder(
              left: BorderSide(color: borderColor, width: 0.5),
              right: BorderSide(color: borderColor, width: 0.5),
              bottom: BorderSide(color: borderColor, width: 0.5),
              horizontalInside: BorderSide(color: borderColor, width: 0.5),
              verticalInside: BorderSide(color: borderColor, width: 0.5),
            ),
            columnWidths: const {
              0: FlexColumnWidth(80),
              1: FlexColumnWidth(20),
            },
            children: [
              TableRow(
                children: [
                  Container(
                    height: 64,
                    padding: const EdgeInsets.all(8),
                    child: Text('Amount in words:\nRupees ${data.total.toInt()} Only', style: const TextStyle(fontSize: 10)),
                  ),
                  SizedBox(
                    height: 64,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: const Text('Discount:', style: TextStyle(fontSize: 9)),
                        ),
                        Container(
                          height: 20,
                          color: accent,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: const Text('Final Amount', style: TextStyle(color: Colors.white, fontSize: 9)),
                        ),
                        Container(
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          alignment: Alignment.centerRight,
                          child: Text(data.total.toStringAsFixed(2), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  Container(
                    height: 45,
                    padding: const EdgeInsets.all(8),
                    color: lightAccent,
                    child: Text('Special notes and instructions\n${data.notes}', style: const TextStyle(fontSize: 9)),
                  ),
                  Container(
                    height: 45,
                    color: lightAccent,
                  ),
                ],
              ),
              TableRow(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: accent,
                    child: const Text('Declaration', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: accent,
                    alignment: Alignment.center,
                    child: const Text('Seal & Signature', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thFlutter(String text, Color bg) {
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _tdFlutter(String text, {TextAlign align = TextAlign.left}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: align == TextAlign.center
          ? Alignment.center
          : (align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft),
      child: Text(text, style: const TextStyle(fontSize: 9)),
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Apex Industries Ltd.',
      businessEmail: 'info@apexindustries.com',
      businessPhone: '+91 98765 43210',
      businessAddress: 'Sector 45, Industrial Estate, City Center',
      gstin: '29ABCDE1234F1Z5',
      clientName: 'Global Corp Solutions',
      clientAddress: 'Tech Park Blvd, Business District',
      clientPhone: '8899001122',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: Colors.deepPurple.toARGB32(),
      fontFamily: 'Roboto',
      items: [
        InvoiceItem(id: '1', desc: 'Custom Machinery Parts', details: '', qty: 50, rate: 850),
        InvoiceItem(id: '2', desc: 'Labor and Assembly', details: '', qty: 10, rate: 2500),
        InvoiceItem(id: '3', desc: 'Quality Check Inspection', details: '', qty: 1, rate: 5000),
      ],
      notes: 'This quotation is valid for 30 days from issue.\nInstallation charges not included.',
      isThermal: false,
    );
  }
}