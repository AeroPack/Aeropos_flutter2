import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class GroceryWholesaleA4Template extends InvoiceTemplate {
  @override
  String get id => 'grocery_wholesale_a4';
  @override
  String get name => 'Grocery Wholesale A4';
  @override
  String get industry => 'GROCERY';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'WHOLESALE';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => Colors.teal;
  @override
  String get metadata => 'Full-page Wholesale Bill';
  @override
  String? get tag => 'BULK';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();
    final accent = PdfColor.fromInt(data.themeColorArgb);

    pw.MemoryImage? logoImage;
    if (data.showLogo && data.logoBytes != null) {
      logoImage = pw.MemoryImage(data.logoBytes!);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  if (data.showLogo && logoImage != null) ...[
                    pw.Container(width: 55, height: 55, child: pw.Image(logoImage)),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Text(data.businessName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: accent)),
                  if (data.showBusinessAddress) pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Phone: ${data.businessPhone}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Email: ${data.businessEmail}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('${data.taxLabel}: ${data.gstin}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: accent, width: 2)),
                  child: pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accent, letterSpacing: 2)),
                ),
              ]),
              pw.Divider(height: 28, thickness: 1, color: PdfColors.grey200),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Buyer Details:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                  pw.SizedBox(height: 4),
                  pw.Text(data.clientName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  if (data.showClientContact) pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 10)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  _meta('Invoice No', 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'),
                  _meta('Date', '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                  _meta('Due Date', '${DateTime.now().add(const Duration(days: 7)).day}/${DateTime.now().add(const Duration(days: 7)).month}/${DateTime.now().add(const Duration(days: 7)).year}'),
                  if (data.paymentMethod != null) _meta('Payment', data.paymentMethod!.toUpperCase()),
                ]),
              ]),
              pw.SizedBox(height: 28),
              pw.Table(
                columnWidths: const {0: pw.FlexColumnWidth(4), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1), 4: pw.FlexColumnWidth(2)},
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: accent),
                    children: ['#', 'Item', 'Qty', 'Rate', 'Amount'].map((h) =>
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: h == 'Item' ? pw.TextAlign.left : pw.TextAlign.right),
                      ),
                    ).toList(),
                  ),
                  ...data.items.asMap().entries.map((entry) {
                    final i = entry.key + 1;
                    final item = entry.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: i.isEven ? PdfColors.grey100 : PdfColors.white,
                        border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                      ),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('$i', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(item.desc, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(item.qty.toString(), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(item.rate.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(item.amount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  _summary('Subtotal:', data.subtotal.toStringAsFixed(2)),
                  if (data.showTaxBreakdown) _summary('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
                  pw.Divider(height: 8, thickness: 1),
                  _summary('Total:', data.total.toStringAsFixed(2), bold: true, large: true),
                ]),
              ]),
              pw.Divider(height: 24, thickness: 1, color: PdfColors.grey200),
              pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              if (data.showNotes && data.notes.isNotEmpty) pw.Text(data.notes, style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 8),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                pw.Text('--- AeroPOS Wholesale ---', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              ]),
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _meta(String label, String value) {
    return pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Text('$label: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
      pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    ]);
  }

  pw.Widget _summary(String label, String value, {bool bold = false, bool large = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text('$label\t\t$value', style: pw.TextStyle(fontSize: large ? 16 : 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    return Container(
      width: 595, height: 842,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.businessName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: data.themeColor)),
            if (data.showBusinessAddress) Text(data.businessAddress, style: const TextStyle(fontSize: 10)),
            Text('Phone: ${data.businessPhone}', style: const TextStyle(fontSize: 10)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(border: Border.all(color: data.themeColor, width: 2)),
            child: Text('TAX INVOICE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: data.themeColor, letterSpacing: 2)),
          ),
        ]),
        const Divider(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Buyer:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            Text(data.clientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 9)),
        ]),
        const SizedBox(height: 24),
        Expanded(child: SingleChildScrollView(
          child: Column(children: data.items.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final item = entry.value;
            return Container(
              color: i.isEven ? Colors.grey.shade50 : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Row(children: [
                SizedBox(width: 30, child: Text('$i', style: const TextStyle(fontSize: 9), textAlign: TextAlign.right)),
                Expanded(flex: 4, child: Text(item.desc, style: const TextStyle(fontSize: 9))),
                Expanded(flex: 1, child: Text(item.qty.toString(), style: const TextStyle(fontSize: 9), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 9), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ]),
            );
          }).toList()),
        )),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Subtotal: ${data.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            Text('${data.taxLabel} (${data.taxRate}%): ${data.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            const Divider(height: 8),
            Text('TOTAL: ₹${data.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        ]),
      ]),
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Grocery Wholesale Distributors',
      businessEmail: 'orders@grocerywholesale.in',
      businessPhone: '+91 22 1122 3344',
      businessAddress: '1 Industrial Area, City, State - 400010',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'Retail Partner',
      clientAddress: 'Local Market Area',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: Colors.teal.toARGB32(),
      fontFamily: 'Inter',
      items: [
        InvoiceItem(id: '1', desc: 'Basmati Rice (25kg)', details: '', qty: 10, rate: 1850),
        InvoiceItem(id: '2', desc: 'Refined Soybean Oil (15L)', details: '', qty: 5, rate: 1650),
        InvoiceItem(id: '3', desc: 'Wheat Flour (10kg)', details: '', qty: 20, rate: 320),
        InvoiceItem(id: '4', desc: 'Sugar (5kg)', details: '', qty: 15, rate: 195),
      ],
      notes: 'Payment due within 7 days. Late payment attracts 2% interest per month. Delivery: Free for orders above ₹10,000.',
      isThermal: false,
    );
  }
}
