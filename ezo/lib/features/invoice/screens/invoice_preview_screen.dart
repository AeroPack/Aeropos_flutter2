import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:aeropos/core/layout/pos_design_system.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:drift/drift.dart' show TypedResult;

import 'package:aeropos/features/invoice/invoice_template_editor/template_repository.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/models.dart' as editor_models;
import 'package:aeropos/features/invoice/invoice_template_editor/template_engine/invoice_template.dart';
import 'package:aeropos/core/providers/tenant_provider.dart';
import 'package:aeropos/core/utils/number_to_words.dart';
import 'package:aeropos/core/services/pdf_generator_isolate.dart';

class InvoicePreviewScreen extends ConsumerStatefulWidget {
  final InvoiceEntity invoiceEntity;
  final CustomerEntity? customer;
  final List<TypedResult> items;

  const InvoicePreviewScreen({
    super.key,
    required this.invoiceEntity,
    this.customer,
    required this.items,
  });

  @override
  ConsumerState<InvoicePreviewScreen> createState() =>
      _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen> {
  double _zoomLevel = 1.0;

  // Set once per template — prevents re-generation on zoom or parent rebuilds.
  String? _buildingForTemplateId;
  Future<Uint8List>? _pdfFuture;

  void _zoomIn() =>
      setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 2.0));
  void _zoomOut() =>
      setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 2.0));

  Future<Uint8List> _buildPdf(InvoiceTemplate template, int tenantId) async {
    final repo = ref.read(invoiceTemplateRepositoryProvider);
    final (data: invoiceData, templateId: templateId) =
        await repo.getHydratedInvoiceData(tenantId, null);

    invoiceData.clientName = widget.customer?.name ?? 'Walk-in Customer';
    invoiceData.clientAddress = widget.customer?.address ?? '';
    invoiceData.showClientContact = widget.customer != null;
    invoiceData.invoiceNumber = widget.invoiceEntity.invoiceNumber;
    invoiceData.invoiceDate = widget.invoiceEntity.date;
    invoiceData.paymentMethod = widget.invoiceEntity.paymentMethod ?? '';
    invoiceData.totalDiscount = widget.invoiceEntity.discount;
    invoiceData.clientPhone = widget.customer?.phone ?? '';
    invoiceData.clientEmail = widget.customer?.email ?? '';
    invoiceData.clientGstin = widget.customer?.gstin ?? '';
    invoiceData.amountInWords = convertToIndianRupees(widget.invoiceEntity.total);

    invoiceData.items = widget.items.map((res) {
      final itemRow =
          res.readTable(ServiceLocator.instance.database.invoiceItems);
      final productRow =
          res.readTable(ServiceLocator.instance.database.products);
      return editor_models.InvoiceItem(
        id: itemRow.id.toString(),
        desc: productRow.name,
        details: '',
        qty: itemRow.quantity.toDouble(),
        rate: itemRow.unitPrice,
      );
    }).toList();

    return generatePdfInIsolate(invoiceData, templateId);
  }

  @override
  Widget build(BuildContext context) {
    final templateAsync = ref.watch(activeTemplateProvider);
    final tenantId = ref.watch(tenantIdProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text('Preview: ${widget.invoiceEntity.invoiceNumber}'),
        backgroundColor: PosColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
            tooltip: 'Zoom Out',
          ),
          Center(
            child: Text(
              '${(_zoomLevel * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
            tooltip: 'Zoom In',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: templateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Template Error: $err')),
        data: (activeTemplate) {
          if (activeTemplate == null) {
            return const Center(
              child: Text('No active template selected.'),
            );
          }
          // Build only once per template. Zoom changes skip this block.
          if (_buildingForTemplateId != activeTemplate.id) {
            _buildingForTemplateId = activeTemplate.id;
            _pdfFuture = _buildPdf(activeTemplate, tenantId);
          }
          return FutureBuilder<Uint8List>(
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
              return Column(
                children: [
                  Expanded(
                    child: PdfPreview(
                      build: (_) async => bytes,
                      canDebug: false,
                      canChangePageFormat: false,
                      maxPageWidth:
                          (screenWidth * _zoomLevel * 1.5).clamp(400.0, 3000.0),
                      onPrinted: (context) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invoice sent to printer'),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildDownloadBar(bytes),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDownloadBar(Uint8List bytes) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => Printing.sharePdf(
              bytes: bytes,
              filename: 'Invoice_${widget.invoiceEntity.invoiceNumber}.pdf',
            ),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }
}
