import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class TallyCreditNoteTemplate extends InvoiceTemplate {
  @override
  String get id => 'tally_credit_note_01';
  @override
  String get name => 'Standard Credit Note (ERP)';
  @override
  String get industry => 'GENERAL TRADING';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'TRADITIONAL';
  @override
  String get previewImagePath =>
      'assets/preview_templates/credit_note_template.png';
  @override
  Color get badgeColor => const Color(0xFF333333); // Dark Gray / Black
  @override
  String get metadata => 'A4 optimized, ERP Style Credit Note';
  @override
  String? get tag => 'CREDIT NOTE';

  // --- PDF GENERATION ---
  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();

    const borderColor = PdfColors.black;
    const double borderWidth = 1.0;
    final tableBorder = pw.TableBorder(
      verticalInside: const pw.BorderSide(color: borderColor, width: borderWidth),
      bottom: const pw.BorderSide(color: borderColor, width: borderWidth),
      top: const pw.BorderSide(color: borderColor, width: borderWidth),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // 1. Document Title
              pw.Text(
                'Credit Note',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),

              // 2. Main Outer Border Container
              pw.Expanded(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderColor, width: borderWidth),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Header Section (Split into Left and Right)
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Left Column (Company & Party)
                          pw.Expanded(
                            flex: 5,
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(right: pw.BorderSide(color: borderColor, width: borderWidth)),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  // Company Details
                                  pw.Container(
                                    padding: const pw.EdgeInsets.all(4),
                                    decoration: const pw.BoxDecoration(
                                      border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: borderWidth)),
                                    ),
                                    child: pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(data.businessName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                        pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 9)),
                                          pw.Text('GSTIN/UIN: ${data.gstin}', style: const pw.TextStyle(fontSize: 9)),
                                      ],
                                    ),
                                  ),
                                  // Party Details
                                  pw.Container(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text('Party :', style: const pw.TextStyle(fontSize: 9)),
                                        pw.Text(data.clientName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                        pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 9)),
                                        pw.Text('State Name      : Local, Code : 07', style: const pw.TextStyle(fontSize: 9)), // Dummy State
                                        pw.Text('GSTIN/UIN        : N/A', style: const pw.TextStyle(fontSize: 9)),
                                        pw.Text('Place of Supply : Local', style: const pw.TextStyle(fontSize: 9)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Right Column (References & Dates)
                          pw.Expanded(
                            flex: 5,
                            child: pw.Column(
                              children: [
                                // Row 1
                                pw.Row(
                                  children: [
                                    pw.Expanded(
                                      child: pw.Container(
                                        padding: const pw.EdgeInsets.all(4),
                                        decoration: const pw.BoxDecoration(
                                          border: pw.Border(
                                            right: pw.BorderSide(color: borderColor, width: borderWidth),
                                            bottom: pw.BorderSide(color: borderColor, width: borderWidth),
                                          ),
                                        ),
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text('Credit Note No.', style: const pw.TextStyle(fontSize: 8)),
                                            pw.Text(data.invoiceNumber, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    pw.Expanded(
                                      child: pw.Container(
                                        padding: const pw.EdgeInsets.all(4),
                                        decoration: const pw.BoxDecoration(
                                          border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: borderWidth)),
                                        ),
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text('Dated', style: const pw.TextStyle(fontSize: 8)),
                                            pw.Text('${data.invoiceDate.day}-${data.invoiceDate.month}-${data.invoiceDate.year}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Row 2
                                pw.Row(
                                  children: [
                                    pw.Expanded(
                                      child: pw.Container(
                                        padding: const pw.EdgeInsets.all(4),
                                        decoration: const pw.BoxDecoration(
                                          border: pw.Border(
                                            right: pw.BorderSide(color: borderColor, width: borderWidth),
                                            bottom: pw.BorderSide(color: borderColor, width: borderWidth),
                                          ),
                                        ),
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text("Buyer's Ref.", style: const pw.TextStyle(fontSize: 8)),
                                            pw.Text('230 dt. 31-Oct-2023', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    pw.Expanded(
                                      child: pw.Container(
                                        padding: const pw.EdgeInsets.all(4),
                                        decoration: const pw.BoxDecoration(
                                          border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: borderWidth)),
                                        ),
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text('Other Reference(s)', style: const pw.TextStyle(fontSize: 8)),
                                            pw.SizedBox(height: 12),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Empty Space
                                pw.Expanded(
                                  child: pw.Container(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Items Table
                      pw.Expanded(
                        child: pw.Table(
                          border: tableBorder,
                          columnWidths: const {
                            0: pw.FlexColumnWidth(0.5), // Sl No
                            1: pw.FlexColumnWidth(4.0), // Particulars
                            2: pw.FlexColumnWidth(1.2), // HSN/SAC
                            3: pw.FlexColumnWidth(1.0), // GST Rate
                            4: pw.FlexColumnWidth(1.2), // Quantity
                            5: pw.FlexColumnWidth(1.2), // Rate
                            6: pw.FlexColumnWidth(0.8), // per
                            7: pw.FlexColumnWidth(1.8), // Amount
                          },
                          children: [
                            // Header Row
                            pw.TableRow(
                              children: [
                                _pdfHeaderCell('Sl\nNo.'),
                                _pdfHeaderCell('Particulars'),
                                _pdfHeaderCell('HSN/SAC'),
                                _pdfHeaderCell('GST\nRate'),
                                _pdfHeaderCell('Quantity'),
                                _pdfHeaderCell('Rate'),
                                _pdfHeaderCell('per'),
                                _pdfHeaderCell('Amount'),
                              ],
                            ),
                            // Body Rows
                            ...data.items.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final item = entry.value;
                              return pw.TableRow(
                                children: [
                                  _pdfBodyCell('${index + 1}', align: pw.TextAlign.center),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                    child: pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(item.desc, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                        if (item.details.isNotEmpty)
                                          pw.Text(item.details, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                                      ],
                                    ),
                                  ),
                                  _pdfBodyCell(''), // HSN
                                  _pdfBodyCell(''), // GST Rate
                                  _pdfBodyCell(item.qty > 0 ? '${item.qty}' : '', align: pw.TextAlign.right),
                                  _pdfBodyCell(item.rate > 0 ? item.rate.toStringAsFixed(2) : '', align: pw.TextAlign.right),
                                  _pdfBodyCell(''), // per
                                  _pdfBodyCell(item.amount.toStringAsFixed(2), align: pw.TextAlign.right, isBold: true),
                                ],
                              );
                            }),
                            // Spacer Row to push total down
                            pw.TableRow(
                              children: [
                                pw.Expanded(child: pw.Container()),
                                pw.Expanded(child: pw.Container()),
                                pw.Expanded(child: pw.Container()),
                                pw.Expanded(child: pw.Container()),
                                pw.Expanded(child: pw.Container()),
                                pw.Expanded(child: pw.Container()),
                                pw.Expanded(child: pw.Container()),
                                pw.Expanded(child: pw.Container()),
                              ],
                            ),
                            // Total Row
                            pw.TableRow(
                              children: [
                                pw.Container(),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text('Total', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
                                ),
                                pw.Container(),
                                pw.Container(),
                                pw.Container(),
                                pw.Container(),
                                pw.Container(),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(data.total.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Footer Section
                      pw.Container(
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Amount in words
                            pw.Expanded(
                              flex: 6,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text('Amount Chargeable (in words)', style: const pw.TextStyle(fontSize: 8)),
                                        pw.Text('E & O.E', style: const pw.TextStyle(fontSize: 8)),
                                      ],
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      'INR ${data.total.toInt()} Only', // Simplified word conversion
                                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Signature Box
                            pw.Expanded(
                              flex: 4,
                              child: pw.Container(
                                height: 80,
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    left: pw.BorderSide(color: borderColor, width: borderWidth),
                                    top: pw.BorderSide(color: borderColor, width: borderWidth),
                                  ),
                                ),
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Column(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text('for ${data.businessName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                    pw.Text('Authorised Signatory', style: const pw.TextStyle(fontSize: 8)),
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
              ),

              pw.SizedBox(height: 4),
              pw.Text('This is a Computer Generated Document', style: const pw.TextStyle(fontSize: 8)),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  // --- PDF Helper Widgets ---
  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  pw.Widget _pdfBodyCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  // --- FLUTTER PREVIEW ---
  @override
  Widget buildFlutterPreview(InvoiceData data) {
    const borderColor = Colors.black;
    const double borderWidth = 1.0;
    final tableBorder = TableBorder(
      verticalInside: const BorderSide(color: borderColor, width: borderWidth),
      bottom: const BorderSide(color: borderColor, width: borderWidth),
      top: const BorderSide(color: borderColor, width: borderWidth),
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Document Title
          const Text(
            'Credit Note',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),

          // Main Wrapper
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                  // Header Block
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left (Company + Party)
                      Expanded(
                        flex: 5,
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(right: BorderSide(color: borderColor, width: borderWidth)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: borderColor, width: borderWidth)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data.businessName, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                    Text(data.businessAddress, style: const TextStyle(fontSize: 8)),
                                      Text('GSTIN/UIN: ${data.gstin}', style: const TextStyle(fontSize: 8)),
                                  ],
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Party :', style: TextStyle(fontSize: 8)),
                                    Text(data.clientName, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                    Text(data.clientAddress, style: const TextStyle(fontSize: 8)),
                                    const Text('State Name      : Local, Code : 07', style: TextStyle(fontSize: 8)),
                                    const Text('GSTIN/UIN        : N/A', style: TextStyle(fontSize: 8)),
                                    const Text('Place of Supply : Local', style: TextStyle(fontSize: 8)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right (Refs + Dates)
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: borderColor, width: borderWidth),
                                        bottom: BorderSide(color: borderColor, width: borderWidth),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Credit Note No.', style: TextStyle(fontSize: 7)),
                                        Text(data.invoiceNumber, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: borderColor, width: borderWidth)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Dated', style: TextStyle(fontSize: 7)),
                                        Text('${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: borderColor, width: borderWidth),
                                        bottom: BorderSide(color: borderColor, width: borderWidth),
                                      ),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Buyer's Ref.", style: TextStyle(fontSize: 7)),
                                        Text('230 dt. 31-Oct', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: borderColor, width: borderWidth)),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Other Reference(s)', style: TextStyle(fontSize: 7)),
                                        SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Table Body
                  Table(
                    border: tableBorder,
                    columnWidths: const {
                      0: FlexColumnWidth(0.5), 1: FlexColumnWidth(4.0), 2: FlexColumnWidth(1.2),
                      3: FlexColumnWidth(1.0), 4: FlexColumnWidth(1.2), 5: FlexColumnWidth(1.2),
                      6: FlexColumnWidth(0.8), 7: FlexColumnWidth(1.8),
                    },
                    children: [
                      // Headers
                      TableRow(
                        children: [
                          _flutterHeaderCell('Sl\nNo.'), _flutterHeaderCell('Particulars'),
                          _flutterHeaderCell('HSN/SAC'), _flutterHeaderCell('GST\nRate'),
                          _flutterHeaderCell('Quantity'), _flutterHeaderCell('Rate'),
                          _flutterHeaderCell('per'), _flutterHeaderCell('Amount'),
                        ],
                      ),
                      // Items
                      ...data.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return TableRow(
                          children: [
                            _flutterBodyCell('${index + 1}', align: TextAlign.center),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.desc, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                                  if (item.details.isNotEmpty)
                                    Text(item.details, style: const TextStyle(fontSize: 7, fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                            _flutterBodyCell(''), _flutterBodyCell(''),
                            _flutterBodyCell(item.qty > 0 ? '${item.qty}' : '', align: TextAlign.right),
                            _flutterBodyCell(item.rate > 0 ? item.rate.toStringAsFixed(2) : '', align: TextAlign.right),
                            _flutterBodyCell(''),
                            _flutterBodyCell(item.amount.toStringAsFixed(2), align: TextAlign.right, isBold: true),
                          ],
                        );
                      }),
                      // Spacer
                      TableRow(
                        children: List.generate(8, (index) => const SizedBox(height: 20)),
                      ),
                      // Total Row
                      TableRow(
                        children: [
                          const SizedBox(),
                          const Padding(
                            padding: EdgeInsets.all(4),
                            child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 8)),
                          ),
                          const SizedBox(), const SizedBox(), const SizedBox(), const SizedBox(), const SizedBox(),
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(data.total.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Footer Bottom Box
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Amount Chargeable (in words)', style: TextStyle(fontSize: 7)),
                                  Text('E & O.E', style: TextStyle(fontSize: 7)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('INR ${data.total.toInt()} Only', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Container(
                          height: 60,
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: borderColor, width: borderWidth),
                              top: BorderSide(color: borderColor, width: borderWidth),
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('for ${data.businessName}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                              const Text('Authorised Signatory', style: TextStyle(fontSize: 7)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 4),
          const Text('This is a Computer Generated Document', style: TextStyle(fontSize: 7, color: Colors.black54)),
        ],
      ),
    );
  }

  // --- Flutter Helper Widgets ---
  Widget _flutterHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 7, color: Colors.black87),
      ),
    );
  }

  Widget _flutterBodyCell(String text, {TextAlign align = TextAlign.left, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 8, color: Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  // --- DUMMY DATA ---
  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Mohan Apparels',
      businessAddress: 'A-404, Lajpat Nagar\nDelhi',
      businessPhone: '',
      businessEmail: '',
      gstin: '07ANDEP2345Q1Z1',
      clientName: 'Rakesh Garments',
      clientAddress: 'B-42, Sarojini Nagar, Delhi',
      clientPhone: '',
      invoiceNumber: '1',
      taxLabel: 'GST',
      taxRate: 0,
      themeColorArgb: 0xFF000000,
      fontFamily: 'Helvetica',
      items: [
        InvoiceItem(
          id: '1',
          desc: 'CGST',
          details: 'For CGST Charged @9% Instead of 6% in Invoice N.230',
          qty: 1,
          rate: 3000.00,
        ),
        InvoiceItem(
          id: '2',
          desc: 'SGST',
          details: 'For SGST Charged @9% Instead of 6% in Invoice N.230',
          qty: 1,
          rate: 3000.00,
        ),
      ],
      notes: '',
      isThermal: false,
    );
  }
}