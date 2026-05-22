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
      'assets/preview_templates/electronics_detailed_template.png';
  @override
  Color get badgeColor => Colors.grey.shade700;
  @override
  String get metadata => 'Structured Grid Layout';
  @override
  String? get tag => 'PRO GRADE';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();
    
    // Core Colors
    final accentColor = PdfColor.fromInt(data.themeColorArgb);
    // Calculating a lighter background by simulating ~15% opacity over white
    final lightAccentColor = PdfColor(
      accentColor.red, 
      accentColor.green, 
      accentColor.blue, 
      0.15
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return wrapWithFont(
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP HEADER (BILL)
                  pw.Container(
                    color: lightAccentColor,
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text(
                      'BILL',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: accentColor,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  pw.Divider(height: 1.5, thickness: 1.5, color: PdfColors.black),

                  // 2. BUSINESS DETAILS
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          data.businessName,
                          style: pw.TextStyle(
                            color: accentColor,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        if (data.showBusinessAddress)
                          pw.Text('Address: ${data.businessAddress}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Email: ${data.businessEmail}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Contact Number: ${data.businessPhone}', style: const pw.TextStyle(fontSize: 10)),
                        if (data.gstin.isNotEmpty)
                          pw.Text('GSTIN NO.: ${data.gstin}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),

                  // 3. INVOICE INFO STRIP
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border.symmetric(horizontal: pw.BorderSide(width: 1.5)),
                    ),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'INVOICE NO. : INV-2024-001',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Row(
                              children: [
                                pw.Text('Invoice Date: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                pw.Text('${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', style: const pw.TextStyle(fontSize: 10)),
                              ]
                            ),
                            pw.Row(
                              children: [
                                pw.Text('Due Date: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                pw.Text('Within 30 days', style: const pw.TextStyle(fontSize: 10)),
                              ]
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 4. BILL TO / SHIP TO
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 1.5)),
                    ),
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('BILL TO', style: pw.TextStyle(color: accentColor, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                              pw.SizedBox(height: 4),
                              pw.Text(data.clientName, style: const pw.TextStyle(fontSize: 10)),
                              pw.Text('Customer Info', style: const pw.TextStyle(fontSize: 10)),
                              pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 10)),
                              pw.SizedBox(height: 12),
                              pw.Text('GSTIN NO.: ${data.clientGstin.isNotEmpty ? data.clientGstin : "N/A"}', style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('SHIP TO', style: pw.TextStyle(color: accentColor, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                              pw.SizedBox(height: 4),
                              pw.Text(data.clientName, style: const pw.TextStyle(fontSize: 10)),
                              pw.Text('Customer Info', style: const pw.TextStyle(fontSize: 10)),
                              pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 10)),
                              pw.SizedBox(height: 12),
                              pw.Text('GSTIN NO.: ${data.clientGstin.isNotEmpty ? data.clientGstin : "N/A"}', style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 5. ITEMS TABLE
                  pw.Expanded(
                    child: pw.Table(
                      border: pw.TableBorder.symmetric(
                        inside: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(4),
                        1: const pw.FlexColumnWidth(1.2),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: accentColor),
                          children: [
                            _pdfHeaderCell('DESCRIPTION', pw.TextAlign.left),
                            _pdfHeaderCell('QTY', pw.TextAlign.center),
                            _pdfHeaderCell('UNIT PRICE', pw.TextAlign.right),
                            _pdfHeaderCell('TOTAL', pw.TextAlign.right),
                          ],
                        ),
                        ...data.items.map(
                          (item) => pw.TableRow(
                            children: [
                              _pdfDataCell(
                                item.details.isNotEmpty 
                                  ? '${item.desc}\n(${item.details})' 
                                  : item.desc, 
                                pw.TextAlign.left
                              ),
                              _pdfDataCell(item.qty.toString(), pw.TextAlign.center),
                              _pdfDataCell(item.rate.toStringAsFixed(2), pw.TextAlign.right),
                              _pdfDataCell(item.amount.toStringAsFixed(2), pw.TextAlign.right),
                            ],
                          ),
                        ),
                        // Pad empty space to fill table
                        for (int i = 0; i < (10 - data.items.length).clamp(0, 10); i++)
                          pw.TableRow(
                            children: [
                              _pdfDataCell(' ', pw.TextAlign.left),
                              _pdfDataCell(' ', pw.TextAlign.center),
                              _pdfDataCell(' ', pw.TextAlign.right),
                              _pdfDataCell(' ', pw.TextAlign.right),
                            ]
                          )
                      ],
                    ),
                  ),

                  // 6. FOOTER (Terms, Payment, Totals)
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(width: 1.5)),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch, // To match heights
                      children: [
                        // Left Footer Section
                        pw.Expanded(
                          flex: 5,
                          child: pw.Container(
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(right: pw.BorderSide(width: 1.5)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Terms & Instructions', style: pw.TextStyle(color: accentColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                      pw.SizedBox(height: 4),
                                      pw.Text(data.notes.isNotEmpty ? data.notes : 'No terms specified.', style: const pw.TextStyle(fontSize: 9)),
                                    ],
                                  ),
                                ),
                                pw.Spacer(),
                                pw.Container(
                                  width: double.infinity,
                                  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1.5))),
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.RichText(
                                        text: pw.TextSpan(
                                          children: [
                                            pw.TextSpan(text: 'Payment Mode: ', style: pw.TextStyle(color: accentColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                            pw.TextSpan(text: data.paymentMethod ?? 'UPI', style: const pw.TextStyle(fontSize: 10)),
                                          ]
                                        )
                                      ),
                                      pw.SizedBox(height: 30),
                                      pw.Align(
                                        alignment: pw.Alignment.bottomRight,
                                        child: pw.Text('Seal & Signature', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))
                                      )
                                    ]
                                  )
                                )
                              ],
                            )
                          ),
                        ),
                        
                        // Right Footer Section (Totals)
                        pw.Expanded(
                          flex: 4,
                          child: pw.Table(
                            border: pw.TableBorder.symmetric(inside: const pw.BorderSide(width: 1)),
                            columnWidths: {
                              0: const pw.FlexColumnWidth(2),
                              1: const pw.FlexColumnWidth(1),
                            },
                            children: [
                              _pdfFooterTotalsRow('SUBTOTAL', data.subtotal.toStringAsFixed(2)),
                              _pdfFooterTotalsRow('DISCOUNT', '0.00'),
                              if (data.showTaxBreakdown && data.taxLabel.toUpperCase() == 'GST') ...[
                                _pdfFooterTotalsRow('CGST @ ${(data.taxRate / 2).toStringAsFixed(1)}%', (data.taxAmount / 2).toStringAsFixed(2)),
                                _pdfFooterTotalsRow('SGST @ ${(data.taxRate / 2).toStringAsFixed(1)}%', (data.taxAmount / 2).toStringAsFixed(2)),
                              ] else ...[
                                _pdfFooterTotalsRow('${data.taxLabel} @ ${data.taxRate}%', data.taxAmount.toStringAsFixed(2)),
                              ],
                              _pdfFooterTotalsRow('Received Balance:', '0.00'),
                              pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    child: pw.Text('Balance Due', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: accentColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                  ),
                                  pw.Container(
                                    color: lightAccentColor,
                                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    child: pw.Text(data.total.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)),
                                  ),
                                ]
                              ),
                              pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                    child: pw.Text('GRAND TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: accentColor, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                  ),
                                  pw.Container(
                                    color: lightAccentColor,
                                    padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                    child: pw.Text(data.total.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                  ),
                                ]
                              ),
                            ]
                          )
                        ),
                      ],
                    ),
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

  pw.TableRow _pdfFooterTotalsRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: pw.Text(label, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: pw.Text(value, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
        ),
      ]
    );
  }

  pw.Widget _pdfHeaderCell(String label, pw.TextAlign align) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        label,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        textAlign: align,
      ),
    );
  }

  pw.Widget _pdfDataCell(String value, pw.TextAlign align) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        value,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: align,
      ),
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    final accentColor = data.themeColor;
    final lightAccentColor = accentColor.withValues(alpha: 0.15);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.5),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP HEADER (BILL)
          Container(
            color: lightAccentColor,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'BILL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accentColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const Divider(height: 1.5, thickness: 1.5, color: Colors.black),

          // 2. BUSINESS DETAILS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.businessName,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (data.showBusinessAddress)
                  Text('Address: ${data.businessAddress}', style: const TextStyle(fontSize: 11)),
                Text('Email: ${data.businessEmail}', style: const TextStyle(fontSize: 11)),
                Text('Contact Number: ${data.businessPhone}', style: const TextStyle(fontSize: 11)),
                if (data.gstin.isNotEmpty)
                  Text('GSTIN NO.: ${data.gstin}', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),

          // 3. INVOICE INFO STRIP
          Container(
            decoration: const BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(width: 1.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'INVOICE NO. : INV-2024-001',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Text('Invoice Date: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', style: const TextStyle(fontSize: 11)),
                      ]
                    ),
                    const Row(
                      children: [
                        Text('Due Date: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('Within 30 days', style: TextStyle(fontSize: 11)),
                      ]
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. BILL TO / SHIP TO
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(width: 1.5)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BILL TO', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(data.clientName, style: const TextStyle(fontSize: 11)),
                      const Text('Customer Info', style: TextStyle(fontSize: 11)),
                      Text(data.clientAddress, style: const TextStyle(fontSize: 11)),
                      const SizedBox(height: 12),
                      Text('GSTIN NO.: ${data.clientGstin.isNotEmpty ? data.clientGstin : "N/A"}', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SHIP TO', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(data.clientName, style: const TextStyle(fontSize: 11)),
                      const Text('Customer Info', style: TextStyle(fontSize: 11)),
                      Text(data.clientAddress, style: const TextStyle(fontSize: 11)),
                      const SizedBox(height: 12),
                      Text('GSTIN NO.: ${data.clientGstin.isNotEmpty ? data.clientGstin : "N/A"}', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. ITEMS TABLE
          Table(
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.grey.shade300, width: 0.5),
            ),
            columnWidths: const {
              0: FlexColumnWidth(4),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: accentColor),
                children: [
                  _flutterHeaderCell('DESCRIPTION', TextAlign.left),
                  _flutterHeaderCell('QTY', TextAlign.center),
                  _flutterHeaderCell('UNIT PRICE', TextAlign.right),
                  _flutterHeaderCell('TOTAL', TextAlign.right),
                ],
              ),
              ...data.items.map(
                (item) => TableRow(
                  children: [
                    _flutterDataCell(
                      item.details.isNotEmpty 
                        ? '${item.desc}\n(${item.details})' 
                        : item.desc, 
                      TextAlign.left
                    ),
                    _flutterDataCell(item.qty.toString(), TextAlign.center),
                    _flutterDataCell(item.rate.toStringAsFixed(2), TextAlign.right),
                    _flutterDataCell(item.amount.toStringAsFixed(2), TextAlign.right),
                  ],
                ),
              ),
            ],
          ),

          // Add spacer to mimic table height
          SizedBox(height: (10 - data.items.length).clamp(0, 5) * 30.0),

          // 6. FOOTER (Terms, Payment, Totals)
          IntrinsicHeight(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(width: 1.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Footer Section
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(width: 1.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Terms & Instructions', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(data.notes.isNotEmpty ? data.notes : 'No terms specified.', style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(border: Border(top: BorderSide(width: 1.5))),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(text: 'Payment Mode: ', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                      TextSpan(text: data.paymentMethod ?? 'UPI', style: const TextStyle(fontSize: 11, color: Colors.black)),
                                    ]
                                  )
                                ),
                                const SizedBox(height: 40),
                                const Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text('Seal & Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))
                                )
                              ]
                            )
                          )
                        ],
                      )
                    ),
                  ),
                  
                  // Right Footer Section (Totals)
                  Expanded(
                    flex: 4,
                    child: Table(
                      border: const TableBorder.symmetric(inside: BorderSide(width: 1)),
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1),
                      },
                      children: [
                        _flutterFooterTotalsRow('SUBTOTAL', data.subtotal.toStringAsFixed(2)),
                        _flutterFooterTotalsRow('DISCOUNT', '0.00'),
                        if (data.showTaxBreakdown && data.taxLabel.toUpperCase() == 'GST') ...[
                          _flutterFooterTotalsRow('CGST @ ${(data.taxRate / 2).toStringAsFixed(1)}%', (data.taxAmount / 2).toStringAsFixed(2)),
                          _flutterFooterTotalsRow('SGST @ ${(data.taxRate / 2).toStringAsFixed(1)}%', (data.taxAmount / 2).toStringAsFixed(2)),
                        ] else ...[
                          _flutterFooterTotalsRow('${data.taxLabel} @ ${data.taxRate}%', data.taxAmount.toStringAsFixed(2)),
                        ],
                        _flutterFooterTotalsRow('Received Balance:', '0.00'),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              child: Text('Balance Due', textAlign: TextAlign.right, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                            Container(
                              color: lightAccentColor,
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              child: Text(data.total.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                            ),
                          ]
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              child: Text('GRAND TOTAL', textAlign: TextAlign.right, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            Container(
                              color: lightAccentColor,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              child: Text(data.total.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ]
                        ),
                      ]
                    )
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _flutterFooterTotalsRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(label, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10)),
        ),
      ]
    );
  }

  Widget _flutterHeaderCell(String label, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        textAlign: align,
      ),
    );
  }

  Widget _flutterDataCell(String value, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        value,
        style: const TextStyle(fontSize: 11),
        textAlign: align,
      ),
    );
  }

  @override
  InvoiceData getDefaultData() {
    // Retaining your original ElectroTech Solutions data so it matches the template context
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
      themeColorArgb: const Color(0xFF00796B).toARGB32(), // Changed to Teal/Mint for the new design
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