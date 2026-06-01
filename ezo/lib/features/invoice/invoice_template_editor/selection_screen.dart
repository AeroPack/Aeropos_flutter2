import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/widgets/master_header.dart';
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
  String activeFormat = 'A4 Full-Page';
  String activeIndustry = 'All Industries';
  String searchQuery = '';
  String sortBy = 'Popular';

  // Premium Color Palette
  final Color primaryColor = const Color.fromARGB(255, 70, 155, 229);
  final Color backgroundLight = const Color(0xFFFAFAFA);
  final Color textDark = const Color(0xFF111827);
  final Color textMuted = const Color(0xFF6B7280);

  final Set<String> _favoriteTemplates = {};
  int currentPage = 1;
  static const int itemsPerPage = 8;

  static const _formatMap = {
    'A4 Full-Page': 'A4',
    'A5 Half-Page': 'A5',
    'Thermal Receipt': 'THERMAL',
  };

  final List<String> formats = [
    'A4 Full-Page',
    'A5 Half-Page',
    'Thermal Receipt',
  ];

  final List<String> sortOptions = ['Popular', 'Alphabetical'];

  final List<InvoiceTemplate> templates = TemplateRegistry.availableTemplates
      .cast<InvoiceTemplate>();

  List<String> get _availableIndustries {
    final unique = templates.map((t) => t.industry).toSet().toList();
    unique.sort();
    return ['All Industries', ...unique];
  }

  List<InvoiceTemplate> get filteredTemplates {
    var filtered = templates.where((t) {
      final fmt = _formatMap[activeFormat];
      final formatMatch = t.format.toUpperCase() == fmt;
      final industryMatch =
          activeIndustry == 'All Industries' ||
          t.industry.toUpperCase() == activeIndustry.toUpperCase();
      final searchMatch =
          searchQuery.isEmpty ||
          t.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          t.metadata.toLowerCase().contains(searchQuery.toLowerCase());

      return formatMatch && industryMatch && searchMatch;
    }).toList();

    if (sortBy == 'Alphabetical') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    }

    return filtered;
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
      backgroundColor: backgroundLight,
      appBar: MasterHeader(
        showSidebarToggle: false,
        isDesktop: !isMobile,
        hidePosButton: true,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textDark),
              onPressed: () => context.go('/dashboard'),
              tooltip: 'Back to Dashboard',
            ),
            InkWell(
              onTap: () => context.go('/dashboard'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.storefront, color: textDark, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      "Aero",
                      style: TextStyle(
                        color: textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      "POS",
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
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
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1400),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : (isTablet ? 32 : 48),
                  vertical: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPageHeader(isMobile),
                    const SizedBox(height: 32),
                    _buildToolbar(),
                    const SizedBox(height: 24),
                    _buildIndustryFilters(),
                    const SizedBox(height: 40),
                    _buildTemplateGrid(screenWidth),
                    if (totalPages > 1) ...[
                      const SizedBox(height: 56),
                      _buildPagination(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Template Library',
          style: TextStyle(
            fontSize: isMobile ? 32 : 40,
            fontWeight: FontWeight.w800,
            color: textDark,
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Discover and customize professional invoice designs tailored for your business.',
          style: TextStyle(
            fontSize: isMobile ? 15 : 16,
            color: textMuted,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    // Wrap prevents any RenderFlex overflow errors on smaller screens
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildFormatTabs(),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [_buildSearchBar(), _buildSortDropdown()],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 240,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        onChanged: (val) {
          setState(() {
            searchQuery = val;
            currentPage = 1;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search templates...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: sortBy,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: TextStyle(
            color: textDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          items: sortOptions.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                sortBy = newValue;
                currentPage = 1;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildFormatTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: formats.map((format) {
          final isActive = format == activeFormat;
          return GestureDetector(
            onTap: () => setState(() {
              activeFormat = format;
              currentPage = 1;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                format,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? textDark : textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIndustryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _availableIndustries.map((industry) {
          final isActive = industry == activeIndustry;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() {
                activeIndustry = industry;
                currentPage = 1;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive ? textDark : Colors.white,
                  border: Border.all(
                    color: isActive ? textDark : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  industry,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.white : textDark,
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
    int crossAxisCount = 4;
    if (width < 600) {
      crossAxisCount = 1;
    } else if (width < 900) {
      crossAxisCount = 2;
    } else if (width < 1300) {
      crossAxisCount = 3;
    }

    final items = paginatedTemplates;

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 80),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No templates found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters.',
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  searchQuery = '';
                  activeIndustry = 'All Industries';
                  activeFormat = 'Thermal Receipt';
                });
              },
              child: Text(
                'Clear Filters',
                style: TextStyle(color: primaryColor),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 24,
        mainAxisSpacing: 32,
        childAspectRatio: 0.72,
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
    final isFavorite = _favoriteTemplates.contains(template.id);

    return InkWell(
      onTap: () => widget.onEdit(template.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentlyActive ? primaryColor : Colors.grey.shade200,
            width: isCurrentlyActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    child: Container(
                      color: const Color(0xFFF9FAFB),
                      child: template.previewImagePath.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: template.previewImagePath,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const SizedBox(),
                              errorWidget: (_, _, _) => _buildPlaceholder(),
                            )
                          : Image.asset(
                              template.previewImagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholder(),
                            ),
                    ),
                  ),

                  // Badges & Favorite
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _badge(template.industry, textDark),
                            const SizedBox(height: 6),
                            _badge(template.styleName, template.badgeColor),
                          ],
                        ),
                        Material(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isFavorite) {
                                  _favoriteTemplates.remove(template.id);
                                } else {
                                  _favoriteTemplates.add(template.id);
                                }
                              });
                            },
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 18,
                                color: isFavorite
                                    ? Colors.redAccent
                                    : textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(11),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          template.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentlyActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.metadata,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPlaceholder({bool large = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: large ? 48 : 32,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Text(
            'Preview Not Available',
            style: TextStyle(
              fontSize: large ? 14 : 12,
              color: textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pageNavButton(
          icon: Icons.arrow_back_ios_new,
          onPressed: currentPage > 1
              ? () => setState(() => currentPage--)
              : null,
        ),
        const SizedBox(width: 16),
        Text(
          'Page $currentPage of $totalPages',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(width: 16),
        _pageNavButton(
          icon: Icons.arrow_forward_ios,
          onPressed: currentPage < totalPages
              ? () => setState(() => currentPage++)
              : null,
        ),
      ],
    );
  }

  Widget _pageNavButton({required IconData icon, VoidCallback? onPressed}) {
    final isEnabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.transparent,
          border: Border.all(
            color: isEnabled ? Colors.grey.shade300 : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isEnabled ? textDark : Colors.grey.shade400,
        ),
      ),
    );
  }

}
