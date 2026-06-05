import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/features/invoice/state/invoice_history_state.dart';
import 'package:aeropos/features/invoice/screens/invoice_preview_screen.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/widgets/table_export_actions.dart';
import 'package:aeropos/features/pos/widgets/return_dialog.dart';
import 'package:aeropos/features/pos/widgets/invoice_audit_history_dialog.dart';
class InvoiceHistoryScreen extends ConsumerStatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  ConsumerState<InvoiceHistoryScreen> createState() =>
      _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends ConsumerState<InvoiceHistoryScreen> {
  final _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salesHistoryProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesHistoryProvider);
    final notifier = ref.read(salesHistoryProvider.notifier);

    return Container(
      color: const Color(0xFFF8F9FF),
      // LayoutBuilder ensures responsiveness relative to parent container,
      // crucial if this screen is placed next to a side navigation menu.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          final isMobile = width < 640;
          final isSmallTablet = width >= 640 && width < 900;
          final isTablet = width >= 640 && width < 1200;
          final isDesktop = width >= 1200;

          // Gracefully hide columns on smaller screens
          final showCustomer = width >= 900;
          final showSerialNo = width >= 900;

          return SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : (isTablet ? 24 : 16),
                    vertical: isDesktop ? 32 : (isTablet ? 20 : 16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(isMobile),
                      SizedBox(height: isMobile ? 16 : 24),
                      _buildSearchBar(
                        width, // Pass available width for fluid scaling
                        isDesktop,
                        isTablet,
                        isSmallTablet,
                        isMobile,
                        notifier,
                      ),
                      const SizedBox(height: 20),
                      _buildTableContainer(
                        state,
                        notifier,
                        isDesktop,
                        isSmallTablet,
                        isMobile,
                        showCustomer: showCustomer,
                        showSerialNo: showSerialNo,
                      ),
                      const SizedBox(height: 16),
                      _buildFooter(isDesktop),
                    ],
                  ),
                ),
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

  Widget _buildSearchBar(
    double maxWidth,
    bool isDesktop,
    bool isTablet,
    bool isSmallTablet,
    bool isMobile,
    SalesHistoryNotifier notifier,
  ) {
    if (isMobile) {
      return Column(
        children: [
          _buildSearchField(notifier),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterButton(
                  icon: Icons.filter_list,
                  label: 'Filters',
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _filterButton(
                  icon: Icons.calendar_today,
                  label: _selectedDateRange != null
                      ? '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}'
                      : 'Date',
                  onTap: _showDateRangePicker,
                  isActive: _selectedDateRange != null,
                ),
                const SizedBox(width: 8),
                _buildExportActions(),
              ],
            ),
          ),
        ],
      );
    }

    // Fluid search field width for tablets and desktops
    final searchFieldWidth = isDesktop
        ? 400.0
        : (maxWidth * 0.45).clamp(260.0, 350.0);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(width: searchFieldWidth, child: _buildSearchField(notifier)),
        _filterButton(icon: Icons.filter_list, label: 'Filters', onTap: () {}),
        _filterButton(
          icon: Icons.calendar_today,
          label: _selectedDateRange != null
              ? '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}'
              : 'Date Range',
          onTap: _showDateRangePicker,
          isActive: _selectedDateRange != null,
        ),
        const SizedBox(width: 8),
        _buildExportActions(),
      ],
    );
  }

  Widget _buildSearchField(SalesHistoryNotifier notifier) {
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
                _searchQuery = value.toLowerCase();
                notifier.setQuery(value);
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
                _searchQuery = '';
                notifier.setQuery('');
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

  Widget _buildExportActions() {
    final state = ref.read(salesHistoryProvider);
    final db = ServiceLocator.instance.database;
    final exportHeaders = [
      'S.No',
      'Invoice #',
      'Date',
      'Time',
      'Customer',
      'Amount',
      'Payment Method',
      'Sync',
    ];
    final exportRows = <List<String>>[];

    for (int i = 0; i < state.items.length; i++) {
      try {
        final res = state.items[i];
        final invoice = res.readTable(db.invoices);
        final cust = res.readTableOrNull(db.customers);
        final serialNumber = (state.page * state.limit) + i + 1;
        exportRows.add([
          serialNumber.toString(),
          invoice.invoiceNumber,
          DateFormat('yyyy-MM-dd').format(invoice.date),
          DateFormat('HH:mm:ss').format(invoice.date),
          cust?.name ?? 'Walk-in',
          invoice.total.toStringAsFixed(2),
          invoice.paymentMethod ?? 'N/A',
          invoice.syncStatus == 0 ? 'Synced' : 'Pending',
        ]);
      } catch (_) {
        continue;
      }
    }

    return TableExportActions(
      title: 'Sales History',
      headers: exportHeaders,
      dataRows: exportRows,
    );
  }

  Future<void> _showDateRangePicker() async {
    // Used sizeOf to prevent keyboard-related layout rebuilds
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width <= 600;

    final result = await showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => _DateRangePickerDialog(
        initialRange: _selectedDateRange,
        isMobile: isMobile,
      ),
    );

    if (result != null) {
      setState(() => _selectedDateRange = result);
      ref.read(salesHistoryProvider.notifier).refresh();
    }
  }

  Widget _buildTableContainer(
    SalesHistoryState state,
    SalesHistoryNotifier notifier,
    bool isDesktop,
    bool isSmallTablet,
    bool isMobile, {
    required bool showCustomer,
    required bool showSerialNo,
  }) {
    if (state.isLoading) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.items.isEmpty) {
      return _buildEmptyState();
    }

    if (isMobile) {
      return _buildMobileList(state, notifier);
    }

    return _buildDesktopTable(
      state,
      notifier,
      isSmallTablet: isSmallTablet,
      showCustomer: showCustomer,
      showSerialNo: showSerialNo,
    );
  }

  Widget _buildDesktopTable(
    SalesHistoryState state,
    SalesHistoryNotifier notifier, {
    required bool isSmallTablet,
    required bool showCustomer,
    required bool showSerialNo,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
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
          _buildTableHeader(
            showCustomer: showCustomer,
            showSerialNo: showSerialNo,
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.items.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (context, index) => _buildTableRow(
              state,
              index,
              showCustomer: showCustomer,
              showSerialNo: showSerialNo,
              showViewLabel: !isSmallTablet,
            ),
          ),
          _buildPaginationFooter(state, notifier, isCompact: isSmallTablet),
        ],
      ),
    );
  }

  Widget _buildTableHeader({
    required bool showCustomer,
    required bool showSerialNo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          if (showSerialNo) _headerCell('S.No', flex: 1),
          _headerCell('Invoice #', flex: 2),
          _headerCell('Date & Time', flex: 2),
          if (showCustomer) _headerCell('Customer', flex: 2),
          _headerCell('Amount', flex: 2, align: TextAlign.center),
          _headerCell('Sync', flex: 1, align: TextAlign.center),
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

  Widget _buildTableRow(
    SalesHistoryState state,
    int index, {
    required bool showCustomer,
    required bool showSerialNo,
    required bool showViewLabel,
  }) {
    try {
      final res = state.items[index];
      final invoice = res.readTable(ServiceLocator.instance.database.invoices);
      final item = res.readTableOrNull(ServiceLocator.instance.database.invoiceItems);
      final cust = res.readTableOrNull(
        ServiceLocator.instance.database.customers,
      );
      final serialNumber = (state.page * state.limit) + index + 1;
      final customerName = cust?.name ?? 'Walk-in';
      final dateStr = DateFormat('MMM dd, yyyy').format(invoice.date);
      final timeStr = DateFormat('HH:mm').format(invoice.date);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewInvoice(invoice, cust, item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                if (showSerialNo)
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
                if (showCustomer)
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
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Icon(
                      invoice.syncStatus == 0
                          ? Icons.check_circle
                          : Icons.cloud_upload,
                      color: invoice.syncStatus == 0
                          ? Colors.green
                          : Colors.orange,
                      size: 18,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  // FittedBox prevents overflow by gracefully scaling down the buttons
                  // if the column gets too narrow on intermediate window sizes.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _viewPdfButton(
                          invoice,
                          cust,
                          item,
                          showLabel: showViewLabel,
                        ),
                        const SizedBox(width: 4),
                        _invoiceActions(invoice, item),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _viewPdfButton(
    InvoiceEntity invoice,
    CustomerEntity? customer,
    InvoiceItemEntity? item, {
    bool showLabel = true,
  }) {
    return Material(
      color: const Color(0xFF0058BC).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _viewInvoice(invoice, customer, item),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 10 : 8,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf,
                size: 16,
                color: Color(0xFF0058BC),
              ),
              if (showLabel) ...[
                const SizedBox(width: 4),
                const Text(
                  'VIEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0058BC),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

Widget _invoiceActions(InvoiceEntity invoice, InvoiceItemEntity? invoiceItem) {
  final isDeleted = invoice.isDeleted;

  return PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF545F73)),
    tooltip: 'More actions',
    offset: const Offset(0, 40), // Spawns the menu cleanly right below the button
    elevation: 4,
    // Modern, crisp styling to match your table container
    shadowColor: Colors.black.withValues(alpha: 0.2),
    surfaceTintColor: Colors.white,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
    ),
    onSelected: (value) async {
switch (value) {
    case 'return':
      // 1. Fetch all items for this specific invoice so the dialog can list them all
      final db = ServiceLocator.instance.database;
      
      final results = await db.getInvoiceItemsWithProduct(invoice.id);
      final allItems = results.map((e) => e.readTable(db.invoiceItems)).toList();
      final productNames = Map.fromEntries(
        results.map((e) {
          final item = e.readTable(db.invoiceItems);
          final product = e.readTable(db.products);
          return MapEntry(item.id, product.name);
        }),
      );

      // 2. Ensure the widget is still mounted before showing the dialog
      if (mounted) {
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ReturnDialog(
            invoice: invoice,
            items: allItems,
            productNames: productNames,
          ),
        );

        // 3. If the dialog returns true (meaning a return was successfully processed),
        // refresh the sales history table to show updated totals/status.
        if (result == true) {
          ref.read(salesHistoryProvider.notifier).refresh(silent: true);
        }
      }
      break;
    case 'history':
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => InvoiceAuditHistoryDialog(
            invoiceId: invoice.id,
          ),
        );
      }
      break;
    }
  },
    itemBuilder: (context) => [
      PopupMenuItem<String>(
        value: 'return',
        enabled: !isDeleted,
        height: 38,
        child: Row(
          children: [
            Icon(
              Icons.assignment_return_outlined, 
              size: 16, 
              color: isDeleted ? const Color(0xFFC1C6D7) : const Color(0xFF545F73),
            ),
            const SizedBox(width: 10),
            Text(
              'Return / Exchange',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDeleted ? const Color(0xFFC1C6D7) : const Color(0xFF0B1C30),
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'history',
        height: 38,
        child: Row(
          children: [
            const Icon(Icons.history_toggle_off_rounded, size: 16, color: Color(0xFF545F73)),
            const SizedBox(width: 10),
            const Text(
              'View Audit History',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0B1C30),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildPaginationFooter(
    SalesHistoryState state,
    SalesHistoryNotifier notifier, {
    bool isCompact = false,
  }) {
    final totalPages = (state.totalItems / state.limit).ceil();
    final currentPage = state.page + 1;
    final startItem = (state.page * state.limit) + 1;
    final endItem = (startItem + state.items.length - 1).clamp(
      0,
      state.totalItems,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Text(
            isCompact
                ? '$startItem-$endItem / ${state.totalItems}'
                : 'Showing $startItem - $endItem of ${state.totalItems} entries',
            style: const TextStyle(fontSize: 12, color: Color(0xFF545F73)),
          ),
          const Spacer(),
          _buildPaginationButtons(currentPage, totalPages, notifier),
        ],
      ),
    );
  }

  Widget _buildPaginationButtons(
    int currentPage,
    int totalPages,
    SalesHistoryNotifier notifier,
  ) {
    if (totalPages == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _paginationButton(
          icon: Icons.chevron_left,
          onTap: currentPage > 1
              ? () => notifier.setPage(currentPage - 2)
              : null,
        ),
        const SizedBox(width: 4),
        ...List.generate(totalPages > 5 ? 5 : totalPages, (index) {
          int pageNum;
          if (totalPages <= 5) {
            pageNum = index + 1;
          } else if (currentPage <= 3) {
            pageNum = index + 1;
          } else if (currentPage >= totalPages - 2) {
            pageNum = totalPages - 4 + index;
          } else {
            pageNum = currentPage - 2 + index;
          }
          final isActive = pageNum == currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _paginationButton(
              label: pageNum.toString(),
              isActive: isActive,
              onTap: () => notifier.setPage(pageNum - 1),
            ),
          );
        }),
        const SizedBox(width: 4),
        _paginationButton(
          icon: Icons.chevron_right,
          onTap: currentPage < totalPages
              ? () => notifier.setPage(currentPage)
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

  Widget _buildMobileList(
    SalesHistoryState state,
    SalesHistoryNotifier notifier,
  ) {
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            try {
              final res = state.items[index];
              final invoice = res.readTable(
                ServiceLocator.instance.database.invoices,
              );
              final item = res.readTableOrNull(
                ServiceLocator.instance.database.invoiceItems,
              );
              final cust = res.readTableOrNull(
                ServiceLocator.instance.database.customers,
              );
              final customerName = cust?.name ?? 'Walk-in';

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
                        const Spacer(),
                        Text(
                          'Rs ${invoice.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0058BC),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                    const SizedBox(height: 6),
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
                            customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Color(0xFF0B1C30),
                            ),
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
                        onPressed: () => _viewInvoice(invoice, cust, item),
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
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Page ${state.page + 1} of ${(state.totalItems / state.limit).ceil()}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF545F73)),
              ),
              const SizedBox(height: 12),
              _buildPaginationButtons(
                state.page + 1,
                (state.totalItems / state.limit).ceil(),
                notifier,
              ),
            ],
          ),
        ),
      ],
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
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
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

  Widget _buildFooter(bool isDesktop) {
    if (!isDesktop) return const SizedBox.shrink();
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

  Future<void> _viewInvoice(
    InvoiceEntity invoice,
    CustomerEntity? customer,
    InvoiceItemEntity? item,
  ) async {
    final db = ServiceLocator.instance.database;
    final items = await db.getInvoiceItemsWithProduct(invoice.id);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => InvoicePreviewScreen(
            invoiceEntity: invoice,
            customer: customer,
            items: items,
          ),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Date Range Picker Dialog (Compact, does not cover full screen)
// ─────────────────────────────────────────────────────────────────────────────

class _DateRangePickerDialog extends StatefulWidget {
  final DateTimeRange? initialRange;
  final bool isMobile;

  const _DateRangePickerDialog({this.initialRange, this.isMobile = false});

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _activePreset;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialRange?.start;
    _endDate = widget.initialRange?.end;
  }

  void _applyPreset(String label, DateTime start, DateTime end) {
    setState(() {
      _activePreset = label;
      _startDate = start;
      _endDate = end;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_endDate ?? now),
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0058BC),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _activePreset = null;
        if (isStart) {
          _startDate = picked;
          // Auto-adjust end if start > end
          if (_endDate != null && picked.isAfter(_endDate!)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && picked.isBefore(_startDate!)) {
            _startDate = picked;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = widget.isMobile ? screenWidth * 0.92 : 420.0;

    final presets = [
      ('Today', today, now),
      ('Last 7 Days', today.subtract(const Duration(days: 7)), now),
      ('Last 30 Days', today.subtract(const Duration(days: 30)), now),
      ('This Month', DateTime(now.year, now.month, 1), now),
    ];

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 16 : 80,
        vertical: widget.isMobile ? 40 : 60,
      ),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0058BC).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.date_range_rounded,
                    color: Color(0xFF0058BC),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Select Date Range',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B1C30),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: Color(0xFF717786),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'QUICK SELECT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF717786),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((p) {
                final isActive = _activePreset == p.$1;
                return InkWell(
                  onTap: () => _applyPreset(p.$1, p.$2, p.$3),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF0058BC)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF0058BC)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      p.$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF545F73),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or pick custom dates',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _dateField(
                    'From',
                    _startDate,
                    () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Color(0xFF717786),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateField(
                    'To',
                    _endDate,
                    () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _activePreset = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF545F73),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_startDate != null && _endDate != null)
                        ? () {
                            Navigator.pop(
                              context,
                              DateTimeRange(start: _startDate!, end: _endDate!),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0058BC),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF717786),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Apply Range',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime? date, VoidCallback onTap) {
    final formatted = date != null
        ? DateFormat('MMM dd, yyyy').format(date)
        : 'Select';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? const Color(0xFF0058BC).withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF717786),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: date != null
                      ? const Color(0xFF0058BC)
                      : const Color(0xFF717786),
                ),
                const SizedBox(width: 6),
                Text(
                  formatted,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: date != null
                        ? const Color(0xFF0B1C30)
                        : const Color(0xFFC1C6D7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
