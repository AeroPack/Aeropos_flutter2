import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/widgets/master_header.dart';
import 'package:aeropos/core/providers/tenant_provider.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/template_repository.dart';
import 'template_engine/invoice_template.dart';
import 'template_engine/template_registry.dart';

class SelectionScreen extends ConsumerStatefulWidget {
  final Function(String) onEdit;

  const SelectionScreen({super.key, required this.onEdit});

  @override
  ConsumerState<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends ConsumerState<SelectionScreen> {
  String activeFormat = 'Thermal Receipt';
  String activeIndustry = 'All Industries';
  InvoiceTemplate? _previewTemplate;
  String? _hoveredTemplateId;
  int currentPage = 1;
  static const int itemsPerPage = 8;

  static const _formatMap = {
    'Thermal Receipt': 'THERMAL',
    'A5 Half-Page': 'A5',
    'A4 Full-Page': 'A4',
  };

  final List<String> formats = [
    'Thermal Receipt',
    'A5 Half-Page',
    'A4 Full-Page',
  ];

  final List<InvoiceTemplate> templates = TemplateRegistry.availableTemplates
      .cast<InvoiceTemplate>();

  List<String> get _availableIndustries {
    final unique = templates.map((t) => t.industry).toSet().toList();
    unique.sort();
    return ['All Industries', ...unique];
  }

  List<InvoiceTemplate> get filteredTemplates {
    return templates.where((t) {
      final fmt = _formatMap[activeFormat];
      final formatMatch = t.format.toUpperCase() == fmt;
      final industryMatch = activeIndustry == 'All Industries' ||
          t.industry.toUpperCase() == activeIndustry.toUpperCase();
      return formatMatch && industryMatch;
    }).toList();
  }

  List<InvoiceTemplate> get paginatedTemplates {
    final start = (currentPage - 1) * itemsPerPage;
    return filteredTemplates.skip(start).take(itemsPerPage).toList();
  }

  int get totalPages => (filteredTemplates.length / itemsPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Scaffold(
      appBar: MasterHeader(
        showSidebarToggle: false,
        isDesktop: !isMobile,
        hidePosButton: true,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
              onPressed: () => context.go('/dashboard'),
              tooltip: 'Back to Dashboard',
            ),
            InkWell(
              onTap: () => context.go('/dashboard'),
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Icon(Icons.storefront, color: Color(0xFF0F172A), size: 28),
                    SizedBox(width: 8),
                    Text(
                      "Aero",
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "POS",
                      style: TextStyle(
                        color: Color.fromARGB(255, 0, 191, 255),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : (isTablet ? 24 : 40),
                vertical: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(screenWidth),
                  const SizedBox(height: 24),
                  _buildFormatTabs(),
                  const SizedBox(height: 24),
                  _buildIndustryFilters(),
                  const SizedBox(height: 32),
                  _buildTemplateGrid(screenWidth),
                  if (totalPages > 1) ...[
                    const SizedBox(height: 48),
                    _buildPagination(screenWidth),
                  ],
                ],
              ),
            ),
          ),
          if (_previewTemplate != null) _buildImagePreview(),
        ],
      ),
    );
  }

  Widget _buildPageHeader(double width) {
    final isMobile = width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select POS Template',
          style: TextStyle(
            fontSize: isMobile ? 32 : 40,
            fontWeight: FontWeight.w900,
            color: Colors.grey.shade900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose a bill format optimized for your industry',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildFormatTabs() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: formats.map((format) {
            final isActive = format == activeFormat;
            return GestureDetector(
              onTap: () => setState(() {
                activeFormat = format;
                currentPage = 1;
              }),
              child: Container(
                padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                margin: const EdgeInsets.only(right: 32),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  format,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? Colors.grey.shade900
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIndustryFilters() {
    final chips = _availableIndustries;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((industry) {
          final isActive = industry == activeIndustry;
          return GestureDetector(
            onTap: () => setState(() {
              activeIndustry = industry;
              currentPage = 1;
            }),
            child: Container(
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isActive ? Colors.blue : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Center(
                child: Text(
                  industry,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTemplateGrid(double width) {
    int crossAxisCount = 5;
    if (width < 600) {
      crossAxisCount = 1;
    } else if (width < 900) {
      crossAxisCount = 2;
    } else if (width < 1200) {
      crossAxisCount = 3;
    } else if (width < 1500) {
      crossAxisCount = 4;
    }

    final items = paginatedTemplates;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No templates found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Try a different format or industry filter',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: width < 600 ? 16 : 32,
        mainAxisSpacing: width < 600 ? 16 : 32,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildTemplateCard(items[index]);
      },
    );
  }

  Widget _buildTemplateCard(InvoiceTemplate template) {
    final activeTemplateAsync = ref.watch(activeTemplateProvider);
    final isCurrentlyActive = activeTemplateAsync.value?.id == template.id;
    final isHovered = _hoveredTemplateId == template.id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTemplateId = template.id),
      onExit: (_) => setState(() => _hoveredTemplateId = null),
      cursor: SystemMouseCursors.click,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrentlyActive
                          ? Colors.blue
                          : Colors.grey.shade200,
                      width: isCurrentlyActive ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: template.previewImagePath.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: template.previewImagePath,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => const SizedBox(),
                            errorWidget: (_, _, _) => _buildPlaceholder(template),
                          )
                        : Image.asset(
                            template.previewImagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(template),
                          ),
                  ),
                ),
                // Dark overlay — only on hover
                if (isHovered)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade900.withValues(alpha: 0.65),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _overlayButton(
                                label: 'Preview',
                                color: Colors.white,
                                textColor: Colors.grey.shade700,
                                onTap: () => setState(
                                  () => _previewTemplate = template,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _overlayButton(
                                label: 'Use Template',
                                color: Colors.blue,
                                textColor: Colors.white,
                                onTap: () => _activateTemplate(template),
                              ),
                              const SizedBox(height: 8),
                              _overlayButton(
                                label: 'Customize',
                                color: Colors.transparent,
                                textColor: Colors.white,
                                border: Border.all(color: Colors.white70),
                                onTap: () => widget.onEdit(template.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Always-visible badges (top-left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _badge(
                        '${template.industry} | ${template.format}',
                        Colors.blue,
                      ),
                      const SizedBox(height: 6),
                      _badge(template.styleName, template.badgeColor),
                      if (isCurrentlyActive) ...[
                        const SizedBox(height: 6),
                        _badge('ACTIVE', Colors.green),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    template.metadata,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    template.tag?.toUpperCase() ?? '',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overlayButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
    BoxBorder? border,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color,
          border: border,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(InvoiceTemplate template, {bool large = false}) {
    return Container(
      height: large ? 300 : null,
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: large ? 48 : 28, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              template.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: large ? 14 : 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Preview not available',
              style: TextStyle(
                fontSize: large ? 12 : 9,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activateTemplate(InvoiceTemplate template) async {
    final repo = ref.read(invoiceTemplateRepositoryProvider);
    final tenantId = ref.read(tenantIdProvider);
    try {
      await repo.saveTemplateSelection(
        tenantId: tenantId,
        templateId: template.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${template.name} activated'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to activate template'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPagination(double width) {
    final count = filteredTemplates.length;
    final start = (currentPage - 1) * itemsPerPage + 1;
    final end = (start + itemsPerPage - 1).clamp(0, count);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Text(
          'Showing $start-$end of $count templates',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pageNavButton(
              icon: Icons.chevron_left,
              onPressed: currentPage > 1
                  ? () => setState(() => currentPage--)
                  : null,
            ),
            const SizedBox(width: 8),
            ...List.generate(totalPages.clamp(1, 7), (i) {
              final page = i + 1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _pageNumberButton(page, page == currentPage),
              );
            }),
            if (totalPages > 7) ...[
              Text(
                '...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 8),
              _pageNumberButton(totalPages, false),
            ],
            _pageNavButton(
              icon: Icons.chevron_right,
              onPressed: currentPage < totalPages
                  ? () => setState(() => currentPage++)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _pageNavButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(
          color: onPressed != null ? Colors.grey.shade300 : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: onPressed != null
              ? Colors.grey.shade600
              : Colors.grey.shade300,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _pageNumberButton(int page, bool isActive) {
    return GestureDetector(
      onTap: isActive
          ? null
          : () => setState(() => currentPage = page),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : null,
          border: isActive ? null : Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final template = _previewTemplate!;
    final imagePath = template.previewImagePath;
    return GestureDetector(
      onTap: () => setState(() => _previewTemplate = null),
      child: Container(
        color: Colors.grey.shade900.withValues(alpha: 0.8),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.7,
                          ),
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: imagePath.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: imagePath,
                                    fit: BoxFit.contain,
                                    placeholder: (_, _) => const SizedBox(),
                                    errorWidget: (_, _, _) => _buildPlaceholder(template, large: true),
                                  )
                                : Image.asset(
                                    imagePath,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildPlaceholder(template, large: true),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => setState(() => _previewTemplate = null),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${template.industry} · ${template.format} · ${template.styleName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => setState(() => _previewTemplate = null),
                            child: const Text('Close'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _previewTemplate = null);
                              _activateTemplate(template);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Use This Template'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
