import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class GrocerySaverA5Template extends InvoiceTemplate {
  @override
  String get id => 'grocery_saver_a5';
  @override
  String get name => 'Grocery Saver A5';
  @override
  String get industry => 'GROCERY';
  @override
  String get format => 'A5';
  @override
  String get styleName => 'SAVER';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => Colors.green.shade500;
  @override
  String get metadata => 'Half-page Grocery Bill';
  @override
  String? get tag => 'VALUE';

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
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  if (data.showLogo && logoImage != null) ...[
                    pw.Container(width: 40, height: 40, child: pw.Image(logoImage)),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(data.businessName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accent)),
                    if (data.showBusinessAddress) pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(data.businessPhone, style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('${data.taxLabel}: ${data.gstin}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('Inv #: INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}', style: const pw.TextStyle(fontSize: 7)),
                ]),
              ]),
              if (data.paymentMethod != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text('Payment: ${data.paymentMethod!.toUpperCase()}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent)),
                ),
              pw.Divider(height: 16, thickness: 1, color: accent),
              pw.Table(
                columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(2)},
                children: [
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent))),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text('Rate', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text('Amt', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.right)),
                  ]),
                  ...data.items.map((item) => pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(item.desc, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(item.qty.toString(), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(item.rate.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(item.amount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  ])),
                ],
              ),
              pw.Divider(height: 12, thickness: 1, color: accent),
              _pdfTotalLine('Subtotal:', data.subtotal.toStringAsFixed(2)),
              if (data.showTaxBreakdown) _pdfTotalLine('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: accent)),
                pw.Text('₹${data.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: accent)),
              ]),
              pw.Divider(height: 12, thickness: 1, color: accent),
              pw.Text('Thank you for shopping with us!', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              if (data.showNotes && data.notes.isNotEmpty) pw.Text(data.notes, style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 8),
              pw.Text('--- AeroPOS Retail ---', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
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
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.businessName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: data.themeColor)),
            if (data.showBusinessAddress) Text(data.businessAddress, style: const TextStyle(fontSize: 8)),
            Text(data.businessPhone, style: const TextStyle(fontSize: 8)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${data.taxLabel}: ${data.gstin}', style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
            Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 7)),
          ]),
        ]),
        const Divider(height: 16),
        Table(
          columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(2)},
          children: [
            TableRow(children: [
              Text('Item', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: data.themeColor)),
              Text('Qty', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: data.themeColor), textAlign: TextAlign.center),
              Text('Rate', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: data.themeColor), textAlign: TextAlign.right),
              Text('Amt', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: data.themeColor), textAlign: TextAlign.right),
            ]),
            ...data.items.map((item) => TableRow(children: [
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(item.desc, style: const TextStyle(fontSize: 8))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(item.qty.toString(), style: const TextStyle(fontSize: 8), textAlign: TextAlign.center)),
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right)),
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            ])),
          ],
        ),
        const Divider(height: 12),
        _flutterTotalLine('Subtotal:', data.subtotal.toStringAsFixed(2)),
        _flutterTotalLine('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: data.themeColor)),
          Text(data.total.toStringAsFixed(2), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: data.themeColor)),
        ]),
      ]),
    );
  }

  Widget _flutterTotalLine(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 9)),
      Text(value, style: const TextStyle(fontSize: 9)),
    ]);
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Grocery Saver Mart',
      businessEmail: 'info@grocerysaver.in',
      businessPhone: '+91 22 7766 4433',
      businessAddress: '99 Market Road, City, State - 400007',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'Walk-in Customer',
      clientAddress: 'Local Area',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: Colors.green.toARGB32(),
      fontFamily: 'Inter',
      items: [
        InvoiceItem(id: '1', desc: 'Wheat Flour (5kg)', details: '', qty: 2, rate: 175),
        InvoiceItem(id: '2', desc: 'Toor Dal (1kg)', details: '', qty: 1, rate: 120),
        InvoiceItem(id: '3', desc: 'Refined Oil (1L)', details: '', qty: 3, rate: 160),
      ],
      notes: 'Prices include GST. Check expiry before purchase.',
      isThermal: false,
    );
  }
}
