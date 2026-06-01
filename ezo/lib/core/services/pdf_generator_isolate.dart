import 'package:flutter/foundation.dart';
import '../../features/invoice/invoice_template_editor/models.dart';
import '../../features/invoice/invoice_template_editor/template_engine/template_registry.dart';
import 'pdf_worker.dart';

/// Generates a PDF.
///
/// On native platforms this delegates to [PdfWorker] (a persistent background
/// isolate) so the pdf layout engine stays JIT-warm across calls.
///
/// On web (where dart:isolate is unavailable) it generates directly on the
/// main thread, which is still fast because [InvoiceTemplate.buildPdf] is
/// synchronous.
Future<Uint8List> generatePdfInIsolate(
  InvoiceData data,
  String templateId,
) async {
  final t0 = DateTime.now();
  debugPrint('[PDF] generate start — template=$templateId');

  final Uint8List bytes;
  if (kIsWeb) {
    final template = TemplateRegistry.getTemplateById(templateId);
    final doc = template.buildPdf(data);
    bytes = await doc.save();
  } else {
    bytes = await PdfWorker.instance.generate(data, templateId);
  }

  debugPrint(
    '[PDF] generate done — ${DateTime.now().difference(t0).inMilliseconds} ms'
    ' (${bytes.length} bytes)',
  );
  return bytes;
}
