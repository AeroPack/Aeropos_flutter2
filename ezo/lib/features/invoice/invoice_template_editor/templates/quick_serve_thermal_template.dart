import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../helpers/thermal_utils.dart';
import '../models.dart';

class QuickServeThermalTemplate extends InvoiceTemplate {
  @override
  String get id => 'quick_serve_thermal';
  @override
  String get name => 'Quick Serve Thermal';
  @override
  String get industry => 'RETAIL';
  @override
  String get format => 'THERMAL';
  @override
  String get styleName => 'SPEEDY';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => Colors.orange.shade600;
  @override
  String get metadata => '58mm/72mm/80mm optimized';
  @override
  String? get tag => 'RETAIL READY';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();
    final mmWidth = thermalWidthInPoints(data.thermalWidth);
    final rollFormat = PdfPageFormat(mmWidth, double.infinity, marginAll: 8);

    pw.MemoryImage? logoImage;
    if (data.showLogo && data.logoBytes != null) {
      logoImage = pw.MemoryImage(data.logoBytes!);
    }
    final themePdfColor = PdfColor.fromInt(data.themeColorArgb);

    pdf.addPage(
      pw.Page(
        pageFormat: rollFormat,
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (data.showLogo && logoImage != null)
                pw.Container(
                  width: 50, height: 50,
                  child: pw.Image(logoImage),
                ),
              pw.Text(
                data.businessName.toUpperCase(),
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, letterSpacing: 1, color: themePdfColor),
              ),
              if (data.showBusinessAddress)
                pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
              pw.Text('${data.taxLabel}: ${data.gstin}', style: const pw.TextStyle(fontSize: 7)),
              pw.Divider(thickness: 1, color: themePdfColor),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('Time: ${DateTime.now().hour}:${DateTime.now().minute}', style: const pw.TextStyle(fontSize: 7)),
              ]),
              if (data.paymentMethod != null)
                pw.Text('Payment: ${data.paymentMethod!.toUpperCase()}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Divider(thickness: 1, color: themePdfColor),
              pw.Table(
                columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1)},
                children: [
                  pw.TableRow(children: [
                    _cell('Item', pw.TextAlign.left, bold: true),
                    _cell('Qty', pw.TextAlign.center, bold: true),
                    _cell('Rate', pw.TextAlign.right, bold: true),
                    _cell('Amt', pw.TextAlign.right, bold: true),
                  ]),
                  ...data.items.map((item) => pw.TableRow(children: [
                    _cell(item.desc, pw.TextAlign.left),
                    _cell(item.qty.toString(), pw.TextAlign.center),
                    _cell(item.rate.toStringAsFixed(2), pw.TextAlign.right),
                    _cell(item.amount.toStringAsFixed(2), pw.TextAlign.right),
                  ])),
                ],
              ),
              pw.Divider(thickness: 1, color: themePdfColor),
              _totalRow('Subtotal:', data.subtotal.toStringAsFixed(2)),
              _totalRow('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('₹${data.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Divider(thickness: 1, color: themePdfColor),
              pw.Text('Thank you for your purchase!', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: themePdfColor)),
              if (data.showNotes && data.notes.isNotEmpty) pw.Text(data.notes, style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 10),
              pw.Text('--- Quick Serve POS ---', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _cell(String text, pw.TextAlign align, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 7, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal), textAlign: align),
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
          if (data.showLogo && data.logoBytes != null) ...[
            Image.memory(data.logoBytes!, height: 50, width: 50),
            const SizedBox(height: 12),
          ],
          Text(data.businessName.toUpperCase(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1, color: data.themeColor)),
          if (data.showBusinessAddress) Text(data.businessAddress, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center),
          Text('${data.taxLabel}: ${data.gstin}', style: const TextStyle(fontSize: 7)),
          Divider(height: 12, thickness: 1, color: data.themeColor),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 7)),
            Text('Time: ${DateTime.now().hour}:${DateTime.now().minute}', style: const TextStyle(fontSize: 7)),
          ]),
          if (data.paymentMethod != null) Text('Payment: ${data.paymentMethod!.toUpperCase()}', style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
          Divider(height: 12, thickness: 1, color: data.themeColor),
          Table(
            columnWidths: const {0: FlexColumnWidth(2), 1: FixedColumnWidth(40), 2: FixedColumnWidth(50), 3: FixedColumnWidth(50)},
            children: [
              const TableRow(children: [
                Text('Item', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                Text('Qty', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                Text('Rate', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                Text('Amt', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
              ]),
              ...data.items.map((item) => TableRow(children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(item.desc, style: const TextStyle(fontSize: 8))),
                Text(item.qty.toString(), style: const TextStyle(fontSize: 8), textAlign: TextAlign.center),
                Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right),
                Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right),
              ])),
            ],
          ),
          Divider(height: 12, thickness: 1, color: data.themeColor),
          _flutterTotalRow('Subtotal:', data.subtotal.toStringAsFixed(2)),
          _flutterTotalRow('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
          Divider(height: 4, thickness: 1, color: data.themeColor),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('TOTAL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text(data.total.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          Divider(height: 12, thickness: 1, color: data.themeColor),
          const Text('Thank you!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
      businessName: 'Quick Serve Retail',
      businessEmail: 'info@quickserve.com',
      businessPhone: '+91 22 1234 5678',
      businessAddress: '456 Main Road, City, State - 400001',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'Walk-in Customer',
      clientAddress: 'Local Area',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: Colors.orange.toARGB32(),
      fontFamily: 'Mono',
      items: [
        InvoiceItem(id: '1', desc: 'Bottled Water (1L)', details: '', qty: 6, rate: 20),
        InvoiceItem(id: '2', desc: 'Potato Chips', details: '', qty: 3, rate: 30),
        InvoiceItem(id: '3', desc: 'Cooking Oil (1L)', details: '', qty: 1, rate: 185),
        InvoiceItem(id: '4', desc: 'White Bread', details: '', qty: 2, rate: 35),
      ],
      notes: 'Items once sold cannot be returned',
      isThermal: true,
    );
  }
}
