import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../helpers/thermal_utils.dart';
import '../models.dart';

class StyleCraftThermalTemplate extends InvoiceTemplate {
  @override
  String get id => 'style_craft_thermal';
  @override
  String get name => 'StyleCraft Thermal';
  @override
  String get industry => 'GARMENT';
  @override
  String get format => 'THERMAL';
  @override
  String get styleName => 'CHIC';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1626266061368-46a8f578ddd6?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => Colors.pink.shade400;
  @override
  String get metadata => '58mm/72mm/80mm optimized';
  @override
  String? get tag => 'BOUTIQUE';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();
    final mmWidth = thermalWidthInPoints(data.thermalWidth);
    final rollFormat = PdfPageFormat(mmWidth, double.infinity, marginAll: 8);

    pw.MemoryImage? logoImage;
    if (data.showLogo && data.logoBytes != null) {
      logoImage = pw.MemoryImage(data.logoBytes!);
    }

    final accent = PdfColor.fromInt(data.themeColorArgb);

    pdf.addPage(
      pw.Page(
        pageFormat: rollFormat,
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                color: accent,
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: pw.Text(
                  data.businessName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 2),
                ),
              ),
              pw.SizedBox(height: 6),
              if (data.showLogo && logoImage != null)
                pw.Container(width: 40, height: 40, child: pw.Image(logoImage)),
              if (data.showBusinessAddress)
                pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
              pw.Text('${data.taxLabel}: ${data.gstin}', style: const pw.TextStyle(fontSize: 7)),
              pw.Divider(thickness: 1, color: accent),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('Time: ${DateTime.now().hour}:${DateTime.now().minute}', style: const pw.TextStyle(fontSize: 7)),
              ]),
              if (data.paymentMethod != null)
                pw.Text('Payment: ${data.paymentMethod!.toUpperCase()}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: accent)),
              pw.Divider(thickness: 1, color: accent),
              pw.Table(
                columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1)},
                children: [
                  pw.TableRow(children: [
                    _cell('Item', pw.TextAlign.left, bold: true, accent: accent),
                    _cell('Qty', pw.TextAlign.center, bold: true, accent: accent),
                    _cell('Rate', pw.TextAlign.right, bold: true, accent: accent),
                    _cell('Amt', pw.TextAlign.right, bold: true, accent: accent),
                  ]),
                  ...data.items.map((item) => pw.TableRow(children: [
                    _cell(item.desc, pw.TextAlign.left),
                    _cell(item.qty.toString(), pw.TextAlign.center),
                    _cell(item.rate.toStringAsFixed(2), pw.TextAlign.right),
                    _cell(item.amount.toStringAsFixed(2), pw.TextAlign.right),
                  ])),
                ],
              ),
              pw.Divider(thickness: 1, color: accent),
              _totalRow('Subtotal:', data.subtotal.toStringAsFixed(2)),
              _totalRow('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accent)),
                pw.Text('₹${data.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accent)),
              ]),
              pw.Divider(thickness: 1, color: accent, height: 12),
              pw.Text('Style that speaks!', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
              if (data.showNotes && data.notes.isNotEmpty) pw.Text(data.notes, style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 8),
              pw.Text('--- StyleCraft POS ---', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _cell(String text, pw.TextAlign align, {bool bold = false, PdfColor? accent}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 7, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: bold ? accent : null), textAlign: align),
    );
  }

  pw.Widget _totalRow(String label, String value) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
      pw.Text(value, style: const pw.TextStyle(fontSize: 7)),
    ]);
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    return SizedBox(
      width: 300,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Container(
            color: data.themeColor,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Text(data.businessName.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
          ),
          const SizedBox(height: 6),
          if (data.showBusinessAddress) Text(data.businessAddress, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center),
          Text('${data.taxLabel}: ${data.gstin}', style: const TextStyle(fontSize: 7)),
          const Divider(height: 12, thickness: 1),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 7)),
            Text('Time: ${DateTime.now().hour}:${DateTime.now().minute}', style: const TextStyle(fontSize: 7)),
          ]),
          if (data.paymentMethod != null) Text('Payment: ${data.paymentMethod!.toUpperCase()}', style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
          const Divider(height: 12, thickness: 1),
          Table(
            columnWidths: const {0: FlexColumnWidth(2), 1: FixedColumnWidth(40), 2: FixedColumnWidth(50), 3: FixedColumnWidth(50)},
            children: [
              TableRow(children: [
                Text('Item', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: data.themeColor)),
                Text('Qty', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: data.themeColor), textAlign: TextAlign.center),
                Text('Rate', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: data.themeColor), textAlign: TextAlign.right),
                Text('Amt', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: data.themeColor), textAlign: TextAlign.right),
              ]),
              ...data.items.map((item) => TableRow(children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(item.desc, style: const TextStyle(fontSize: 8))),
                Text(item.qty.toString(), style: const TextStyle(fontSize: 8), textAlign: TextAlign.center),
                Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right),
                Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right),
              ])),
            ],
          ),
          const Divider(height: 12, thickness: 1),
          _flutterTotalRow('Subtotal:', data.subtotal.toStringAsFixed(2)),
          _flutterTotalRow('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
          const Divider(height: 4, thickness: 1),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('TOTAL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: data.themeColor)),
            Text(data.total.toStringAsFixed(2), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: data.themeColor)),
          ]),
          const Divider(height: 12, thickness: 1),
          const Text('Style that speaks!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          if (data.showNotes && data.notes.isNotEmpty) Text(data.notes, style: const TextStyle(fontSize: 7), textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _flutterTotalRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 8)),
      Text(value, style: const TextStyle(fontSize: 8)),
    ]);
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'StyleCraft Boutique',
      businessEmail: 'hello@stylecraft.in',
      businessPhone: '+91 22 7766 5544',
      businessAddress: '42 Fashion Avenue, City, State - 400003',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'Walk-in Customer',
      clientAddress: 'Local Area',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: Colors.pink.toARGB32(),
      fontFamily: 'Mono',
      items: [
        InvoiceItem(id: '1', desc: 'Cotton Kurti', details: 'Size: M', qty: 2, rate: 899),
        InvoiceItem(id: '2', desc: 'Silk Dupatta', details: 'Color: Red', qty: 1, rate: 1299),
        InvoiceItem(id: '3', desc: 'Jutta (Pair)', details: 'Size: 7', qty: 1, rate: 599),
      ],
      notes: 'Exchange within 15 days with original tags. No refund on sale items.',
      isThermal: true,
    );
  }
}
