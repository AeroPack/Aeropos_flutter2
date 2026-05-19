import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class FashionistaA5Template extends InvoiceTemplate {
  @override
  String get id => 'fashionista_a5';
  @override
  String get name => 'Fashionista A5';
  @override
  String get industry => 'GARMENT';
  @override
  String get format => 'A5';
  @override
  String get styleName => 'ELEGANT';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1626266061368-46a8f578ddd6?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => Colors.purple;
  @override
  String get metadata => 'Half-page Boutique Invoice';
  @override
  String? get tag => 'BOUTIQUE';

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
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                color: accent,
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    if (data.showLogo && logoImage != null)
                      pw.Container(width: 35, height: 35, child: pw.Image(logoImage)),
                    pw.Text(data.businessName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ]),
                  pw.Text('INVOICE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.grey300)),
                ]),
              ),
              pw.SizedBox(height: 16),
              if (data.showBusinessAddress)
                pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text(data.businessPhone, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.SizedBox(height: 12),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('${data.taxLabel}: ${data.gstin}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  if (data.showClientContact) ...[
                    pw.SizedBox(height: 8),
                    pw.Text('BILL TO', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                    pw.Text(data.clientName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Inv #: INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}', style: const pw.TextStyle(fontSize: 8)),
                  if (data.paymentMethod != null) pw.Text(data.paymentMethod!.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ]),
              ]),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                color: PdfColors.grey100,
                child: pw.Row(children: [
                  pw.Expanded(child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent))),
                  pw.SizedBox(width: 60, child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.center)),
                  pw.SizedBox(width: 70, child: pw.Text('Rate', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.right)),
                  pw.SizedBox(width: 70, child: pw.Text('Amt', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.right)),
                ]),
              ),
              ...data.items.map((item) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                child: pw.Row(children: [
                  pw.Expanded(child: pw.Text(item.desc, style: const pw.TextStyle(fontSize: 9))),
                  pw.SizedBox(width: 60, child: pw.Text(item.qty.toString(), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                  pw.SizedBox(width: 70, child: pw.Text(item.rate.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                  pw.SizedBox(width: 70, child: pw.Text(item.amount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ]),
              )),
              pw.Divider(height: 16, thickness: 1),
              _pdfTotalLine('Subtotal:', data.subtotal.toStringAsFixed(2)),
              _pdfTotalLine('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                color: PdfColors.grey100,
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent)),
                  pw.Text('₹${data.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent)),
                ]),
              ),
              pw.Divider(height: 16, thickness: 1),
              pw.Text('Thank you for your purchase!', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
              if (data.showNotes && data.notes.isNotEmpty) pw.Text(data.notes, style: const pw.TextStyle(fontSize: 7)),
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _pdfTotalLine(String label, String value) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 9)),
      pw.Text(value, style: pw.TextStyle(fontSize: 9)),
    ]);
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    return Container(
      width: 380, height: 540,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12), color: data.themeColor,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(data.businessName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('INVOICE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.7))),
          ]),
        ),
        const SizedBox(height: 12),
        if (data.showBusinessAddress) Text(data.businessAddress, style: const TextStyle(fontSize: 8, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${data.taxLabel}: ${data.gstin}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
            if (data.showClientContact) ...[
              const SizedBox(height: 4),
              Text('BILL TO', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
              Text(data.clientName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ]),
          Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 8)),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), color: Colors.grey.shade100,
          child: Row(children: [
            const Expanded(child: Text('Item', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
            SizedBox(width: 60, child: Text('Qty', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            SizedBox(width: 70, child: Text('Rate', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            SizedBox(width: 70, child: Text('Amt', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          ]),
        ),
        ...data.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(children: [
            Expanded(child: Text(item.desc, style: const TextStyle(fontSize: 9))),
            SizedBox(width: 60, child: Text(item.qty.toString(), style: const TextStyle(fontSize: 9), textAlign: TextAlign.center)),
            SizedBox(width: 70, child: Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 9), textAlign: TextAlign.right)),
            SizedBox(width: 70, child: Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          ]),
        )),
        const Spacer(),
        _totalLine('Subtotal:', data.subtotal.toStringAsFixed(2)),
        _totalLine('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
        const Divider(height: 4),
        Container(
          padding: const EdgeInsets.all(8), color: data.themeColor.withValues(alpha: 0.1),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('TOTAL:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: data.themeColor)),
            Text(data.total.toStringAsFixed(2), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: data.themeColor)),
          ]),
        ),
      ]),
    );
  }

  Widget _totalLine(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 9)),
      Text(value, style: const TextStyle(fontSize: 9)),
    ]);
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Fashionista Boutique',
      businessEmail: 'info@fashionista.in',
      businessPhone: '+91 22 9988 1122',
      businessAddress: '55 Style Avenue, City, State - 400006',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'Valued Customer',
      clientAddress: 'Local Area',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: Colors.purple.toARGB32(),
      fontFamily: 'Inter',
      items: [
        InvoiceItem(id: '1', desc: 'Designer Saree', details: '', qty: 1, rate: 3999),
        InvoiceItem(id: '2', desc: 'Earrings (Gold Plated)', details: '', qty: 2, rate: 599),
        InvoiceItem(id: '3', desc: 'Handcrafted Clutch', details: '', qty: 1, rate: 1499),
      ],
      notes: 'Exchange within 15 days with tags intact. No refund on sale items.',
      isThermal: false,
    );
  }
}
