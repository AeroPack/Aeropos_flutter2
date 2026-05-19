import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class RestaurantProA4Template extends InvoiceTemplate {
  @override
  String get id => 'restaurant_pro_a4';
  @override
  String get name => 'Restaurant Pro A4';
  @override
  String get industry => 'RESTAURANT';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'PROFESSIONAL';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => Colors.redAccent;
  @override
  String get metadata => 'Full-page Restaurant Invoice';
  @override
  String? get tag => 'DINE-IN';

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
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  if (data.showLogo && logoImage != null) ...[
                    pw.Container(width: 50, height: 50, child: pw.Image(logoImage)),
                    pw.SizedBox(width: 12),
                  ],
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(data.businessName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: accent)),
                    if (data.showBusinessAddress) pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(data.businessPhone, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('${data.taxLabel}: ${data.gstin}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ]),
                ]),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: accent,
                  child: pw.Text('INVOICE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ),
              ]),
              pw.Divider(height: 32, thickness: 1, color: PdfColors.grey200),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                if (data.showClientContact)
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('BILL TO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                    pw.SizedBox(height: 6),
                    pw.Text(data.clientName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 10)),
                  ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  _metaRow('Invoice #', 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'),
                  _metaRow('Date', '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                  if (data.paymentMethod != null) _metaRow('Payment', data.paymentMethod!.toUpperCase()),
                ]),
              ]),
              pw.SizedBox(height: 32),
              pw.Table(
                columnWidths: const {0: pw.FlexColumnWidth(4), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1), 4: pw.FlexColumnWidth(1)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: ['Item', 'Qty', 'Rate', 'GST', 'Total'].map((h) =>
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accent)),
                      ),
                    ).toList(),
                  ),
                  ...data.items.map((item) => pw.TableRow(
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(item.desc, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(item.qty.toString(), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(item.rate.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('${data.taxRate}%', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(item.amount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    ],
                  )),
                ],
              ),
              pw.Divider(height: 24, thickness: 1, color: PdfColors.grey300),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  _summaryLine('Subtotal:', data.subtotal.toStringAsFixed(2)),
                  if (data.showTaxBreakdown) _summaryLine('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
                  pw.SizedBox(height: 8),
                  pw.Row(children: [
                    pw.Text('GRAND TOTAL: ', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accent)),
                    pw.Text('₹${data.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: accent)),
                  ]),
                ]),
              ]),
              pw.Divider(height: 32, thickness: 1, color: PdfColors.grey200),
              pw.Text('Thank you for dining with us!', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
              if (data.showNotes && data.notes.isNotEmpty) pw.Text(data.notes, style: const pw.TextStyle(fontSize: 8)),
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _metaRow(String label, String value) {
    return pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Text('$label: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
      pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    ]);
  }

  pw.Widget _summaryLine(String label, String value) {
    return pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(width: 12),
      pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
    ]);
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    return Container(
      width: 595, height: 842,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.businessName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: data.themeColor)),
            if (data.showBusinessAddress) Text(data.businessAddress, style: const TextStyle(fontSize: 10)),
            Text(data.businessPhone, style: const TextStyle(fontSize: 10)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: data.themeColor,
            child: const Text('INVOICE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ]),
        const Divider(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BILL TO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            Text(data.clientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 9)),
        ]),
        const SizedBox(height: 24),
        Expanded(child: SingleChildScrollView(
          child: Column(children: data.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(flex: 4, child: Text(item.desc, style: const TextStyle(fontSize: 10))),
              Expanded(flex: 1, child: Text(item.qty.toString(), style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
              Expanded(flex: 1, child: Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
              Expanded(flex: 1, child: Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            ]),
          )).toList()),
        )),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Subtotal: ${data.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            Text('${data.taxLabel} (${data.taxRate}%): ${data.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            Text('TOTAL: ₹${data.total.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: data.themeColor)),
          ]),
        ]),
      ]),
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Restaurant Pro',
      businessEmail: 'info@restaurantpro.in',
      businessPhone: '+91 22 8877 9900',
      businessAddress: '22 Dine Avenue, City, State - 400008',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'Guest',
      clientAddress: 'Table 8, VIP Section',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: Colors.redAccent.toARGB32(),
      fontFamily: 'Inter',
      items: [
        InvoiceItem(id: '1', desc: 'Paneer Butter Masala', details: '', qty: 2, rate: 250),
        InvoiceItem(id: '2', desc: 'Butter Naan', details: '', qty: 4, rate: 35),
        InvoiceItem(id: '3', desc: 'Dal Tadka', details: '', qty: 1, rate: 180),
        InvoiceItem(id: '4', desc: 'Gulab Jamun (4 pcs)', details: '', qty: 2, rate: 80),
      ],
      notes: 'GST included. 10% service charge for groups of 6+. No outside food.',
      isThermal: false,
    );
  }
}
