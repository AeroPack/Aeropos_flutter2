import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class BoutiqueA4InvoiceTemplate extends InvoiceTemplate {
  @override
  String get id => 'boutique_service_a4';
  @override
  String get name => 'Elegant Boutique Service';
  @override
  String get industry => 'FASHION & BOUTIQUE';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'ELEGANT';
  @override
  String get previewImagePath =>
      'assets/preview_templates/service_a4_template.png';
  @override
  Color get badgeColor => const Color(0xFFC07C88); // Dusty Rose
  @override
  String get metadata => 'A4 optimized, Service Oriented';
  @override
  String? get tag => 'SERVICE';

  // --- PDF GENERATION ---
  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();
    
    // Boutique Color Palette
    final primaryColor = PdfColor.fromInt(data.themeColorArgb); // e.g., Dusty Rose
    const lightBackground = PdfColor.fromInt(0xFFF9F6F6); // Soft blush white
    const alternateRowColor = PdfColor.fromInt(0xFFF3EAEA); 
    const textColor = PdfColors.grey800;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Header (Company Info)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        data.businessName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 20, 
                          fontWeight: pw.FontWeight.bold, 
                          color: primaryColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Phone No.: ${data.businessPhone}', style: const pw.TextStyle(fontSize: 10, color: textColor)),
                      pw.Text('Email: ${data.businessEmail}', style: const pw.TextStyle(fontSize: 10, color: textColor)),
                    ],
                  ),
                  // Optional Logo Placeholder
                  if (data.showLogo && data.logoBytes != null)
                    pw.Container(width: 60, height: 60, child: pw.Image(pw.MemoryImage(data.logoBytes!))),
                ],
              ),
              pw.SizedBox(height: 20),

              // 2. Title Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                decoration: pw.BoxDecoration(color: primaryColor),
                child: pw.Text(
                  'SERVICE INVOICE',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // 3. Billing & Invoice Details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Bill To
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Bill To:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text(data.clientName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 10, color: textColor)),
                           pw.Text('Contact No.: ${data.clientPhone}', style: const pw.TextStyle(fontSize: 10, color: textColor)),
                      ],
                    ),
                  ),
                  // Invoice Details
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _pdfDetailRow('Invoice No.:', data.invoiceNumber),
                        _pdfDetailRow('Date:', '${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}'),
                        if (data.paymentMethod != null)
                          _pdfDetailRow('Payment Mode:', data.paymentMethod!),
                      ],
                    ),
                  ),
                ],
              ),
              // 4. Items Table & Bottom Content (Expanded to fill page)
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Table(
                      columnWidths: const {
                        0: pw.FlexColumnWidth(0.8),
                        1: pw.FlexColumnWidth(3.5),
                        2: pw.FlexColumnWidth(1.2),
                        3: pw.FlexColumnWidth(1.0),
                        4: pw.FlexColumnWidth(1.0),
                        5: pw.FlexColumnWidth(1.5),
                        6: pw.FlexColumnWidth(1.0),
                        7: pw.FlexColumnWidth(1.5),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: primaryColor),
                          children: [
                            _pdfHeaderCell('Sl. No.'),
                            _pdfHeaderCell('Service Name', align: pw.TextAlign.left),
                            _pdfHeaderCell('HSN/SAC'),
                            _pdfHeaderCell('Qty'),
                            _pdfHeaderCell('Unit'),
                            _pdfHeaderCell('Price/Unit'),
                            _pdfHeaderCell('GST'),
                            _pdfHeaderCell('Amount'),
                          ],
                        ),
                        ...data.items.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final item = entry.value;
                          final isEven = index % 2 == 0;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(color: isEven ? lightBackground : alternateRowColor),
                            children: [
                              _pdfBodyCell('${index + 1}', align: pw.TextAlign.center),
                              _pdfBodyCell(item.desc, align: pw.TextAlign.left),
                              _pdfBodyCell('9983', align: pw.TextAlign.center),
                              _pdfBodyCell('${item.qty}', align: pw.TextAlign.center),
                              _pdfBodyCell('Pcs', align: pw.TextAlign.center),
                              _pdfBodyCell(item.rate.toStringAsFixed(2)),
                              _pdfBodyCell('${data.taxRate}%'),
                              _pdfBodyCell(item.amount.toStringAsFixed(2)),
                            ],
                          );
                        }),
                      ],
                    ),
                    
                    pw.Container(height: 1, color: primaryColor),
                    pw.SizedBox(height: 20),

                    // 5. Calculations & Terms Layout
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 6,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _pdfBannerTitle('INVOICE AMOUNT IN WORDS', primaryColor),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                child: pw.Text(
                                  'Rupees ${data.total.toInt()} Only',
                                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textColor),
                                ),
                              ),
                              pw.SizedBox(height: 12),
                              _pdfBannerTitle('Terms and Conditions', primaryColor),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                child: pw.Text(
                                  data.notes.isNotEmpty ? data.notes : '1. Subject to local jurisdiction.\n2. No refund on custom tailoring.',
                                  style: const pw.TextStyle(fontSize: 8, color: textColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            children: [
                              _pdfCalculationRow('Sub Total:', data.subtotal.toStringAsFixed(2)),
                              _pdfCalculationRow('SGST @ ${(data.taxRate/2).toStringAsFixed(1)}%:', (data.taxAmount/2).toStringAsFixed(2)),
                              _pdfCalculationRow('CGST @ ${(data.taxRate/2).toStringAsFixed(1)}%:', (data.taxAmount/2).toStringAsFixed(2)),
                              _pdfCalculationRow('Discount:', '0.00'),
                              pw.Container(
                                color: _lighten(primaryColor, 0.8),
                                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                                child: _pdfCalculationRow(
                                  'Total:', 
                                  data.total.toStringAsFixed(2), 
                                  isBold: true,
                                  color: primaryColor,
                                ),
                              ),
                              _pdfCalculationRow('Received:', '0.00'),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.Spacer(),

                    // 6. Signature Section
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.SizedBox(height: 40),
                            pw.Container(width: 120, height: 1, color: textColor),
                            pw.SizedBox(height: 4),
                            pw.Text('Authorized Seal & Signature', style: const pw.TextStyle(fontSize: 9, color: textColor)),
                          ],
                        ),
                      ],
                    ),
                    
                    pw.SizedBox(height: 20),
                    pw.Center(
                      child: pw.Text(
                        'Thank you for choosing ${data.businessName}!',
                        style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: primaryColor),
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
  pw.Widget _pdfHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _pdfBodyCell(String text, {pw.TextAlign align = pw.TextAlign.right}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(text, textAlign: align, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
    );
  }

  pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _pdfBannerTitle(String title, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: pw.BoxDecoration(color: _lighten(color, 0.8)),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color),
      ),
    );
  }

  pw.Widget _pdfCalculationRow(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.grey800)),
        ],
      ),
    );
  }

  PdfColor _lighten(PdfColor color, double amount) {
    final int value = color.toInt();
    final int r = (value >> 16) & 0xFF;
    final int g = (value >> 8) & 0xFF;
    final int b = value & 0xFF;
    final int lr = (r + ((255 - r) * amount).toInt()).clamp(0, 255);
    final int lg = (g + ((255 - g) * amount).toInt()).clamp(0, 255);
    final int lb = (b + ((255 - b) * amount).toInt()).clamp(0, 255);
    return PdfColor.fromInt((0xFF << 24) | (lr << 16) | (lg << 8) | lb);
  }

  // --- FLUTTER PREVIEW ---
  @override
  Widget buildFlutterPreview(InvoiceData data) {
    final primaryColor = Color(data.themeColorArgb);
    const lightBackground = Color(0xFFF9F6F6);
    const alternateRowColor = Color(0xFFF3EAEA);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.businessName.toUpperCase(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 1.2),
                  ),
                  Text('Phone: ${data.businessPhone}', style: const TextStyle(fontSize: 8, color: Colors.black87)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: primaryColor,
            child: const Text(
              'SERVICE INVOICE',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 12),

          // Bill To & Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bill To:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryColor)),
                    Text(data.clientName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(data.clientAddress, style: const TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _flutterDetailRow('Invoice No.:', data.invoiceNumber),
                    _flutterDetailRow('Date:', '${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1), 1: FlexColumnWidth(3), 2: FlexColumnWidth(1),
              3: FlexColumnWidth(1), 4: FlexColumnWidth(1), 5: FlexColumnWidth(1.5),
              6: FlexColumnWidth(1), 7: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: primaryColor),
                children: [
                  _flutterHeaderCell('Sl.'), _flutterHeaderCell('Service', align: TextAlign.left),
                  _flutterHeaderCell('HSN'), _flutterHeaderCell('Qty'), _flutterHeaderCell('Unit'),
                  _flutterHeaderCell('Price'), _flutterHeaderCell('GST'), _flutterHeaderCell('Amt'),
                ],
              ),
              ...data.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return TableRow(
                  decoration: BoxDecoration(color: index % 2 == 0 ? lightBackground : alternateRowColor),
                  children: [
                    _flutterBodyCell('${index + 1}', align: TextAlign.center),
                    _flutterBodyCell(item.desc, align: TextAlign.left),
                    _flutterBodyCell('9983', align: TextAlign.center),
                    _flutterBodyCell('${item.qty}', align: TextAlign.center),
                    _flutterBodyCell('Pcs', align: TextAlign.center),
                    _flutterBodyCell(item.rate.toStringAsFixed(0)),
                    _flutterBodyCell('${data.taxRate}%'),
                    _flutterBodyCell(item.amount.toStringAsFixed(0)),
                  ],
                );
              }),
            ],
          ),
          Container(height: 1, color: primaryColor),
          const SizedBox(height: 12),

          // Bottom Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _flutterBannerTitle('AMOUNT IN WORDS', primaryColor),
                    Text('Rupees ${data.total.toInt()} Only', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _flutterBannerTitle('Terms & Conditions', primaryColor),
                    Text(data.notes, style: const TextStyle(fontSize: 7)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _flutterCalcRow('Sub Total:', data.subtotal.toStringAsFixed(2)),
                    _flutterCalcRow('SGST:', (data.taxAmount / 2).toStringAsFixed(2)),
                    _flutterCalcRow('CGST:', (data.taxAmount / 2).toStringAsFixed(2)),
                    Container(
                      color: primaryColor.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: _flutterCalcRow('Total:', data.total.toStringAsFixed(2), isBold: true, color: primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Flutter Helper Widgets ---
  Widget _flutterHeaderCell(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Text(text, textAlign: align, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
    );
  }

  Widget _flutterBodyCell(String text, {TextAlign align = TextAlign.right}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Text(text, textAlign: align, style: const TextStyle(fontSize: 7, color: Colors.black87)),
    );
  }

  Widget _flutterDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.black54)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _flutterBannerTitle(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2)),
      child: Text(title, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _flutterCalcRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 8, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87)),
          Text(value, style: TextStyle(fontSize: 8, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  // --- DUMMY DATA ---
  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Aura Bridal & Boutique',
      businessEmail: 'hello@auraboutique.in',
      businessPhone: '+91 98765 43210',
      businessAddress: '12 Elegance Street, Fashion District, City - 400001',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'Ms. Ananya Sharma',
      clientAddress: 'Rosewood Apartments, Block B, City Area',
      clientPhone: '+91 91234 56789',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: 0xFFC07C88, // Dusty Rose
      fontFamily: 'Helvetica',
      items: [
        InvoiceItem(id: '1', desc: 'Bridal Lehenga Custom Fitting', details: '', qty: 1, rate: 4500),
        InvoiceItem(id: '2', desc: 'Hand-Embroidery Saree Blouse', details: '', qty: 2, rate: 2800),
        InvoiceItem(id: '3', desc: 'Designer Dress Alteration', details: '', qty: 1, rate: 950),
      ],
      notes: '1. Alterations require 3 days advance notice.\n2. No refunds on custom stitching and hand-embroidery work.\n3. Please bring this invoice for garment collection.',
      isThermal: false, // A4 format
    );
  }
}