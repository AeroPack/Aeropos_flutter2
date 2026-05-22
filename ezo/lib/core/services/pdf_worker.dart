import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/invoice/invoice_template_editor/models.dart';
import '../../features/invoice/invoice_template_editor/template_engine/template_registry.dart';

// ─── Wire types (plain Dart — no closures, no platform handles) ───────────────

class _Req {
  final int id;
  final InvoiceData data;
  final String templateId;
  _Req(this.id, this.data, this.templateId);
}

class _Res {
  final int id;
  final Uint8List? bytes;
  final String? error;
  _Res.ok(this.id, Uint8List b) : bytes = b, error = null;
  _Res.err(this.id, String e) : bytes = null, error = e;
}

// ─── Singleton worker ──────────────────────────────────────────────────────────

/// Long-lived background isolate that keeps the pdf layout engine JIT-warm.
///
/// Call [start] once at app launch (fire-and-forget). The isolate pre-warms
/// itself by generating a trivial one-page PDF so the JIT is compiled before
/// the user taps "View Invoice". Real generation then takes ~300–800 ms instead
/// of 3–12 s on the first cold call.
class PdfWorker {
  PdfWorker._();
  static final instance = PdfWorker._();

  ReceivePort? _fromWorker;
  SendPort? _toWorker;
  int _nextId = 0;
  final _pending = <int, Completer<Uint8List>>{};
  final _ready = Completer<void>();

  /// Fire-and-forget. Safe to call multiple times.
  /// No-op on web since dart:isolate is unsupported.
  void start() {
    if (kIsWeb) return;
    if (_fromWorker != null) return;
    _fromWorker = ReceivePort('pdf-worker-rx');
    _fromWorker!.listen(_onMessage);
    Isolate.spawn(
      _workerEntry,
      _fromWorker!.sendPort,
      debugName: 'pdf-worker',
      errorsAreFatal: false,
    ).then((_) {
      debugPrint('[PdfWorker] isolate spawned');
    }).catchError((Object e) {
      debugPrint('[PdfWorker] spawn failed: $e');
      if (!_ready.isCompleted) _ready.completeError(e);
    });
  }

  void _onMessage(dynamic msg) {
    if (msg is SendPort) {
      _toWorker = msg;
      if (!_ready.isCompleted) _ready.complete();
      return;
    }
    if (msg is _Res) {
      final c = _pending.remove(msg.id);
      if (c == null) return;
      if (msg.bytes != null) {
        c.complete(msg.bytes!);
      } else {
        c.completeError(msg.error ?? 'PDF generation failed');
      }
    }
  }

  Future<Uint8List> generate(InvoiceData data, String templateId) async {
    if (kIsWeb) {
      throw UnsupportedError('PdfWorker uses dart:isolate which is not available on web');
    }
    start();
    await _ready.future;
    final id = _nextId++;
    final c = Completer<Uint8List>();
    _pending[id] = c;
    _toWorker!.send(_Req(id, data, templateId));
    return c.future;
  }

  // ─── Runs inside the background isolate ─────────────────────────────────────

  static void _workerEntry(SendPort sendToMain) async {
    final fromMain = ReceivePort('pdf-worker-tx');
    sendToMain.send(fromMain.sendPort);

    // Pre-warm: compile pdf layout engine before any real request arrives.
    final warmStart = DateTime.now();
    try {
      final doc = pw.Document();
      doc.addPage(pw.Page(build: (_) => pw.SizedBox()));
      await doc.save();
      debugPrint(
        '[PdfWorker] warmup done in '
        '${DateTime.now().difference(warmStart).inMilliseconds} ms',
      );
    } catch (e) {
      debugPrint('[PdfWorker] warmup error (non-fatal): $e');
    }

    await for (final msg in fromMain) {
      if (msg is! _Req) continue;
      final t0 = DateTime.now();
      try {
        final tpl = TemplateRegistry.getTemplateById(msg.templateId);
        final tBuild = DateTime.now();
        final doc = tpl.buildPdf(msg.data);
        debugPrint(
          '[PdfWorker] buildPdf: '
          '${DateTime.now().difference(tBuild).inMilliseconds} ms',
        );
        final tSave = DateTime.now();
        final bytes = await doc.save();
        debugPrint(
          '[PdfWorker] doc.save: ${DateTime.now().difference(tSave).inMilliseconds} ms'
          ' | total: ${DateTime.now().difference(t0).inMilliseconds} ms',
        );
        sendToMain.send(_Res.ok(msg.id, bytes));
      } catch (e) {
        debugPrint('[PdfWorker] error id=${msg.id}: $e');
        sendToMain.send(_Res.err(msg.id, e.toString()));
      }
    }
  }
}
