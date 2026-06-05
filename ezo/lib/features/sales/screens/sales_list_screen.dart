import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/widgets/master_header.dart';
import 'package:aeropos/features/sales/state/sales_state.dart';
import 'package:aeropos/features/sales/screens/invoice_preview_screen.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/models/user.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/template_repository.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/models.dart'
    as editor_models;
import 'package:aeropos/core/providers/tenant_provider.dart';
import 'package:aeropos/core/utils/number_to_words.dart';
import 'package:aeropos/core/services/pdf_generator_isolate.dart';

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent) {
      // Load more if needed
    }
  }

  void _resetPage() {
    setState(() {
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final isTablet = width > 600;
    final isMobile = width <= 600;

    final salesAsync = ref.watch(salesListStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: const MasterHeader(showSidebarToggle: true, hidePosButton: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 20 : 16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isMobile),
                  SizedBox(height: isMobile ? 16 : 24),
                  _buildSearchBar(isTablet, isMobile),
                  SizedBox(height: isMobile ? 16 : 20),
                  SizedBox(
                    height: isDesktop ? constraints.maxHeight - 280 : null,
                    child: salesAsync.when(
                      data: (results) => _buildSalesContent(
                        results,
                        isDesktop,
                        isTablet,
                        isMobile,
                      ),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error: $err',
                              style: TextStyle(color: Colors.red.shade400),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(height: 16),
                    _buildFooter(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sales History',
          style: TextStyle(
            fontSize: isMobile ? 24 : 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0B1C30),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Comprehensive log of all transactions and customer interactions.',
          style: TextStyle(
            fontSize: isMobile ? 13 : 16,
            color: const Color(0xFF545F73),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isTablet, bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterButton(
                  icon: Icons.filter_list,
                  label: 'Filters',
                  onTap: () => setState(() => _showFilters = !_showFilters),
                  isActive: _showFilters,
                ),
                const SizedBox(width: 8),
                _filterButton(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  onTap: _showDateRangePicker,
                ),
                const SizedBox(width: 8),
                _exportButton(),
              ],
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(width: isTablet ? 350 : 280, child: _buildSearchField()),
        _filterButton(
          icon: Icons.filter_list,
          label: 'Filters',
          onTap: () => setState(() => _showFilters = !_showFilters),
          isActive: _showFilters,
        ),
        _filterButton(
          icon: Icons.calendar_today,
          label: 'Date Range',
          onTap: _showDateRangePicker,
        ),
        const Spacer(),
        _exportButton(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: Color(0xFF717786), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
                _resetPage();
              },
              decoration: const InputDecoration(
                hintText: 'Search by Invoice or Customer...',
                hintStyle: TextStyle(color: Color(0xFFC1C6D7), fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF717786)),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
                _resetPage();
              },
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _filterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Material(
      color: isActive ? const Color(0xFFDCE9FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF0058BC)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? const Color(0xFF0058BC)
                    : const Color(0xFF545F73),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF0058BC)
                      : const Color(0xFF545F73),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportButton() {
    return Material(
      color: const Color(0xFF0058BC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _exportToCsv,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0058BC).withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Export',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0058BC),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _resetPage();
    }
  }

  void _exportToCsv() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting to CSV...'),
        backgroundColor: Color(0xFF0058BC),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<TypedResult> _filterResults(List<TypedResult> results) {
    return results.where((row) {
      final invoice = row.readTable(ServiceLocator.instance.database.invoices);
      final customer = row.readTableOrNull(
        ServiceLocator.instance.database.customers,
      );

      bool matchesSearch =
          _searchQuery.isEmpty ||
          invoice.invoiceNumber.toLowerCase().contains(_searchQuery) ||
          (customer?.name.toLowerCase().contains(_searchQuery) ?? false);

      bool matchesDateRange = true;
      if (_selectedDateRange != null) {
        matchesDateRange =
            invoice.date.isAfter(
              _selectedDateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            invoice.date.isBefore(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }

      return matchesSearch && matchesDateRange;
    }).toList();
  }

  Widget _buildSalesContent(
    List<TypedResult> allResults,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final filteredResults = _filterResults(allResults);
    final totalEntries = filteredResults.length;
    final totalPages = totalEntries == 0
        ? 1
        : (totalEntries / _pageSize).ceil();
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalEntries);
    final pageResults = totalEntries > 0
        ? filteredResults.sublist(startIndex, endIndex)
        : <TypedResult>[];

    if (filteredResults.isEmpty) {
      return _buildEmptyState();
    }

    if (isMobile) {
      return Column(
        children: [
          _buildMobileList(pageResults),
          const SizedBox(height: 16),
          _buildPaginationMobile(totalEntries, totalPages),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: _buildDesktopTable(pageResults, startIndex, isTablet)),
        _buildPaginationFooter(totalEntries, totalPages),
      ],
    );
  }

  Widget _buildDesktopTable(
    List<TypedResult> pageResults,
    int startIndex,
    bool isTablet,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(isTablet),
          Expanded(
            child: ListView.separated(
              itemCount: pageResults.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) => _buildTableRow(
                pageResults[index],
                startIndex + index + 1,
                isTablet,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isTablet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          _headerCell('S.No', flex: 1),
          _headerCell('Invoice #', flex: 2),
          _headerCell('Date & Time', flex: 2),
          if (isTablet) _headerCell('Customer', flex: 2),
          _headerCell('Amount', flex: 2, align: TextAlign.right),
          _headerCell('Action', flex: 1, align: TextAlign.center),
        ],
      ),
    );
  }

  Widget _headerCell(
    String text, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF545F73),
          letterSpacing: 1,
        ),
        textAlign: align,
      ),
    );
  }

  Widget _buildTableRow(TypedResult row, int serialNumber, bool isTablet) {
    final invoice = row.readTable(ServiceLocator.instance.database.invoices);
    final customer = row.readTableOrNull(
      ServiceLocator.instance.database.customers,
    );
    final customerName = customer?.name ?? 'Walk-in Customer';
    final dateStr = DateFormat('MMM dd, yyyy').format(invoice.date);
    final timeStr = DateFormat('HH:mm').format(invoice.date);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _viewInvoice(invoice),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  serialNumber.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF717786),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0B1C30),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF545F73),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF717786),
                      ),
                    ),
                  ],
                ),
              ),
              if (isTablet)
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8E3FB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            customerName.isNotEmpty
                                ? customerName[0].toUpperCase()
                                : 'W',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFF0058BC),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Color(0xFF0B1C30),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs ${invoice.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0058BC),
                      ),
                    ),
                    if (invoice.paymentMethod != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          invoice.paymentMethod!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF545F73),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(flex: 1, child: Center(child: _viewPdfButton(invoice))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewPdfButton(InvoiceEntity invoice) {
    return Material(
      color: const Color(0xFF0058BC).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _viewInvoice(invoice),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFF0058BC)),
              SizedBox(width: 4),
              Text(
                'VIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0058BC),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(int totalEntries, int totalPages) {
    final startEntry = _currentPage > 1
        ? ((_currentPage - 1) * _pageSize) + 1
        : 1;
    final endEntry = _currentPage * _pageSize;
    final displayedEnd = endEntry.clamp(0, totalEntries);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Text(
            'Showing $startEntry - $displayedEnd of $totalEntries entries',
            style: const TextStyle(fontSize: 13, color: Color(0xFF545F73)),
          ),
          const Spacer(),
          _buildPaginationButtons(totalPages),
        ],
      ),
    );
  }

  Widget _buildPaginationMobile(int totalEntries, int totalPages) {
    final startEntry = _currentPage > 1
        ? ((_currentPage - 1) * _pageSize) + 1
        : 1;
    final endEntry = _currentPage * _pageSize;
    final displayedEnd = endEntry.clamp(0, totalEntries);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Showing $startEntry - $displayedEnd of $totalEntries',
            style: const TextStyle(fontSize: 12, color: Color(0xFF545F73)),
          ),
          const SizedBox(height: 12),
          _buildPaginationButtons(totalPages),
        ],
      ),
    );
  }

  Widget _buildPaginationButtons(int totalPages) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _paginationButton(
          icon: Icons.chevron_left,
          onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
        ),
        const SizedBox(width: 4),
        ...List.generate(totalPages > 5 ? 5 : totalPages, (index) {
          int pageNum;
          if (totalPages <= 5) {
            pageNum = index + 1;
          } else if (_currentPage <= 3) {
            pageNum = index + 1;
          } else if (_currentPage >= totalPages - 2) {
            pageNum = totalPages - 4 + index;
          } else {
            pageNum = _currentPage - 2 + index;
          }

          final isActive = pageNum == _currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _paginationButton(
              label: pageNum.toString(),
              isActive: isActive,
              onTap: () => setState(() => _currentPage = pageNum),
            ),
          );
        }),
        const SizedBox(width: 4),
        _paginationButton(
          icon: Icons.chevron_right,
          onTap: _currentPage < totalPages
              ? () => setState(() => _currentPage++)
              : null,
        ),
      ],
    );
  }

  Widget _paginationButton({
    IconData? icon,
    String? label,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isActive ? const Color(0xFF0058BC) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF0058BC)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 18,
                    color: onTap != null
                        ? const Color(0xFF0B1C30)
                        : const Color(0xFF717786),
                  )
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF0B1C30),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<TypedResult> results) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = results[index];
        final invoice = row.readTable(
          ServiceLocator.instance.database.invoices,
        );
        final customer = row.readTableOrNull(
          ServiceLocator.instance.database.customers,
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8E3FB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF0058BC),
                      ),
                    ),
                  ),
                  if (invoice.paymentMethod != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        invoice.paymentMethod!.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF545F73),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Color(0xFF717786),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      customer?.name ?? 'Walk-in Customer',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Color(0xFF0B1C30),
                      ),
                    ),
                  ),
                  Text(
                    'Rs ${invoice.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0058BC),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: Color(0xFF717786),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM dd, yyyy HH:mm').format(invoice.date),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF545F73),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _viewInvoice(invoice),
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('VIEW PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0058BC),
                    side: const BorderSide(color: Color(0xFF0058BC)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long,
                size: 48,
                color: const Color(0xFF717786).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No sales found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B1C30),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedDateRange != null
                  ? 'Try adjusting your filters'
                  : 'Complete a transaction in POS to see it here.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF545F73)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'AeroPOS v2.4.0',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF545F73),
            letterSpacing: 1,
          ),
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF006B2C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Sync Active',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B1C30),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _viewInvoice(InvoiceEntity invoice) async {
    final companyId = ref.read(companyIdProvider);
    final repo = ref.read(invoiceTemplateRepositoryProvider);

    // Show loading immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Preparing invoice…'),
              ],
            ),
          ),
        ),
      ),
    );

    // Fire all independent DB queries in parallel
    final itemsFuture = ServiceLocator.instance.saleRepository.getSaleItems(invoice.id);
    final customerFuture = invoice.customerId != null
        ? ServiceLocator.instance.customerRepository
            .getCustomerById(invoice.customerId!)
        : Future<User?>.value(null);
    final hydratedFuture = repo.getHydratedInvoiceData(companyId, null);

    final items = await itemsFuture;
    final customer = await customerFuture;
    final (data: invoiceData, templateId: templateId) = await hydratedFuture;

    if (customer != null) {
      invoiceData.clientName = customer.name;
      invoiceData.clientAddress = customer.address ?? '';
      invoiceData.clientPhone = customer.phone ?? '';
      invoiceData.clientEmail = customer.email ?? '';
      invoiceData.clientGstin = customer.gstin ?? '';
      invoiceData.showClientContact = true;
    } else {
      invoiceData.clientName = 'Walk-in Customer';
      invoiceData.clientAddress = '';
      invoiceData.clientPhone = '';
      invoiceData.clientEmail = '';
      invoiceData.clientGstin = '';
      invoiceData.showClientContact = false;
    }

    invoiceData.invoiceNumber = invoice.invoiceNumber;
    invoiceData.invoiceDate = invoice.date;
    invoiceData.paymentMethod = invoice.paymentMethod;
    invoiceData.amountInWords = convertToIndianRupees(invoice.total);

    invoiceData.items = items
        .map(
          (item) => editor_models.InvoiceItem(
            id: item.uuid,
            desc: item.product.name,
            details: '',
            qty: item.quantity.toDouble(),
            rate: item.unitPrice,
          ),
        )
        .toList();

    // Generate PDF while loading dialog is still showing
    if (!mounted) return;
    final pdfBytes = await generatePdfInIsolate(invoiceData, templateId);

    // Pop loading dialog
    if (mounted) Navigator.pop(context);

    // Show preview with pre-generated bytes (no second spinner)
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => InvoicePreviewScreen(
        invoiceNumber: invoice.invoiceNumber,
        preGeneratedPdfBytes: pdfBytes,
        onLayout: (format) async => pdfBytes,
        onPrintComplete: () {
          Navigator.pop(context);
        },
      ),
    );
  }
}
