import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class GroceryWholesaleA4Template extends InvoiceTemplate {
  @override
  String get id => 'grocery_wholesale_a4';
  @override
  String get name => 'Grocery Wholesale B2B';
  @override
  String get industry => 'GROCERY';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'WHOLESALE';
  @override
  String get previewImagePath =>
      'assets/preview_templates/grocery_wholesale_a4_template.png';
  @override
  Color get badgeColor => Colors.indigo;
  @override
  String get metadata => 'Structured B2B Wholesale Invoice';
  @override
  String? get tag => 'BULK';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();
    final accent = PdfColor.fromInt(data.themeColorArgb);
    final accentLight = PdfColor.fromInt(
      ((0x1A) << 24) |
      ((accent.red * 255).round() << 16) |
      ((accent.green * 255).round() << 8) |
      (accent.blue * 255).round(),
    );

    pw.MemoryImage? logoImage;
    if (data.showLogo && data.logoBytes != null) {
      logoImage = pw.MemoryImage(data.logoBytes!);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return wrapWithFont(
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // --- HEADER SECTION ---
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    color: accentLight,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (data.showLogo && logoImage != null) ...[
                                pw.Container(
                                  width: 60,
                                  height: 60,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    border: pw.Border.all(color: PdfColors.grey300),
                                  ),
                                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                                ),
                                pw.SizedBox(width: 12),
                              ],
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      data.businessName.toUpperCase(),
                                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: accent),
                                    ),
                                    pw.SizedBox(height: 4),
                                    if (data.showBusinessAddress)
                                      pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 9)),
                                    pw.SizedBox(height: 2),
                                    pw.Text('M: ${data.businessPhone} | E: ${data.businessEmail}',
                                        style: const pw.TextStyle(fontSize: 9)),
                                    pw.SizedBox(height: 4),
                                    pw.Text('${data.taxLabel} NO: ${data.gstin}',
                                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('TAX INVOICE',
                                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accent, letterSpacing: 1.5)),
                              pw.SizedBox(height: 8),
                              pw.Text('ORIGINAL FOR RECIPIENT', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- BILLING & SHIPPING INFO ---
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey400, width: 1),
                        bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
                      ),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Billed To
                        pw.Expanded(
                          flex: 5,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(right: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Billed To / Party Details:',
                                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                                pw.SizedBox(height: 4),
                                pw.Text(data.clientName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                                if (data.showClientContact) ...[
                                  pw.SizedBox(height: 2),
                                  pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 9)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Invoice Details
                        pw.Expanded(
                          flex: 4,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildGridRow('Invoice No.', data.invoiceNumber.isNotEmpty ? data.invoiceNumber : 'INV-001'),
                                pw.SizedBox(height: 4),
                                _buildGridRow('Invoice Date', '${data.invoiceDate.day}-${data.invoiceDate.month}-${data.invoiceDate.year}'),
                                pw.SizedBox(height: 4),
                                _buildGridRow('Place of Supply', 'State Code / Local'),
                                if (data.paymentMethod != null) ...[
                                  pw.SizedBox(height: 4),
                                  _buildGridRow('Payment Mode', data.paymentMethod!.toUpperCase()),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- ITEMS TABLE ---
                  pw.Expanded(
                    child: pw.Table(
                      border: const pw.TableBorder(
                        verticalInside: pw.BorderSide(color: PdfColors.grey400, width: 1),
                        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                        bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
                      ),
                      columnWidths: const {
                        0: pw.FixedColumnWidth(30),
                        1: pw.FlexColumnWidth(4),
                        2: pw.FlexColumnWidth(1.5),
                        3: pw.FlexColumnWidth(1.2),
                        4: pw.FlexColumnWidth(2),
                      },
                      children: [
                        // Table Header
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: accent),
                          children: [
                            _buildTableHeader('S.N.'),
                            _buildTableHeader('Description of Goods', align: pw.TextAlign.left),
                            _buildTableHeader('Quantity'),
                            _buildTableHeader('Rate'),
                            _buildTableHeader('Amount'),
                          ],
                        ),
                        // Table Body
                        ...data.items.asMap().entries.map((entry) {
                          final i = entry.key + 1;
                          final item = entry.value;
                          return pw.TableRow(
                            children: [
                              _buildTableCell('$i', align: pw.TextAlign.center),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(item.desc, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                    if (item.details.isNotEmpty) ...[
                                      pw.SizedBox(height: 2),
                                      pw.Text(item.details, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                                    ]
                                  ],
                                ),
                              ),
                              _buildTableCell(item.qty.toStringAsFixed(0), align: pw.TextAlign.center, isBold: true),
                              _buildTableCell(item.rate.toStringAsFixed(2), align: pw.TextAlign.right),
                              _buildTableCell(item.amount.toStringAsFixed(2), align: pw.TextAlign.right, isBold: true),
                            ],
                          );
                        }),
                        // Fill empty space if items are few
                        if (data.items.length < 15)
                          pw.TableRow(
                            children: List.generate(5, (index) => pw.Container(height: 40)), // Blank padding row
                          )
                      ],
                    ),
                  ),

                  // --- SUMMARY SECTION ---
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                    ),
                    child: pw.Row(
                      children: [
                        // Notes / Bank Details / Amount in Words
                        pw.Expanded(
                          flex: 6,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(right: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Bank Details:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 2),
                                pw.Text('Bank: ${data.bankName.isNotEmpty ? data.bankName : "Bank Name"} | A/C: ${data.bankAccountNo.isNotEmpty ? data.bankAccountNo : "Account No"}', style: const pw.TextStyle(fontSize: 8)),
                                pw.Text('IFSC: ${data.bankIfsc.isNotEmpty ? data.bankIfsc : "IFSC Code"}', style: const pw.TextStyle(fontSize: 8)),
                                pw.SizedBox(height: 8),
                                if (data.showNotes && data.notes.isNotEmpty) ...[
                                  pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 2),
                                  pw.Text(data.notes, style: const pw.TextStyle(fontSize: 7)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Totals Breakdown
                        pw.Expanded(
                          flex: 4,
                          child: pw.Container(
                            color: PdfColors.grey50,
                            child: pw.Column(
                              children: [
                                _buildTotalRow('Taxable Amount', data.subtotal.toStringAsFixed(2)),
                                if (data.showTaxBreakdown)
                                  _buildTotalRow('${data.taxLabel} @ ${data.taxRate}%', data.taxAmount.toStringAsFixed(2)),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  color: accent,
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                                      pw.Text('Rs ${data.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- SIGNATURE SECTION ---
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Receiver\'s Seal & Signature', style: const pw.TextStyle(fontSize: 9)),
                            pw.SizedBox(height: 30),
                            pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)))),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('For ${data.businessName}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 30),
                            pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 9)),
                          ],
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

  pw.Widget _buildGridRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Expanded(flex: 2, child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
        pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
        pw.Expanded(flex: 3, child: pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: align),
    );
  }

  pw.Widget _buildTableCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal), textAlign: align),
    );
  }

  pw.Widget _buildTotalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    return Container(
      width: 595,
      height: 842,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              color: data.themeColor.withValues(alpha: 0.1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.businessName.toUpperCase(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: data.themeColor)),
                        if (data.showBusinessAddress) Text(data.businessAddress, style: const TextStyle(fontSize: 9)),
                        Text('M: ${data.businessPhone} | E: ${data.businessEmail}', style: const TextStyle(fontSize: 9)),
                        Text('${data.taxLabel} NO: ${data.gstin}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TAX INVOICE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: data.themeColor, letterSpacing: 1.5)),
                      Text('ORIGINAL FOR RECIPIENT', style: TextStyle(fontSize: 8, color: Colors.grey.shade700)),
                    ],
                  ),
                ],
              ),
            ),
            
            // Billed To & Meta
            Container(
              decoration: BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: Colors.grey.shade400)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade400))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Billed To / Party Details:', style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
                          Text(data.clientName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          if (data.showClientContact) Text(data.clientAddress, style: const TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text('Invoice No.', style: TextStyle(fontSize: 9, color: Colors.grey.shade700))),
                            const Text(':', style: TextStyle(fontSize: 9)),
                            Expanded(flex: 2, child: Text(data.invoiceNumber.isNotEmpty ? data.invoiceNumber : 'INV-001', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                          ]),
                          Row(children: [
                            Expanded(child: Text('Date', style: TextStyle(fontSize: 9, color: Colors.grey.shade700))),
                            const Text(':', style: TextStyle(fontSize: 9)),
                            Expanded(flex: 2, child: Text('${data.invoiceDate.day}-${data.invoiceDate.month}-${data.invoiceDate.year}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Table
            Expanded(
              child: Column(
                children: [
                  Container(
                    color: data.themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    child: const Row(
                      children: [
                        SizedBox(width: 30, child: Text('S.N.', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
                        Expanded(flex: 4, child: Text('Description of Goods', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
                        Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
                        Expanded(flex: 1, child: Text('Rate', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.right)),
                        Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: data.items.asMap().entries.map((entry) {
                          final i = entry.key + 1;
                          final item = entry.value;
                          return Container(
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))),
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            child: Row(
                              children: [
                                SizedBox(width: 30, child: Text('$i', style: const TextStyle(fontSize: 9), textAlign: TextAlign.center)),
                                Expanded(
                                  flex: 4, 
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.desc, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                      if (item.details.isNotEmpty) Text(item.details, style: TextStyle(fontSize: 7, color: Colors.grey.shade600)),
                                    ],
                                  )
                                ),
                                Expanded(flex: 1, child: Text(item.qty.toStringAsFixed(0), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                Expanded(flex: 1, child: Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 9), textAlign: TextAlign.right)),
                                Expanded(flex: 2, child: Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade400), bottom: BorderSide(color: Colors.grey.shade400))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade400))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bank Details:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          Text('Bank: ${data.bankName.isNotEmpty ? data.bankName : "Bank Name"} | A/C: ${data.bankAccountNo.isNotEmpty ? data.bankAccountNo : "Account No"}', style: const TextStyle(fontSize: 8)),
                          Text('IFSC: ${data.bankIfsc.isNotEmpty ? data.bankIfsc : "IFSC Code"}', style: const TextStyle(fontSize: 8)),
                          const SizedBox(height: 8),
                          if (data.showNotes) ...[
                            const Text('Terms & Conditions:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                            Text(data.notes, style: const TextStyle(fontSize: 7)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: Colors.grey.shade50,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Taxable Amount', style: TextStyle(fontSize: 9)),
                                Text(data.subtotal.toStringAsFixed(2), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          if (data.showTaxBreakdown)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${data.taxLabel} @ ${data.taxRate}%', style: const TextStyle(fontSize: 9)),
                                  Text(data.taxAmount.toStringAsFixed(2), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            color: data.themeColor,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('GRAND TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('Rs ${data.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Signature
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Receiver\'s Seal & Signature', style: TextStyle(fontSize: 9)),
                      const SizedBox(height: 30),
                      Container(width: 150, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade400)))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('For ${data.businessName}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 30),
                      const Text('Authorized Signatory', style: TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Apex Grocery Suppliers Ltd.',
      businessEmail: 'sales@apexgrocery.in',
      businessPhone: '+91 98765 43210',
      businessAddress: 'Block C, Wholesale Mandi, APMC Market, City - 400010',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'SuperMart Retail Outlet',
      clientAddress: 'Sector 15, Urban Estate, Next to Plaza',
      taxLabel: 'GST',
      taxRate: 5,
      themeColorArgb: Colors.indigo.toARGB32(),
      fontFamily: 'Inter',
      items: [
        InvoiceItem(id: '1', desc: 'Premium Basmati Rice', details: 'HSN: 1006 | Unit: 25kg Bag', qty: 50, rate: 1850),
        InvoiceItem(id: '2', desc: 'Refined Sunflower Oil', details: 'HSN: 1512 | Unit: 15L Tin', qty: 100, rate: 1650),
        InvoiceItem(id: '3', desc: 'Whole Wheat Flour (Chakki Atta)', details: 'HSN: 1101 | Unit: 10kg Bag', qty: 200, rate: 320),
        InvoiceItem(id: '4', desc: 'Crystal Sugar', details: 'HSN: 1701 | Unit: 50kg Gunny', qty: 10, rate: 1950),
      ],
      notes: '1. Goods once sold will not be taken back.\n2. Interest @ 24% p.a. will be charged if bill is not paid within 7 days.\n3. Subject to local jurisdiction.',
      isThermal: false,
      paymentMethod: 'Bank Transfer (NEFT/RTGS)',
    );
  }
}