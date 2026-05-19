import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final Future<Uint8List> Function(PdfPageFormat) onLayout;
  final String invoiceNumber;
  final VoidCallback onPrintComplete;
  final Uint8List? preGeneratedPdfBytes;

  const InvoicePreviewScreen({
    super.key,
    required this.onLayout,
    required this.invoiceNumber,
    required this.onPrintComplete,
    this.preGeneratedPdfBytes,
  });

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  double _zoomFactor = 1.0;
  Uint8List? _cachedPdf;
  late final Future<Uint8List> _pdfFuture;

  @override
  void initState() {
    super.initState();
    if (widget.preGeneratedPdfBytes != null) {
      _cachedPdf = widget.preGeneratedPdfBytes;
      _pdfFuture = Future.value(widget.preGeneratedPdfBytes);
    } else {
      _pdfFuture = _buildOnce();
    }
  }

  Future<Uint8List> _buildOnce() async {
    final bytes = await widget.onLayout(PdfPageFormat.a4);
    if (mounted) setState(() => _cachedPdf = bytes);
    return bytes;
  }

  void _zoomIn() =>
      setState(() => _zoomFactor = (_zoomFactor + 0.1).clamp(0.5, 2.0));
  void _zoomOut() =>
      setState(() => _zoomFactor = (_zoomFactor - 0.1).clamp(0.5, 2.0));

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const Divider(),
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: _pdfFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Generating invoice…',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to generate invoice: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  final bytes = snapshot.data!;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PdfPreview(
                      // No key — stays alive across zoom changes, re-renders in place.
                      build: (_) async => bytes,
                      allowPrinting: false,
                      allowSharing: false,
                      canChangePageFormat: false,
                      useActions: false,
                      initialPageFormat: PdfPageFormat.a4,
                      maxPageWidth:
                          (screenWidth * _zoomFactor * 1.5).clamp(400.0, 3000.0),
                      onPrinted: (context) => widget.onPrintComplete(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Invoice Preview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.zoom_out, size: 20),
              onPressed: _zoomOut,
              tooltip: 'Zoom Out',
            ),
            Text(
              '${(_zoomFactor * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 20),
              onPressed: _zoomIn,
              tooltip: 'Zoom In',
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final ready = _cachedPdf != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            onPressed: ready
                ? () => Printing.sharePdf(
                      bytes: _cachedPdf!,
                      filename: 'Invoice_${widget.invoiceNumber}.pdf',
                    )
                : null,
            icon: const Icon(Icons.download, size: 20),
            label: const Text(
              'Download PDF',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              elevation: 0,
            ),
            onPressed: ready
                ? () async {
                    await Printing.layoutPdf(
                      name: 'Invoice_${widget.invoiceNumber}',
                      onLayout: (_) async => _cachedPdf!,
                    );
                    widget.onPrintComplete();
                  }
                : null,
            icon: const Icon(Icons.print, size: 20),
            label: const Text(
              'Print Invoice',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
