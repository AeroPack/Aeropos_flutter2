import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/providers/tenant_provider.dart';
import 'package:aeropos/core/utils/number_to_words.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/template_repository.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/models.dart'
    as editor_models;
import 'package:aeropos/core/services/pdf_generator_isolate.dart';
import 'package:drift/drift.dart' show TypedResult;

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

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen>
    with SingleTickerProviderStateMixin {
  double _zoomLevel = 1.0;
  late final Future<Uint8List> _pdfFuture;
  Uint8List? _pdfBytes;
  late final AnimationController _progressController;

  static const _navy = Color(0xFF0F172A);
  static const _navyLight = Color(0xFF1E293B);
  static const _accent = Color(0xFF3B82F6);
  static const _surface = Color(0xFF1A2332);

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..forward();
    _pdfFuture = _generatePdf();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<Uint8List> _generatePdf() async {
    final t0 = DateTime.now();
    debugPrint('[PDF_SCREEN] start — inv=${widget.invoiceEntity.invoiceNumber}');

    final tenantId = ref.read(tenantIdProvider);
    final repo = ref.read(invoiceTemplateRepositoryProvider);

    final (data: invoiceData, templateId: templateId) =
        await repo.getHydratedInvoiceData(tenantId, null);

    debugPrint(
      '[PDF_SCREEN] hydrate: ${DateTime.now().difference(t0).inMilliseconds} ms',
    );

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
    invoiceData.amountInWords =
        convertToIndianRupees(widget.invoiceEntity.total);

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

    final t1 = DateTime.now();
    final bytes = await generatePdfInIsolate(invoiceData, templateId);
    debugPrint(
      '[PDF_SCREEN] worker round-trip: ${DateTime.now().difference(t1).inMilliseconds} ms'
      ' | TOTAL: ${DateTime.now().difference(t0).inMilliseconds} ms',
    );

    if (mounted) setState(() => _pdfBytes = bytes);
    return bytes;
  }

  void _zoomIn() =>
      setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 3.0));
  void _zoomOut() =>
      setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 3.0));
  void _resetZoom() => setState(() => _zoomLevel = 1.0);

  // DPI scaled per screen class. Values chosen so the rendered A4 image is
  // always wider than the display container → Flutter downscales → crisp.
  // Mobile gets a lower cap to prevent OOM on constrained Android devices.
  double _dpiFor(double w) {
    if (w < 640) return 120.0;  // phone  → A4 ≈  992 px wide
    if (w < 1024) return 160.0; // tablet → A4 ≈ 1323 px wide
    return 220.0;                // desktop → A4 ≈ 1818 px wide
  }

  // Base page width at zoom = 1.0.
  double _basePageWidth(double w) {
    if (w < 640) return w;         // phone: full width
    if (w < 1024) return w * 0.90; // tablet: 90 %
    return w * 0.75;               // desktop: 75 %
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 640;

    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(screenWidth, isMobile),
      body: FutureBuilder<Uint8List>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _buildLoadingState(screenWidth, isMobile);
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          return _buildPdfViewer(snapshot.data!, screenWidth);
        },
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(double screenWidth, bool isMobile) {
    final inv = widget.invoiceEntity;

    // Mobile: standard-height bar, icon-only actions to avoid overflow.
    if (isMobile) {
      return AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          inv.invoiceNumber,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          _ZoomIconButton(
            icon: Icons.remove,
            onTap: _zoomOut,
            enabled: _zoomLevel > 0.5,
          ),
          _ZoomIconButton(
            icon: Icons.add,
            onTap: _zoomIn,
            enabled: _zoomLevel < 3.0,
          ),
          const SizedBox(width: 4),
          if (_pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.download_outlined,
                  color: Colors.white, size: 20),
              onPressed: () => Printing.sharePdf(
                bytes: _pdfBytes!,
                filename: 'Invoice_${inv.invoiceNumber}.pdf',
              ),
              tooltip: 'Download',
            ),
          const SizedBox(width: 4),
        ],
      );
    }

    // Tablet / Desktop: tall bar with meta chips and labelled action buttons.
    final isTablet = screenWidth < 1024;
    final dateStr = DateFormat('MMM d, yyyy').format(inv.date);
    final amountStr =
        'Rs ${NumberFormat('#,##,##0.00', 'en_IN').format(inv.total)}';

    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        color: _navy,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isTablet) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _metaChip(dateStr, Icons.calendar_today_outlined),
                            const SizedBox(width: 8),
                            _metaChip(amountStr, Icons.currency_rupee),
                            if (inv.paymentMethod != null) ...[
                              const SizedBox(width: 8),
                              _metaChip(
                                inv.paymentMethod!.toUpperCase(),
                                Icons.payment_outlined,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _zoomControl(),
                const SizedBox(width: 4),
                _VerticalDivider(),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.print_outlined,
                  label: isTablet ? '' : 'Print',
                  enabled: _pdfBytes != null,
                  onTap: _pdfBytes == null
                      ? null
                      : () async {
                          await Printing.layoutPdf(
                            name: 'Invoice_${inv.invoiceNumber}',
                            onLayout: (_) async => _pdfBytes!,
                          );
                        },
                ),
                const SizedBox(width: 6),
                _ActionButton(
                  icon: Icons.download_outlined,
                  label: isTablet ? '' : 'Download',
                  isPrimary: true,
                  enabled: _pdfBytes != null,
                  onTap: _pdfBytes == null
                      ? null
                      : () => Printing.sharePdf(
                            bytes: _pdfBytes!,
                            filename: 'Invoice_${inv.invoiceNumber}.pdf',
                          ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Colors.white38),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _zoomControl() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomIconButton(
            icon: Icons.remove,
            onTap: _zoomOut,
            enabled: _zoomLevel > 0.5,
          ),
          GestureDetector(
            onTap: _resetZoom,
            child: SizedBox(
              width: 44,
              child: Text(
                '${(_zoomLevel * 100).toInt()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _ZoomIconButton(
            icon: Icons.add,
            onTap: _zoomIn,
            enabled: _zoomLevel < 3.0,
          ),
        ],
      ),
    );
  }

  // ── Loading state ─────────────────────────────────────────────────────────

  Widget _buildLoadingState(double screenWidth, bool isMobile) {
    final inv = widget.invoiceEntity;
    final customerName = widget.customer?.name ?? 'Walk-in Customer';
    final amountStr =
        'Rs ${NumberFormat('#,##,##0.00', 'en_IN').format(inv.total)}';
    final cardWidth =
        isMobile ? (screenWidth - 48).clamp(0.0, 400.0) : 320.0;

    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        final progress = _progressController.value;
        final pct = (progress * 100).toInt();

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        value: progress,
                        color: _accent,
                        backgroundColor: _accent.withValues(alpha: 0.12),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _navyLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF60A5FA),
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Preparing Invoice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Building PDF — this takes a moment…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _navyLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Invoice', inv.invoiceNumber, isCode: true),
                      const SizedBox(height: 12),
                      _detailRow(
                        'Date',
                        DateFormat('MMM d, yyyy  HH:mm').format(inv.date),
                      ),
                      const SizedBox(height: 12),
                      _detailRow('Customer', customerName),
                      const SizedBox(height: 12),
                      _detailRow('Amount', amountStr, isAmount: true),
                      if (inv.paymentMethod != null) ...[
                        const SizedBox(height: 12),
                        _detailRow('Payment', inv.paymentMethod!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: cardWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Generating PDF…',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: const TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isCode = false,
    bool isAmount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isAmount ? const Color(0xFF60A5FA) : Colors.white,
              fontSize: isAmount ? 14 : 13,
              fontWeight:
                  isCode || isAmount ? FontWeight.w700 : FontWeight.w500,
              fontFamily: isCode || isAmount ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF7F1D1D).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFF87171),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Generate Invoice',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Go Back'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF60A5FA)),
            ),
          ],
        ),
      ),
    );
  }

  // ── PDF viewer ────────────────────────────────────────────────────────────

  Widget _buildPdfViewer(Uint8List bytes, double screenWidth) {
    final base = _basePageWidth(screenWidth);
    final maxWidth = (base * _zoomLevel).clamp(160.0, 3000.0);

    return PdfPreview(
      build: (_) async => bytes,
      canDebug: false,
      canChangePageFormat: false,
      allowPrinting: false,
      allowSharing: false,
      useActions: false,
      // Fixed DPI per screen class ensures the rendered bitmap is always
      // larger than the displayed container → downscale path → crisp output.
      dpi: _dpiFor(screenWidth),
      maxPageWidth: maxWidth,
      scrollViewDecoration: BoxDecoration(color: _surface),
      pdfPreviewPageDecoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _ZoomIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _ZoomIconButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool enabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isPrimary = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    final hasLabel = label.isNotEmpty;
    return Material(
      color: isPrimary
          ? (active
              ? const Color(0xFF2563EB)
              : Colors.white.withValues(alpha: 0.06))
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hasLabel ? 12 : 8,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
              ),
              if (hasLabel) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
