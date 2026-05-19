import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../helpers/thermal_utils.dart';
import '../models.dart';

class TechBillThermalTemplate extends InvoiceTemplate {
  @override
  String get id => 'tech_bill_thermal';
  @override
  String get name => 'TechBill Thermal';
  @override
  String get industry => 'ELECTRONICS';
  @override
  String get format => 'THERMAL';
  @override
  String get styleName => 'TECH';
  @override
  String get previewImagePath =>
      'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&q=80&w=400';
  @override
  Color get badgeColor => Colors.blueGrey;
  @override
  String get metadata => '58mm/72mm/80mm optimized';
  @override
  String? get tag => 'WARRANTY';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();
    final mmWidth = thermalWidthInPoints(data.thermalWidth);
    final rollFormat = PdfPageFormat(mmWidth, double.infinity, marginAll: 8);

    pw.MemoryImage? logoImage;
    if (data.showLogo && data.logoBytes != null) {
      logoImage = pw.MemoryImage(data.logoBytes!);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: rollFormat,
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (data.showLogo && logoImage != null)
                pw.Container(width: 45, height: 45, child: pw.Image(logoImage)),
              pw.Text(data.businessName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              if (data.showBusinessAddress)
                pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
              pw.Text('${data.taxLabel}: ${data.gstin}', style: const pw.TextStyle(fontSize: 7)),
              pw.Divider(thickness: 1, color: PdfColors.black),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('Time: ${DateTime.now().hour}:${DateTime.now().minute}', style: const pw.TextStyle(fontSize: 7)),
              ]),
              if (data.showClientContact) ...[
                pw.Text('Customer: ${data.clientName}', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('Address: ${data.clientAddress}', style: const pw.TextStyle(fontSize: 7)),
              ],
              if (data.paymentMethod != null)
                pw.Text('Payment: ${data.paymentMethod!.toUpperCase()}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Divider(thickness: 1, color: PdfColors.black),
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
              pw.Divider(thickness: 1, color: PdfColors.black),
              _totalRow('Subtotal:', data.subtotal.toStringAsFixed(2)),
              if (data.showTaxBreakdown) ...[
                _totalRow('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
              ],
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('₹${data.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Divider(thickness: 1, color: PdfColors.black, height: 12),
              pw.Text('Warranty: 1 year from purchase date', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              if (data.showNotes && data.notes.isNotEmpty) pw.Text(data.notes, style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 8),
              pw.Text('--- TechBill by AeroPOS ---', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
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
            Image.memory(data.logoBytes!, height: 45, width: 45),
            const SizedBox(height: 8),
          ],
          Text(data.businessName.toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
          if (data.showBusinessAddress) Text(data.businessAddress, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center),
          Text('${data.taxLabel}: ${data.gstin}', style: const TextStyle(fontSize: 7)),
          const Divider(height: 12, thickness: 1),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 7)),
            Text('Time: ${DateTime.now().hour}:${DateTime.now().minute}', style: const TextStyle(fontSize: 7)),
          ]),
          if (data.showClientContact) Text('Customer: ${data.clientName}', style: const TextStyle(fontSize: 7)),
          if (data.paymentMethod != null) Text('Payment: ${data.paymentMethod!.toUpperCase()}', style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
          const Divider(height: 12, thickness: 1),
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
          const Divider(height: 12, thickness: 1),
          _flutterTotalRow('Subtotal:', data.subtotal.toStringAsFixed(2)),
          _flutterTotalRow('${data.taxLabel} (${data.taxRate}%):', data.taxAmount.toStringAsFixed(2)),
          const Divider(height: 4, thickness: 1),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('TOTAL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text(data.total.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          const Divider(height: 12, thickness: 1),
          const Text('Warranty: 1 year', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
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
      businessName: 'TechBill Electronics',
      businessEmail: 'support@techbill.in',
      businessPhone: '+91 22 3344 5566',
      businessAddress: '88 Tech Park, City, State - 400004',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'Mr. Customer',
      clientAddress: 'Local Area',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: Colors.blueGrey.toARGB32(),
      fontFamily: 'Mono',
      items: [
        InvoiceItem(id: '1', desc: 'Wireless Mouse', details: 'SN: WM-001', qty: 1, rate: 599),
        InvoiceItem(id: '2', desc: 'USB-C Hub 7-in-1', details: 'SN: UB-002', qty: 2, rate: 1299),
        InvoiceItem(id: '3', desc: 'Bluetooth Speaker', details: 'SN: BT-003', qty: 1, rate: 2499),
      ],
      notes: 'Product warranty: 1 year from invoice date. Please retain this receipt for warranty claims.',
      isThermal: true,
    );
  }
}
