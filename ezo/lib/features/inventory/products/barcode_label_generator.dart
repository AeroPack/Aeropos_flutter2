import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Describes a single label for batch generation.
class LabelSpec {
  final String productName;
  final String barcodeValue;
  final double? sellingPrice; // Kept for fallback/backward compatibility
  final int quantity;
  final String barcodeTypeKey;
  
  // NEW: Template and Dynamic Fields
  final String templateKey;
  final Map<String, String> dynamicFields;

  const LabelSpec({
    required this.productName,
    required this.barcodeValue,
    this.sellingPrice,
    this.quantity = 1,
    this.barcodeTypeKey = 'code128',
    this.templateKey = 'standard',
    this.dynamicFields = const {},
  });
}

/// Maps a string key to a pw.Barcode instance.
pw.Barcode _mapBarcodeType(String key) {
  switch (key.toLowerCase()) {
    case 'ean13': return pw.Barcode.ean13();
    case 'upca': return pw.Barcode.upcA();
    case 'qr': return pw.Barcode.qrCode();
    case 'datamatrix': return pw.Barcode.dataMatrix();
    case 'code39': return pw.Barcode.code39();
    default: return pw.Barcode.code128();
  }
}

/// Generates a 2" × 1" thermal label PDF for a single product unit barcode.
Future<Uint8List> generateBarcodeLabel({
  required String productName,
  required String barcodeValue,
  double? sellingPrice,
  String? unitName,
}) async {
  return generateBatchBarcodeLabels(
    labels: [
      LabelSpec(
        productName: productName,
        barcodeValue: barcodeValue,
        sellingPrice: sellingPrice,
        quantity: 1,
      ),
    ],
  );
}

/// Generates a multi-page PDF with one 2"×1" label per page for each item.
Future<Uint8List> generateBatchBarcodeLabels({
  required List<LabelSpec> labels,
}) async {
  final doc = pw.Document();
  const format = PdfPageFormat(2 * 72.0, 1 * 72.0);

  for (final label in labels) {
    for (int i = 0; i < label.quantity; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          build: (context) {
            // Route to the correct layout based on templateKey
            switch (label.templateKey) {
              case 'compact':
                return _buildCompactLayout(label);
              case 'barcode_only':
                return _buildBarcodeOnlyLayout(label);
              case 'standard':
              default:
                return _buildStandardLayout(label);
            }
          },
        ),
      );
    }
  }

  return doc.save();
}

// ==========================================
// TEMPLATE LAYOUT BUILDERS
// ==========================================

pw.Widget _buildStandardLayout(LabelSpec label) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      // 1. Product Name (Header)
      pw.Text(
        label.productName,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 2),
      
      // 2. Barcode Graphic
      pw.BarcodeWidget(
        barcode: _mapBarcodeType(label.barcodeTypeKey),
        data: label.barcodeValue,
        height: 24, // Slightly shorter to make room for dynamic fields
        width: double.infinity,
        drawText: false,
      ),
      pw.SizedBox(height: 1),
      
      // 3. Barcode Text Value
      pw.Text(
        label.barcodeValue,
        style: const pw.TextStyle(fontSize: 5),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 2),

      // 4. Dynamic Fields (e.g., Price, SKU, Weight)
      if (label.dynamicFields.isNotEmpty)
        pw.Wrap(
          alignment: pw.WrapAlignment.center,
          spacing: 4,
          runSpacing: 1,
          children: label.dynamicFields.entries.map((entry) {
            return pw.Text(
              '${entry.key}: ${entry.value}',
              style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold),
            );
          }).toList(),
        )
      else if (label.sellingPrice != null) ...[
        // Fallback for older implementation
        pw.Text(
          'Rs${label.sellingPrice!.toStringAsFixed(2)}',
          style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
      ],
    ],
  );
}

pw.Widget _buildCompactLayout(LabelSpec label) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    mainAxisAlignment: pw.MainAxisAlignment.center,
    children: [
      // 1. Barcode Graphic (Larger, takes priority)
      pw.BarcodeWidget(
        barcode: _mapBarcodeType(label.barcodeTypeKey),
        data: label.barcodeValue,
        height: 32,
        width: double.infinity,
        drawText: false,
      ),
      pw.SizedBox(height: 2),
      
      // 2. Barcode Text Value
      pw.Text(
        label.barcodeValue,
        style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
      
      // 3. Dynamic Fields (No Name Header, strictly fields below barcode)
      if (label.dynamicFields.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Wrap(
          alignment: pw.WrapAlignment.center,
          spacing: 6,
          children: label.dynamicFields.values.map((value) {
            // In compact mode, we might drop the label keys (e.g., just show "$10.00" instead of "Price: $10.00")
            return pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 5),
            );
          }).toList(),
        ),
      ]
    ],
  );
}

pw.Widget _buildBarcodeOnlyLayout(LabelSpec label) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    mainAxisAlignment: pw.MainAxisAlignment.center,
    children: [
      // 1. Barcode Graphic (Maximum size)
      pw.Expanded(
        child: pw.BarcodeWidget(
          barcode: _mapBarcodeType(label.barcodeTypeKey),
          data: label.barcodeValue,
          width: double.infinity,
          drawText: false,
        ),
      ),
      pw.SizedBox(height: 2),
      
      // 2. Barcode Text Value
      pw.Text(
        label.barcodeValue,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    ],
  );
}