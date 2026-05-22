import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';

class BistroHalfPageTemplate extends InvoiceTemplate {
  @override
  String get id => 'bistro_half_page';
  @override
  String get name => 'Bistro Half-Page';
  @override
  String get industry => 'RESTAURANT';
  @override
  String get format => 'A5';
  @override
  String get styleName => 'BISTRO';
  @override
  String get previewImagePath =>
      'assets/preview_templates/bistro_half_page_template.png';
  @override
  Color get badgeColor => Colors.amber.shade700;
  @override
  String get metadata => 'Half-page Restaurant Bill';
  @override
  String? get tag => 'DINE-IN';

  // Currency symbol (You can update this to pull from your InvoiceData model if you add it later)
  final String currency = 'Rs';

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
        pageFormat: PdfPageFormat.a5.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  if (data.showLogo && logoImage != null) ...[
                    pw.Container(width: 40, height: 40, child: pw.Image(logoImage)),
                    pw.SizedBox(height: 4),
                  ],
                  pw.Text(data.businessName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accent)),
                  if (data.showBusinessAddress && data.businessAddress.isNotEmpty) 
                    pw.Text(data.businessAddress, style: const pw.TextStyle(fontSize: 8)),
                  if (data.businessPhone.isNotEmpty)
                    pw.Text(data.businessPhone, style: const pw.TextStyle(fontSize: 8)),
                  if (data.businessEmail.isNotEmpty)
                    pw.Text(data.businessEmail, style: const pw.TextStyle(fontSize: 8)),
                  if (data.gstin.isNotEmpty)
                    pw.Text('GSTIN: ${data.gstin}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey300)),
              ]),
              pw.Divider(height: 24, thickness: 1, color: PdfColors.grey200),
              
              // META DATA & CLIENT
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                if (data.showClientContact)
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('CLIENT', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                    pw.SizedBox(height: 4),
                    pw.Text(data.clientName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    if (data.clientAddress.isNotEmpty)
                      pw.Text(data.clientAddress, style: const pw.TextStyle(fontSize: 8)),
                  ])
                else 
                  pw.SizedBox(), // Placeholder to keep alignment if client contact is hidden
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Date: ${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Inv #: ${data.invoiceNumber.isNotEmpty ? data.invoiceNumber : "INV-001"}', style: const pw.TextStyle(fontSize: 8)),
                  if (data.paymentMethod != null && data.paymentMethod!.isNotEmpty) 
                    pw.Text(data.paymentMethod!.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ]),
              ]),
              pw.SizedBox(height: 24),
              
              // TABLE HEADER
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                color: PdfColors.grey100,
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent))),
                    pw.SizedBox(width: 60, child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.center)),
                    pw.SizedBox(width: 60, child: pw.Text('Rate', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.right)),
                    pw.SizedBox(width: 60, child: pw.Text('Amt', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),
              
              // TABLE ITEMS
              ...data.items.map((item) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                child: pw.Row(children: [
                  pw.Expanded(child: pw.Text(item.desc, style: const pw.TextStyle(fontSize: 9))),
                  pw.SizedBox(width: 60, child: pw.Text(item.qty.toString(), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                  pw.SizedBox(width: 60, child: pw.Text(item.rate.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                  pw.SizedBox(width: 60, child: pw.Text(item.amount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ]),
              )),
              pw.Divider(height: 16, thickness: 1, color: PdfColors.grey300),
              
              // TOTALS
              _pdfTotalLine('Subtotal:', '$currency ${data.subtotal.toStringAsFixed(2)}'),
              // Note: If you add discount to models.dart, uncomment this:
              // if (data.discountAmount > 0) _pdfTotalLine('Discount:', '- $currency ${data.discountAmount.toStringAsFixed(2)}'),
              if (data.showTaxBreakdown) 
                _pdfTotalLine('${data.taxLabel} (${data.taxRate}%):', '$currency ${data.taxAmount.toStringAsFixed(2)}'),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent)),
                pw.Text('$currency ${data.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent)),
              ]),
              pw.Divider(height: 16, thickness: 1, color: PdfColors.grey300),
              
              // FOOTER
              pw.Text('Thank you! Visit again.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
              if (data.showNotes && data.notes.isNotEmpty) 
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(data.notes, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                )
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _pdfTotalLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ])
    );
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    return Container(
      width: 380, height: 540, // Keeps standard A5 proportion feeling
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        
        // HEADER (Sync'd with PDF)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (data.showLogo) ...[
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.storefront, size: 24, color: Colors.grey),
                ),
                const SizedBox(height: 4),
              ],
              Text(data.businessName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: data.themeColor)),
              if (data.showBusinessAddress && data.businessAddress.isNotEmpty) 
                Text(data.businessAddress, style: const TextStyle(fontSize: 8)),
              if (data.businessPhone.isNotEmpty) 
                Text(data.businessPhone, style: const TextStyle(fontSize: 8)),
              if (data.businessEmail.isNotEmpty)
                Text(data.businessEmail, style: const TextStyle(fontSize: 8)),
              if (data.gstin.isNotEmpty)
                Text('GSTIN: ${data.gstin}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
            ]),
          ),
          Text('INVOICE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade300)),
        ]),
        const Divider(height: 16),
        
        // META DATA & CLIENT (Sync'd with PDF)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (data.showClientContact) 
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CLIENT', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(data.clientName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              if (data.clientAddress.isNotEmpty) 
                Text(data.clientAddress, style: const TextStyle(fontSize: 8)),
            ])
          else
            const SizedBox(), // Spacer
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Date: ${data.invoiceDate.day}/${data.invoiceDate.month}/${data.invoiceDate.year}', style: const TextStyle(fontSize: 8)),
            Text('Inv #: ${data.invoiceNumber.isNotEmpty ? data.invoiceNumber : "INV-001"}', style: TextStyle(fontSize: 8)),
            if (data.paymentMethod != null && data.paymentMethod!.isNotEmpty) 
              Text(data.paymentMethod!.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
          ]),
        ]),
        const SizedBox(height: 16),
        
        // TABLE HEADER
        Container(
          padding: const EdgeInsets.all(8), color: Colors.grey.shade100,
          child: const Row(children: [
            Expanded(child: Text('Item', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
            SizedBox(width: 50, child: Text('Qty', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            SizedBox(width: 50, child: Text('Rate', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            SizedBox(width: 50, child: Text('Amt', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          ]),
        ),
        
        // TABLE ITEMS
        ...data.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(children: [
            Expanded(child: Text(item.desc, style: const TextStyle(fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis)),
            SizedBox(width: 50, child: Text(item.qty.toString(), style: const TextStyle(fontSize: 9), textAlign: TextAlign.center)),
            SizedBox(width: 50, child: Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 9), textAlign: TextAlign.right)),
            SizedBox(width: 50, child: Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          ]),
        )),
        const Spacer(),
        
        // TOTALS & FOOTER
        _flutterTotalLine('Subtotal:', '$currency ${data.subtotal.toStringAsFixed(2)}'),
        if (data.showTaxBreakdown) 
          _flutterTotalLine('${data.taxLabel} (${data.taxRate}%):', '$currency ${data.taxAmount.toStringAsFixed(2)}'),
        const Divider(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('GRAND TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: data.themeColor)),
          Text('$currency ${data.total.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: data.themeColor)),
        ]),
        const Divider(height: 16),
        const Text('Thank you! Visit again.', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
        if (data.showNotes && data.notes.isNotEmpty) 
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(data.notes, style: const TextStyle(fontSize: 7, color: Colors.black54)),
          )
      ]),
    );
  }

  Widget _flutterTotalLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 9)),
        Text(value, style: const TextStyle(fontSize: 9)),
      ])
    );
  }

  @override
  InvoiceData getDefaultData() {
    return InvoiceData(
      businessName: 'Le Bistro Café',
      businessEmail: 'hello@lebistro.in',
      businessPhone: '+91 22 8877 6655',
      businessAddress: '12 Church Street, City, State - 400005',
      gstin: '27AABCF1234Z1Z5',
      clientName: 'Guest',
      clientAddress: 'Table 5',
      taxLabel: 'GST',
      taxRate: 18,
      themeColorArgb: Colors.amber.toARGB32(),
      fontFamily: 'Inter',
      paymentMethod: 'Credit Card', 
      items: [
        InvoiceItem(id: '1', desc: 'Cappuccino', details: '', qty: 2, rate: 180),
        InvoiceItem(id: '2', desc: 'Blueberry Muffin', details: '', qty: 1, rate: 120),
        InvoiceItem(id: '3', desc: 'Mineral Water', details: '', qty: 1, rate: 60),
      ],
      notes: 'GST included. Service charge not included.',
      isThermal: false,
    );
  }
}