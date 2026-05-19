import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../../features/invoice/invoice_template_editor/models.dart';
import '../../features/invoice/invoice_template_editor/template_engine/template_registry.dart';

Future<Uint8List> generatePdfInIsolate(InvoiceData data, String templateId) async {
  debugPrint('generatePdfInIsolate: starting for template $templateId');

  try {
    final bytes = await Isolate.run(() async {
      final template = TemplateRegistry.getTemplateById(templateId);
      final doc = template.buildPdf(data);
      return doc.save();
    }).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('PDF generation timed out after 30s'),
    );

    debugPrint('generatePdfInIsolate: isolate succeeded, ${bytes.length} bytes');
    return bytes;
  } catch (e) {
    debugPrint('generatePdfInIsolate: isolate failed ($e), falling back to main thread');
    final template = TemplateRegistry.getTemplateById(templateId);
    final doc = template.buildPdf(data);
    final bytes = await doc.save();
    debugPrint('generatePdfInIsolate: main-thread fallback succeeded, ${bytes.length} bytes');
    return bytes;
  }
}
