import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class GarmentCollectionA4Template extends InvoiceTemplate {
  @override
  String get id => 'garment_collection_a4';
  @override
  String get name => 'Garment Collection A4';
  @override
  String get industry => 'GARMENT';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'ELEGANT';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1626266061368-46a8f578ddd6?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => Colors.indigo;
  @override
  String get metadata => 'Full-page Boutique Invoice';
  @override
  String? get tag => 'PREMIUM';

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
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: accent, width: 2)),
                ),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    if (data.showLogo && logoImage != null) ...[
                      pw.Container(width: 55, height: 55, child: pw.Image(logoImage)),
                      pw.SizedBox(width: 14),
                    ],
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(data.businessName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: accent, letterSpacing: 1)),
                      if (data.showBusinessAddress) pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text('Phone: ${data.businessPhone}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text('${data.taxLabel}: ${data.gstin}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ]),
                  pw.Text('INVOICE', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.grey300, letterSpacing: 4)),
                ]),
              ),
              pw.SizedBox(height: 24),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                if (data.showClientContact)
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('SHIP TO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500, letterSpacing: 1)),
                    pw.SizedBox(height: 6),
                    pw.Text(data.clientName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 10)),
                  ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  _meta('Invoice', 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'),
                  _meta('Date', '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                  if (data.paymentMethod != null) _meta('Payment', data.paymentMethod!.toUpperCase()),
                ]),
              ]),
              pw.SizedBox(height: 32),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                color: PdfColors.grey100,
                child: pw.Row(children: [
                  pw.Expanded(flex: 3, child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accent))),
                  pw.Expanded(flex: 1, child: pw.Text('QTY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 1, child: pw.Text('RATE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 1, child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.right)),
                ]),
              ),
              ...data.items.map((item) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                child: pw.Row(children: [
                  pw.Expanded(flex: 3, child: pw.Text(item.desc, style: const pw.TextStyle(fontSize: 10))),
                  pw.Expanded(flex: 1, child: pw.Text(item.qty.toString(), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 1, child: pw.Text(item.rate.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 1, child: pw.Text(item.amount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ]),
              )),
              pw.SizedBox(height: 24),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  _summary('Subtotal:', data.subtotal.toStringAsFixed(2)),
                  if (data.showTaxBreakdown) _summary('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    color: PdfColors.grey100,
                    child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                      pw.Text('TOTAL AMOUNT:  ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent)),
                      pw.Text('₹${data.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accent)),
                    ]),
                  ),
                ]),
              ]),
              pw.Divider(height: 32, thickness: 1, color: PdfColors.grey200),
              pw.Text('Thank you for your purchase!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
              if (data.showNotes && data.notes.isNotEmpty) pw.Container(
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.only(top: 8),
                color: PdfColors.grey100,
                child: pw.Text(data.notes, style: const pw.TextStyle(fontSize: 7)),
              ),
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

  pw.Widget _summary(String label, String value) {
    return pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(width: 16),
      pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
    ]);
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    return Container(
      width: 595, height: 842,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: data.themeColor, width: 2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data.businessName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: data.themeColor, letterSpacing: 1)),
              if (data.showBusinessAddress) Text(data.businessAddress, style: const TextStyle(fontSize: 9)),
            ]),
            Text('INVOICE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey.shade300, letterSpacing: 4)),
          ]),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SHIP TO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1)),
            Text(data.clientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 9)),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), color: data.themeColor.withValues(alpha: 0.08),
          child: Row(children: [
            const Expanded(flex: 3, child: Text('DESCRIPTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
            const Expanded(flex: 1, child: Text('QTY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            const Expanded(flex: 1, child: Text('RATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            const Expanded(flex: 1, child: Text('TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          ]),
        ),
        Expanded(child: ListView(
          children: data.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(children: [
              Expanded(flex: 3, child: Text(item.desc, style: const TextStyle(fontSize: 10))),
              Expanded(flex: 1, child: Text(item.qty.toString(), style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
              Expanded(flex: 1, child: Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
              Expanded(flex: 1, child: Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            ]),
          )).toList(),
        )),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Subtotal: ${data.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            Text('${data.taxLabel} (${data.taxRate}%): ${data.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12), color: data.themeColor.withValues(alpha: 0.1),
              child: Text('TOTAL: ₹${data.total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: data.themeColor)),
            ),
          ]),
        ]),
      ]),
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Garment Collection',
      businessEmail: 'orders@garmentcollection.in',
      businessPhone: '+91 22 6655 4433',
      businessAddress: '77 Fashion Street, City, State - 400009',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'Preferred Customer',
      clientAddress: 'Local Area',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: Colors.indigo.toARGB32(),
      fontFamily: 'Inter',
      items: [
        InvoiceItem(id: '1', desc: 'Men Blazer - Navy Blue', details: '', qty: 1, rate: 4499),
        InvoiceItem(id: '2', desc: 'Formal Shirt - White', details: '', qty: 3, rate: 1299),
        InvoiceItem(id: '3', desc: 'Silk Tie - Designer', details: '', qty: 2, rate: 599),
        InvoiceItem(id: '4', desc: 'Leather Belt - Brown', details: '', qty: 1, rate: 1499),
      ],
      notes: 'Alteration free within 7 days. Exchange with original tags within 15 days. No refund on sale items.',
      isThermal: false,
    );
  }
}
