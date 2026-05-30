import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class FashionShopA4Template extends InvoiceTemplate {
  @override
  String get id => 'fashion_shop_a4';
  @override
  String get name => 'Fashion Boutique A4';
  @override
  String get industry => 'FASHION';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'MODERN ELEGANT';
  @override
  String get previewImagePath => 'assets/preview_templates/fashionista_a4_template.png';
  @override
  Color get badgeColor => const Color(0xFF255B77);
  @override
  String get metadata => 'Elegant Fashion Design with Full Bleed Headers';
  @override
  String? get tag => 'PREMIUM';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromInt(data.themeColorArgb);
    final goldColor = const PdfColor.fromInt(0xFFD4B068);
    // A slightly lighter/different blue for the table header to match the image
    final tableHeaderColor = const PdfColor.fromInt(0xFF3B7494);

    pw.MemoryImage? logoImage;
    if (data.showLogo && data.logoBytes != null) {
      logoImage = pw.MemoryImage(data.logoBytes!);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) {
          return wrapWithFont(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. Top Header Block (Dark Blue)
                pw.Container(
                  color: primaryColor,
                  padding: const pw.EdgeInsets.only(left: 40, right: 40, top: 50, bottom: 30),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Left Logo/Title
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (logoImage != null)
                                pw.Container(
                                  width: 60,
                                  height: 60,
                                  margin: const pw.EdgeInsets.only(bottom: 10),
                                  child: pw.Image(logoImage),
                                )
                              else
                                pw.Text(
                                  data.businessName.toUpperCase(),
                                  style: pw.TextStyle(
                                    color: goldColor,
                                    fontSize: 24,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'PREMIUM FASHION APPAREL',
                                style: const pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 9,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          // Right Title
                          pw.Text(
                            'INVOICE',
                            style: pw.TextStyle(
                              color: goldColor,
                              fontSize: 42,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 30),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(flex: 3, child: pw.SizedBox()), // Empty space under logo
                          pw.Expanded(
                            flex: 4,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Invoice To:',
                                  style: pw.TextStyle(color: goldColor, fontSize: 11),
                                ),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                  data.clientName.toUpperCase(),
                                  style: pw.TextStyle(
                                    color: goldColor,
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  data.clientAddress,
                                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Phone: 9999999999', // Placeholder or use client phone if in model
                                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.SizedBox(height: 20), // Align with client name
                                _pdfHeaderDetailRow('Invoice No', ': INV-0001', goldColor),
                                pw.SizedBox(height: 4),
                                _pdfHeaderDetailRow(
                                  'Invoice Date',
                                  ': ${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}',
                                  goldColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Table Header (Medium Blue)
                pw.Container(
                  color: tableHeaderColor,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Text(
                          'Item Description',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Price',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Quantity',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Total',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table rows
                      ...data.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final rowColor = index % 2 == 0 ? PdfColors.white : const PdfColor.fromInt(0xFFF5F5F5);

                        return pw.Container(
                          color: rowColor,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                flex: 5,
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      item.desc,
                                      style: pw.TextStyle(color: PdfColors.black, fontSize: 11, fontWeight: pw.FontWeight.bold),
                                    ),
                                    if (item.details.isNotEmpty) ...[
                                      pw.SizedBox(height: 2),
                                      pw.Text(
                                        item.details,
                                        style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  '\$${item.rate.toStringAsFixed(2)}',
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(color: PdfColors.black, fontSize: 11),
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  item.qty.toString(),
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(color: PdfColors.black, fontSize: 11),
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  '\$${item.amount.toStringAsFixed(2)}',
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(color: PdfColors.black, fontSize: 11, fontWeight: pw.FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // 4. Bottom Section (Totals & Payment Info)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: Payment Info & Terms
                            pw.Expanded(
                              flex: 6,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'PAYMENT INFO',
                                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.SizedBox(height: 8),
                                  if (data.showBankDetails && data.bankName.isNotEmpty) ...[
                                    _pdfInfoRow('Account Name', ': ${data.businessName}'),
                                    _pdfInfoRow('Bank', ': ${data.bankName}'),
                                    _pdfInfoRow('A/C No', ': ${data.bankAccountNo}'),
                                    _pdfInfoRow('IFSC', ': ${data.bankIfsc}'),
                                  ],
                                  
                                  pw.SizedBox(height: 30),
                                  
                                  pw.Text(
                                    'Thank you for your business!',
                                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.SizedBox(height: 8),
                                  pw.Text(
                                    'TERMS: ',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.Text(
                                    data.notes.isNotEmpty ? data.notes : 'Lorem ipsum dolor sit amet, consectetuer\nLorem ipsum dolor sit amet, consectetuer',
                                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                                  ),
                                ],
                              ),
                            ),
                            
                            pw.SizedBox(width: 20),
                            
                            // Right: Totals & Signature
                            pw.Expanded(
                              flex: 4,
                              child: pw.Column(
                                children: [
                                  // Totals
                                  pw.Container(
                                    padding: const pw.EdgeInsets.only(left: 10),
                                    child: pw.Column(
                                      children: [
                                        _pdfTotalRow('Sub Total', '\$${data.subtotal.toStringAsFixed(2)}'),
                                        pw.SizedBox(height: 6),
                                        _pdfTotalRow('${data.taxLabel} ${data.taxRate}%', '\$${data.taxAmount.toStringAsFixed(2)}'),
                                        pw.SizedBox(height: 6),
                                        _pdfTotalRow('Discount 0%', '\$0.00'),
                                      ],
                                    ),
                                  ),
                                  pw.SizedBox(height: 10),
                                  pw.Container(
                                    color: primaryColor,
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text('Grand Total', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                        pw.Text('\$${data.total.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  
                                  pw.SizedBox(height: 40),
                                  
                                  // Signature area
                                  pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      pw.Text(
                                        'TONY GREY',
                                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                                      ),
                                      pw.Text(
                                        'Account Manager',
                                        style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
                                      ),
                                      pw.SizedBox(height: 10),
                                      pw.Text(
                                        'Signature',
                                        style: pw.TextStyle(
                                          fontStyle: pw.FontStyle.italic,
                                          fontSize: 24,
                                          color: PdfColors.grey700,
                                        ),
                                      ),
                                    ],
                                  ),
              ],
                        ),
                      ),

                      // 5. Footer Block
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _pdfFooterItem('Location', data.businessAddress.replaceAll('\n', ' ')),
                            _pdfFooterItem('Phone', data.businessPhone),
                            _pdfFooterItem('Email', data.businessEmail),
                          ],
                        ),
                      ),
                      // Bottom Gold Bar
                      pw.Container(
                        height: 15,
                        width: double.infinity,
                        color: goldColor,
                      ),
                    ],
                  ),
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

  pw.Widget _pdfHeaderDetailRow(String label, String value, PdfColor labelColor) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 70,
          child: pw.Text(label, style: pw.TextStyle(color: labelColor, fontSize: 10)),
        ),
        pw.Text(value, style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
      ],
    );
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
        ],
      ),
    );
  }

  pw.Widget _pdfTotalRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  pw.Widget _pdfFooterItem(String iconPlaceholder, String text) {
    return pw.Row(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF3B7494),
            shape: pw.BoxShape.circle,
          ),
          child: pw.Text(
            iconPlaceholder[0], 
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    final primaryColor = Color(data.themeColorArgb);
    final goldColor = const Color(0xFFD4B068);
    final tableHeaderColor = const Color(0xFF3B7494);

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header Block
          Container(
            color: primaryColor,
            padding: const EdgeInsets.only(left: 30, right: 30, top: 40, bottom: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data.showLogo && data.logoBytes != null)
                          buildLogoWidget(data, size: 50)
                        else
                          Text(
                            data.businessName.toUpperCase(),
                            style: TextStyle(
                              color: goldColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 4),
                        const Text(
                          'PREMIUM FASHION APPAREL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'INVOICE',
                      style: TextStyle(
                        color: goldColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(flex: 2, child: SizedBox()),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice To:',
                            style: TextStyle(color: goldColor, fontSize: 9),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.clientName.toUpperCase(),
                            style: TextStyle(
                              color: goldColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.clientAddress,
                            style: const TextStyle(color: Colors.white, fontSize: 8),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Phone: 9999999999',
                            style: TextStyle(color: Colors.white, fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 15),
                          _flutterHeaderDetailRow('Invoice No', ': INV-0001', goldColor),
                          const SizedBox(height: 4),
                          _flutterHeaderDetailRow(
                            'Invoice Date',
                            ': ${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}',
                            goldColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Table Header
          Container(
            color: tableHeaderColor,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            child: Row(
              children: const [
                Expanded(
                  flex: 5,
                  child: Text('Item Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Price', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Quantity', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                ),
              ],
            ),
          ),

          // 3. Table Rows
          ...data.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final rowColor = index % 2 == 0 ? Colors.white : const Color(0xFFF5F5F5);

            return Container(
              color: rowColor,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.desc, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                        if (item.details.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(item.details, style: TextStyle(color: Colors.grey.shade600, fontSize: 8)),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('\$${item.rate.toStringAsFixed(2)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 9)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(item.qty.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 9)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('\$${item.amount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 15),

          // 4. Bottom Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PAYMENT INFO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      _flutterInfoRow('Account No', ': 123 456 789'),
                      _flutterInfoRow('Account Name', ': ${data.businessName}'),
                      _flutterInfoRow('Bank Details', '${data.bankName.isNotEmpty ? data.bankName : ""}${data.bankAccountNo.isNotEmpty ? " | A/C: ${data.bankAccountNo}" : ""}${data.bankIfsc.isNotEmpty ? " | IFSC: ${data.bankIfsc}" : ""}'),
                      
                      const SizedBox(height: 20),
                      
                      const Text('Thank you for your business!', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('TERMS: ', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                      Text(
                        data.notes.isNotEmpty ? data.notes : 'Lorem ipsum dolor sit amet, consectetuer\nLorem ipsum dolor sit amet, consectetuer',
                        style: TextStyle(fontSize: 7, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 15),
                
                // Right
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Column(
                          children: [
                            _flutterTotalRow('Sub Total', '\$${data.subtotal.toStringAsFixed(2)}'),
                            const SizedBox(height: 4),
                            _flutterTotalRow('${data.taxLabel} ${data.taxRate}%', '\$${data.taxAmount.toStringAsFixed(2)}'),
                            const SizedBox(height: 4),
                            _flutterTotalRow('Discount 0%', '\$0.00'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        color: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            Text('\$${data.total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 25),
                      
                      // Signature
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('TONY GREY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                          Text('Account Manager', style: TextStyle(color: Colors.grey.shade600, fontSize: 8)),
                          const SizedBox(height: 5),
                          Text('Signature', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 18, color: Colors.grey.shade700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 5. Footer Block
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _flutterFooterItem(Icons.location_on, data.businessAddress.replaceAll('\n', ' ')),
                _flutterFooterItem(Icons.phone, data.businessPhone),
                _flutterFooterItem(Icons.language, data.businessEmail),
              ],
            ),
          ),
          Container(
            height: 10,
            width: double.infinity,
            color: goldColor,
          ),
        ],
      ),
    );
  }

  Widget _flutterHeaderDetailRow(String label, String value, Color labelColor) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: TextStyle(color: labelColor, fontSize: 8)),
        ),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 8)),
      ],
    );
  }

  Widget _flutterInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
          ),
          Text(value, style: TextStyle(fontSize: 8, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Widget _flutterTotalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 9)),
        Text(value, style: const TextStyle(fontSize: 9)),
      ],
    );
  }

  Widget _flutterFooterItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Color(0xFF3B7494),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 8),
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 7, color: Colors.grey.shade700)),
      ],
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: "Fashionist",
      businessEmail: "info@fashionist.com",
      businessPhone: "+123 456789",
      businessAddress: "1234 Main Street, Your City 54678",
      gstin: "",
      clientName: "John Clark",
      clientAddress: "123 Street. Town/City, Country",
      taxLabel: "VAT",
      taxRate: 0,
      themeColorArgb: const Color(0xFF255B77).toARGB32(),
      fontFamily: "Inter",
      items: [
        InvoiceItem(
          id: '1',
          desc: 'Product Description',
          details: 'Lorem ipsum dolor sit amet, consectetuer Lorem ipsum dolor sit\namet, consectetuerLorem ipsum dolor',
          qty: 1,
          rate: 150.00,
        ),
        InvoiceItem(
          id: '2',
          desc: 'Product Description',
          details: 'Lorem ipsum dolor sit amet, consectetuer Lorem ipsum dolor sit',
          qty: 2,
          rate: 75.00,
        ),
        InvoiceItem(
          id: '3',
          desc: 'Product Description',
          details: 'Lorem ipsum dolor sit amet, consectetuer Lorem ipsum dolor sit\namet, consectetuerLorem ipsum dolor',
          qty: 1,
          rate: 220.00,
        ),
        InvoiceItem(
          id: '4',
          desc: 'Product Description',
          details: 'Lorem ipsum dolor sit amet, consectetuer Lorem ipsum dolor sit',
          qty: 3,
          rate: 45.00,
        ),
      ],
      notes: "Lorem ipsum dolor sit amet, consectetuer\nLorem ipsum dolor sit amet, consectetuer",
      isThermal: false,
    );
  }
}