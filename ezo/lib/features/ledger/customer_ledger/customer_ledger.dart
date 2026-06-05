import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/viewModel/customer_transaction_view_model.dart';
import 'package:aeropos/core/models/customer_transaction.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/widgets/date_range_picker.dart' as custom_date_picker;

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  final Color primaryBlue = const Color(0xFF0D6EFD);
  final Color bgColor = const Color(0xFFF8F9FB);
  final Color borderColor = const Color(0xFFE0E4E9);

  late CustomerTransactionViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.instance.customerTransactionViewModel;
    _viewModel.loadCustomers();
    _viewModel.loadTransactions();
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    final transactions = _viewModel.filteredTransactions;
    final dateFormat = DateFormat('dd/MM/yyyy, HH:mm:ss');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Customer Ledger Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Generated: ${dateFormat.format(DateTime.now())}'),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Customer Name',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Amount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Type',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Date',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Remarks',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                ...transactions.map(
                  (t) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(t.customerName),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs${NumberFormat('#,###.00').format(t.amount)}',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(t.type.displayName),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(dateFormat.format(t.createdAt)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(t.remarks ?? '-'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final pdfBytes = await pdf.save();
    final fileName =
        'customer_ledger_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (kIsWeb) {
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } else {
      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF exported: ${file.path}')));
      }
    }
  }

  Future<void> _exportToExcel() async {
    final workbook = excel.Excel.createExcel();
    final sheet = workbook['Customer Ledger'];

    final headers = ['Customer Name', 'Amount', 'Type', 'Date', 'Remarks'];
    sheet.appendRow(headers.map((h) => excel.TextCellValue(h)).toList());

    final transactions = _viewModel.filteredTransactions;
    final dateFormat = DateFormat('dd/MM/yyyy, HH:mm:ss');

    for (final t in transactions) {
      sheet.appendRow([
        excel.TextCellValue(t.customerName),
        excel.TextCellValue('Rs${NumberFormat('#,###.00').format(t.amount)}'),
        excel.TextCellValue(t.type.displayName),
        excel.TextCellValue(dateFormat.format(t.createdAt)),
        excel.TextCellValue(t.remarks ?? '-'),
      ]);
    }

    final excelBytes = workbook.encode()!;
    final fileName =
        'customer_ledger_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    if (kIsWeb) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(excelBytes);
      await Share.shareXFiles([
        XFile(tempFile.path),
      ], text: 'Customer Ledger Export');
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(excelBytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Excel exported: ${file.path}')));
      }
    } else {
      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(excelBytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Excel exported: ${file.path}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopHeader(),
                  const SizedBox(height: 20),
                  _buildFilterCard(),
                  const SizedBox(height: 24),
                  _buildTableContainer(),
                ],
              ),
            ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Ledger',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage Your Customer\'s Ledger',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        Row(
          children: [
            _buildActionIcon(
              Icons.picture_as_pdf,
              Colors.red[400]!,
              _exportToPdf,
            ),
            const SizedBox(width: 8),
            _buildActionIcon(Icons.grid_on, Colors.green[500]!, _exportToExcel),
            const SizedBox(width: 8),
            _buildActionIcon(
              Icons.refresh,
              Colors.grey[600]!,
              () => _viewModel.loadTransactions(),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/customer-ledger/add'),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add New Transaction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _filterLabelWrapper('Date Range', _buildDatePickerBox()),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: _filterLabelWrapper(
                  'Customer',
                  _buildCustomerDropdown(),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: _filterLabelWrapper(
                  'Transaction Type',
                  _buildTypeDropdown(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: _viewModel.resetFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Reset Filters'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterLabelWrapper(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Color(0xFF444444),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDatePickerBox() {
    return InkWell(
      onTap: () => _showDateRangePicker(),
      child: Container(
        width: double.infinity,
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _viewModel.startDate != null
                  ? DateFormat('dd/MM/yyyy').format(_viewModel.startDate!)
                  : 'Start date',
              style: TextStyle(
                color: _viewModel.startDate != null
                    ? Colors.black
                    : Colors.grey[400],
                fontSize: 13,
              ),
            ),
            const Icon(Icons.arrow_right_alt, size: 14, color: Colors.grey),
            Text(
              _viewModel.endDate != null
                  ? DateFormat('dd/MM/yyyy').format(_viewModel.endDate!)
                  : 'End date',
              style: TextStyle(
                color: _viewModel.endDate != null
                    ? Colors.black
                    : Colors.grey[400],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width <= 600;

    final result = await showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => custom_date_picker.DateRangePickerDialog(
        initialRange: _viewModel.startDate != null && _viewModel.endDate != null
            ? DateTimeRange(
                start: _viewModel.startDate!,
                end: _viewModel.endDate!,
              )
            : null,
        isMobile: isMobile,
      ),
    );

    if (result != null) {
      _viewModel.setDateRange(result.start, result.end);
    }
  }

  Widget _buildCustomerDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _viewModel.selectedCustomerId,
          isExpanded: true,
          hint: Text(
            'All Customers',
            style: TextStyle(color: Colors.grey[600]),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All Customers'),
            ),
            ..._viewModel.customers.map(
              (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
            ),
          ],
          onChanged: (value) => _viewModel.setSelectedCustomer(value),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TransactionType?>(
          value: _viewModel.selectedType,
          isExpanded: true,
          hint: Text('All Types', style: TextStyle(color: Colors.grey[600])),
          items: const [
            DropdownMenuItem<TransactionType?>(
              value: null,
              child: Text('All Types'),
            ),
            DropdownMenuItem<TransactionType?>(
              value: TransactionType.credit,
              child: Text('CREDIT'),
            ),
            DropdownMenuItem<TransactionType?>(
              value: TransactionType.debit,
              child: Text('DEBIT'),
            ),
          ],
          onChanged: (value) => _viewModel.setSelectedType(value),
        ),
      ),
    );
  }

  Widget _buildTableContainer() {
    final transactions = _viewModel.paginatedTransactions;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 200,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryBlue),
                    ),
                  ),
                  onChanged: (value) => _viewModel.setSearchQuery(value),
                ),
              ),
            ),
          ),
          _buildTableHeader(),
          if (transactions.isEmpty)
            _buildEmptyState()
          else
            ...transactions.map((t) => _buildTableRow(t)),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 30),
          Expanded(
            flex: 3,
            child: _HeaderCell(
              'Customer Name',
              sortField: SortField.customerName,
              currentSort: _viewModel.sortField,
              sortOrder: _viewModel.sortOrder,
              onTap: () => _viewModel.setSorting(SortField.customerName),
            ),
          ),
          Expanded(
            flex: 2,
            child: _HeaderCell(
              'Amount',
              sortField: SortField.amount,
              currentSort: _viewModel.sortField,
              sortOrder: _viewModel.sortOrder,
              onTap: () => _viewModel.setSorting(SortField.amount),
              hasSort: true,
            ),
          ),
          Expanded(
            flex: 1,
            child: _HeaderCell(
              'Type',
              sortField: SortField.type,
              currentSort: _viewModel.sortField,
              sortOrder: _viewModel.sortOrder,
              onTap: () => _viewModel.setSorting(SortField.type),
            ),
          ),
          Expanded(
            flex: 3,
            child: _HeaderCell(
              'Date',
              sortField: SortField.date,
              currentSort: _viewModel.sortField,
              sortOrder: _viewModel.sortOrder,
              onTap: () => _viewModel.setSorting(SortField.date),
              hasSort: true,
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Remarks',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(CustomerTransaction t) {
    final isDebit = t.type == TransactionType.debit;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: bgColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.add, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              t.customerName,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Rs${NumberFormat('#,###.00').format(t.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDebit ? Colors.red[600] : Colors.green[600],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDebit ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                t.type.displayName,
                style: TextStyle(
                  color: isDebit ? Colors.red[600] : Colors.green[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              DateFormat('dd/MM/yyyy, HH:mm:ss').format(t.createdAt),
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              t.remarks ?? '-',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${_viewModel.paginatedTransactions.length} of ${_viewModel.filteredTransactions.length} entries',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          Row(
            children: [
              Text(
                'Page ${_viewModel.currentPage} of ${_viewModel.totalPages}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: _viewModel.hasPreviousPage
                    ? Colors.grey[700]
                    : Colors.grey[300],
                onPressed: _viewModel.hasPreviousPage
                    ? _viewModel.previousPage
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: _viewModel.hasNextPage
                    ? Colors.grey[700]
                    : Colors.grey[300],
                onPressed: _viewModel.hasNextPage ? _viewModel.nextPage : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String title;
  final SortField? sortField;
  final SortField currentSort;
  final SortOrder sortOrder;
  final VoidCallback onTap;
  final bool hasSort;

  const _HeaderCell(
    this.title, {
    this.sortField,
    required this.currentSort,
    required this.sortOrder,
    required this.onTap,
    this.hasSort = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = sortField == currentSort;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isActive
                  ? const Color(0xFF0D6EFD)
                  : const Color(0xFF555555),
            ),
          ),
          if (hasSort)
            Icon(
              isActive
                  ? (sortOrder == SortOrder.ascending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isActive ? const Color(0xFF0D6EFD) : Colors.grey[400],
            ),
        ],
      ),
    );
  }
}

class CustomerLedgerDetailScreen extends StatelessWidget {
  final CustomerEntity customer;

  const CustomerLedgerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${customer.name} - Ledger')),
      body: Center(child: Text('Customer Ledger Detail - Coming Soon')),
    );
  }
}
