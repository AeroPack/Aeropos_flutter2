import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../template_engine/invoice_template.dart';
import '../models.dart';
import '../../../../core/utils/upi_qr.dart';

class DesignSystemsIndiaTemplate extends InvoiceTemplate {
  @override
  String get id => 'default_a4';
  @override
  String get name => 'Design Systems India';
  @override
  String get industry => 'RETAIL';
  @override
  String get format => 'A4';
  @override
  String get styleName => 'PROFESSIONAL';
  @override
  String get previewImagePath =>
      'assets/preview_templates/design_systems_india_template.png';
  @override
  Color get badgeColor => const Color(0xFF13a4ec);
  @override
  String get metadata => 'Modern Corporate Layout';
  @override
  String? get tag => 'DEFAULT A4';

  @override
  pw.Document buildPdf(InvoiceData data) {
    final pdf = pw.Document();
    final accentColor = PdfColor.fromInt(data.themeColorArgb);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero, // Zero margin to allow full-width wave
        build: (context) {
          return wrapWithFont(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Wave Header
              pw.Container(
                height: 160,
                width: double.infinity,
                child: pw.Stack(
                  children: [
                    pw.Positioned.fill(
                      child: pw.CustomPaint(
                        painter: (PdfGraphics canvas, PdfPoint size) {
                          canvas.setFillColor(accentColor);
                          // In PDF, (0,0) is the bottom-left of the CustomPaint box
                          canvas.moveTo(0, size.y);
                          canvas.lineTo(size.x, size.y);
                          canvas.lineTo(size.x, 60);
                          // cubic curve to create the wave
                          canvas.curveTo(
                            size.x * 0.6, 90, 
                            size.x * 0.4, 20, 
                            0, 40
                          );
                          canvas.lineTo(0, size.y);
                          canvas.fillPath();
                        },
                      ),
                    ),
                    pw.Positioned(
                      top: 40,
                      left: 32,
                      right: 32,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'INVOICE',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 36,
                              letterSpacing: 2,
                            ),
                          ),
                          pw.Text(
                            data.invoiceNumber.isNotEmpty ? 'NO: ${data.invoiceNumber}' : 'NO: INV-001',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Padded Body
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Bill To / From Section
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Bill To
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Bill To:',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey800,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                data.clientName,
                                style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
                              ),
                              pw.Text(
                                data.clientPhone.isNotEmpty ? data.clientPhone : "+123-456-7890", 
                                style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
                              ),
                              pw.Text(
                                data.clientAddress,
                                style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
                              ),
                            ],
                          ),
                          // From
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'From:',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey800,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                data.businessName,
                                style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
                              ),
                              pw.Text(
                                data.businessPhone,
                                style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
                              ),
                              pw.Text(
                                data.businessAddress,
                                style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),

                      pw.SizedBox(height: 24),

                      // Date
                      pw.Text(
                        'Date: ${data.invoiceDate.day} ${_getMonth(data.invoiceDate.month)} ${data.invoiceDate.year}',
                        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                      ),

                      pw.SizedBox(height: 24),

                      // Table
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(4),
                          1: const pw.FlexColumnWidth(1),
                          2: const pw.FlexColumnWidth(1.5),
                          3: const pw.FlexColumnWidth(1.5),
                        },
                        children: [
                          // Table Header
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: accentColor),
                            children: [
                              _pdfHeaderCell('Description', pw.TextAlign.left),
                              _pdfHeaderCell('Qty', pw.TextAlign.center),
                              _pdfHeaderCell('Price', pw.TextAlign.center),
                              _pdfHeaderCell('Total', pw.TextAlign.center),
                            ],
                          ),
                          // Table Rows
                          ...data.items.map((item) => pw.TableRow(
                            children: [
                              _pdfDataCell(item.desc, pw.TextAlign.left),
                              _pdfDataCell(item.qty.toString(), pw.TextAlign.center),
                              _pdfDataCell('Rs ${item.rate.toStringAsFixed(2)}', pw.TextAlign.center),
                              _pdfDataCell('Rs ${item.amount.toStringAsFixed(2)}', pw.TextAlign.center),
                            ],
                          )),
                        ],
                      ),

                      pw.SizedBox(height: 16),

                      // Sub Total Box
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Container(
                                width: 220,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Sub Total', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                    pw.Text('Rs ${data.subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
                                  ],
                                ),
                              ),
                              if (data.showTaxBreakdown && data.cgstTotal > 0) ...[
                                pw.Container(
                                  width: 220,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('CGST', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                      pw.Text('Rs ${data.cgstTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
                                    ],
                                  ),
                                ),
                                pw.Container(
                                  width: 220,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('SGST', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                      pw.Text('Rs ${data.sgstTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
                                    ],
                                  ),
                                ),
                              ] else if (data.showTaxBreakdown && data.taxAmount > 0) ...[
                                pw.Container(
                                  width: 220,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(data.taxLabel.isNotEmpty ? data.taxLabel : 'Tax', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                      pw.Text('Rs ${data.taxAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
                                    ],
                                  ),
                                ),
                              ],
                              pw.Container(
                                width: 220,
                                color: accentColor,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Total', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                    pw.Text('Rs ${data.total.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      pw.Spacer(),

                      // Footer Content
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          // Notes and Payment Info
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Lines for Note
                              pw.Text('Note:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                              pw.Container(width: 150, height: 1, color: PdfColors.grey400, margin: const pw.EdgeInsets.only(top: 4, bottom: 6)),
                              pw.Container(width: 150, height: 1, color: PdfColors.grey400, margin: const pw.EdgeInsets.only(bottom: 6)),
                              pw.Container(width: 150, height: 1, color: PdfColors.grey400, margin: const pw.EdgeInsets.only(bottom: 24)),

                              // Payment Info
                              if (data.showBankDetails && data.bankName.isNotEmpty) ...[
                                pw.Text('Payment Information:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                                pw.SizedBox(height: 6),
                                _pdfPaymentRow('Bank:', data.bankName),
                                _pdfPaymentRow('A/C No:', data.bankAccountNo),
                                _pdfPaymentRow('IFSC:', data.bankIfsc),
                              ],
                              if (data.showUpiQr && data.upiId.isNotEmpty) ...[
                                pw.SizedBox(height: 8),
                                pw.Text('UPI QR:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                pw.SizedBox(height: 4),
                                pw.Container(
                                  width: 80, height: 80,
                                  child: pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(),
                                    data: buildUpiUri(upiId: data.upiId, amount: data.grandTotal, invoiceNo: data.invoiceNumber),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          
                          // Thank You text
                          pw.Text(
                            'Thank You!',
                            style: pw.TextStyle(
                              fontSize: 28,
                              color: accentColor,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      pw.SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ), data);
        },
      ),
    );
    return pdf;
  }

  pw.Widget _pdfHeaderCell(String text, pw.TextAlign align) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: align,
      ),
    );
  }

  pw.Widget _pdfDataCell(String text, pw.TextAlign align) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
        textAlign: align,
      ),
    );
  }

  pw.Widget _pdfPaymentRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Container(
            width: 60,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey800)),
          ),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget buildFlutterPreview(InvoiceData data) {
    final accentColor = data.themeColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wave Header
        ClipPath(
          clipper: WaveClipper(),
          child: Container(
            height: 160,
            width: double.infinity,
            color: accentColor,
            padding: const EdgeInsets.only(top: 40, left: 32, right: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INVOICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  data.invoiceNumber.isNotEmpty ? 'NO: ${data.invoiceNumber}' : 'NO: INV-001',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Padded Body
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Bill To / From Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bill To:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(data.clientName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(data.clientPhone.isNotEmpty ? data.clientPhone : "+123-456-7890", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(data.clientAddress, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('From:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(data.businessName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(data.businessPhone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(data.businessAddress, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Date: ${data.invoiceDate.day} ${_getMonth(data.invoiceDate.month)} ${data.invoiceDate.year}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 24),

              // Table
              Table(
                border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
                columnWidths: const {
                  0: FlexColumnWidth(4),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: accentColor),
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12), child: Text('Description', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12), child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12), child: Text('Price', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12), child: Text('Total', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  ...data.items.map((item) => TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), child: Text(item.desc, style: const TextStyle(color: Colors.grey, fontSize: 11))),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), child: Text(item.qty.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11))),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), child: Text('Rs ${item.rate.toStringAsFixed(2)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11))),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), child: Text('Rs ${item.amount.toStringAsFixed(2)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11))),
                    ],
                  )),
                ],
              ),

              const SizedBox(height: 16),

              // Totals breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 220,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sub Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text('Rs ${data.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      if (data.showTaxBreakdown && data.cgstTotal > 0) ...[
                        SizedBox(
                          width: 220,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('CGST', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('Rs ${data.cgstTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('SGST', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('Rs ${data.sgstTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ] else if (data.showTaxBreakdown && data.taxAmount > 0) ...[
                        SizedBox(
                          width: 220,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(data.taxLabel.isNotEmpty ? data.taxLabel : 'Tax', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('Rs ${data.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      Container(
                        width: 220,
                        color: accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Rs ${data.total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 60),

              // Footer Content
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Note:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Container(width: 150, height: 1, color: Colors.grey.shade400, margin: const EdgeInsets.only(top: 4, bottom: 6)),
                      Container(width: 150, height: 1, color: Colors.grey.shade400, margin: const EdgeInsets.only(bottom: 6)),
                      Container(width: 150, height: 1, color: Colors.grey.shade400, margin: const EdgeInsets.only(bottom: 24)),

                      if (data.showBankDetails && data.bankName.isNotEmpty) ...[
                        const Text('Payment Information:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        _flutterPaymentRow('Bank:', data.bankName),
                        _flutterPaymentRow('A/C No:', data.bankAccountNo),
                        _flutterPaymentRow('IFSC:', data.bankIfsc),
                      ],
                      if (data.showUpiQr && data.upiId.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('UPI QR:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        const SizedBox(height: 4),
                        const Icon(Icons.qr_code_2, size: 48),
                      ],
                    ],
                  ),
                  
                  Text(
                    'Thank You!',
                    style: TextStyle(
                      fontSize: 28,
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _flutterPaymentRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
          ),
          Text(value, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  InvoiceData getDefaultData() {
    // Retained your original default data so it matches your existing setup
    return InvoiceData(
      businessName: "Design Systems India Pvt. Ltd.",
      businessEmail: "billing@dsindia.in",
      businessPhone: "+91 98765 43210",
      businessAddress: "402, Business Hub, BKC, Mumbai, Maharashtra 400051",
      gstin: "27AAAAA0000A1Z5",
      clientName: "Global Tech Solutions",
      clientAddress: "12th Floor, Prestige Tech Park, Bangalore, KA 560103",
      taxLabel: "GST",
      taxRate: 18,
      themeColorArgb: const Color(0xFF0A3D7B).toARGB32(), // Deep Blue matching the new wave design
      fontFamily: "Inter",
      items: [
        InvoiceItem(
          id: '1',
          desc: 'UI/UX Design - Dashboard',
          details: 'High-fidelity prototypes for admin panel',
          qty: 40,
          rate: 1200,
        ),
        InvoiceItem(
          id: '2',
          desc: 'React Implementation',
          details: 'Frontend components development',
          qty: 25,
          rate: 1500,
        ),
      ],
      notes:
          "Please include the invoice number in your bank transfer description. Payment is due within 15 days of the invoice date.",
      isThermal: false,
    );
  }
}

// Custom Clipper for Flutter Preview Header
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    // Top-left to bottom-left
    path.lineTo(0, size.height - 40);
    // Cubic bezier curve for wave effect
    path.cubicTo(
        size.width * 0.4, size.height + 20, 
        size.width * 0.6, size.height - 90, 
        size.width, size.height - 60);
    // Bottom-right to top-right
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}