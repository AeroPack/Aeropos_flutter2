import 'dart:async';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/widgets/date_range_picker.dart' as custom_date_picker;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aeropos/features/stock_mgmt/widgets/bulk_import_dialog.dart';

class InventoryDashboard extends StatefulWidget {
  const InventoryDashboard({super.key});

  @override
  State<InventoryDashboard> createState() => _InventoryDashboardState();
}

class _InventoryDashboardState extends State<InventoryDashboard> {
  final Color primaryBlue = const Color(0xFF0D6EFD);
  final Color bgColor = const Color(0xFFF8F9FB);
  final Color borderColor = const Color(0xFFE0E4E9);
  final TextEditingController _searchController = TextEditingController();

  final _categoryViewModel = ServiceLocator.instance.categoryViewModel;
  final _unitViewModel = ServiceLocator.instance.unitViewModel;
  final _database = ServiceLocator.instance.database;

  List<ProductEntity> _allProducts = [];
  Map<int, String> _categoryNames = {};
  Map<int, String> _unitNames = {};

  String? _selectedCategory;
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  int _currentPage = 1;
  final int _pageSize = 10;

  StreamSubscription? _categoriesSub;
  StreamSubscription? _unitsSub;

  @override
  void initState() {
    super.initState();
    // Use one-time .get() instead of permanent .listen() for products
    _loadProducts();
    // Categories and units are small reference tables; keep watch but cancel on dispose
    _categoriesSub = _categoryViewModel.allCategories.listen((categories) {
      if (mounted) {
        setState(() {
          _categoryNames = {for (var c in categories) c.id: c.name};
        });
      }
    });
    _unitsSub = _unitViewModel.allUnits.listen((units) {
      if (mounted) {
        setState(() {
          _unitNames = {for (var u in units) u.id: u.name};
        });
      }
    });
  }

  Future<void> _loadProducts() async {
    final products = await _database.getAllProducts();
    if (mounted) {
      setState(() => _allProducts = products);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoriesSub?.cancel();
    _unitsSub?.cancel();
    super.dispose();
  }

  String _getStockStatus(int stock) {
    if (stock == 0) return 'Out of Stock';
    if (stock <= 10) return 'Low Stock';
    return 'In Stock';
  }

  List<ProductEntity> get filteredProducts {
    return _allProducts.where((p) {
      // Search filter
      if (_searchController.text.isNotEmpty) {
        if (!p.name.toLowerCase().contains(
          _searchController.text.toLowerCase(),
        )) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != null && _selectedCategory != 'All Categories') {
        final productCategoryName = _categoryNames[p.categoryId] ?? '';
        if (productCategoryName != _selectedCategory) {
          return false;
        }
      }

      // Status filter
      if (_selectedStatus != null && _selectedStatus != 'All Statuses') {
        final status = _getStockStatus(p.stockQuantity);
        if (status != _selectedStatus) {
          return false;
        }
      }

      // Date range filter
      if (_startDate != null && _endDate != null) {
        if (p.updatedAt.isBefore(_startDate!) ||
            p.updatedAt.isAfter(_endDate!)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<ProductEntity> get paginatedProducts {
    final start = (_currentPage - 1) * _pageSize;
    final end = start + _pageSize;
    if (start >= filteredProducts.length) return [];
    return filteredProducts.sublist(
      start,
      end > filteredProducts.length ? filteredProducts.length : end,
    );
  }

  int get totalPages => (filteredProducts.length / _pageSize).ceil();

  bool get hasNextPage => _currentPage < totalPages;
  bool get hasPreviousPage => _currentPage > 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
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
              'Inventory Dashboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage Your Stock & Inventory',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        Row(
          children: [
            _buildActionIcon(Icons.upload_file, Colors.blue[600]!, () {
              showBulkImportDialog(context);
            }),
            const SizedBox(width: 8),
            _buildActionIcon(Icons.picture_as_pdf, Colors.red[400]!, () {}),
            const SizedBox(width: 8),
            _buildActionIcon(Icons.grid_on, Colors.green[500]!, () {}),
            const SizedBox(width: 8),
            _buildActionIcon(Icons.refresh, Colors.grey[600]!, () {}),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add New Stock'),
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
                  'Category',
                  _buildCategoryDropdown(),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: _filterLabelWrapper(
                  'Stock Status',
                  _buildStatusDropdown(),
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
                onPressed: () {
                  setState(() {
                    _selectedCategory = null;
                    _selectedStatus = null;
                    _startDate = null;
                    _endDate = null;
                    _currentPage = 1;
                  });
                },
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
              _startDate != null
                  ? DateFormat('dd/MM/yyyy').format(_startDate!)
                  : 'Start date',
              style: TextStyle(
                color: _startDate != null ? Colors.black : Colors.grey[400],
                fontSize: 13,
              ),
            ),
            const Icon(Icons.arrow_right_alt, size: 14, color: Colors.grey),
            Text(
              _endDate != null
                  ? DateFormat('dd/MM/yyyy').format(_endDate!)
                  : 'End date',
              style: TextStyle(
                color: _endDate != null ? Colors.black : Colors.grey[400],
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
        initialRange: _startDate != null && _endDate != null
            ? DateTimeRange(start: _startDate!, end: _endDate!)
            : null,
        isMobile: isMobile,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
    }
  }

  Widget _buildCategoryDropdown() {
    return StreamBuilder<List<CategoryEntity>>(
      stream: _categoryViewModel.allCategories,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];
        final dropdownItems = [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All Categories'),
          ),
          ...categories.map(
            (c) =>
                DropdownMenuItem<String?>(value: c.name, child: Text(c.name)),
          ),
        ];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedCategory,
              isExpanded: true,
              hint: const Text(
                'All Categories',
                style: TextStyle(color: Colors.grey),
              ),
              items: dropdownItems,
              onChanged: (value) => setState(() {
                _selectedCategory = value;
                _currentPage = 1;
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedStatus,
          isExpanded: true,
          hint: const Text(
            'All Statuses',
            style: TextStyle(color: Colors.grey),
          ),
          items: const [
            DropdownMenuItem<String?>(value: null, child: Text('All Statuses')),
            DropdownMenuItem<String?>(
              value: 'In Stock',
              child: Text('In Stock'),
            ),
            DropdownMenuItem<String?>(
              value: 'Low Stock',
              child: Text('Low Stock'),
            ),
            DropdownMenuItem<String?>(
              value: 'Out of Stock',
              child: Text('Out of Stock'),
            ),
          ],
          onChanged: (value) => setState(() {
            _selectedStatus = value;
            _currentPage = 1;
          }),
        ),
      ),
    );
  }

  Widget _buildTableContainer() {
    final products = paginatedProducts;
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildMetricChip(
                      'Total Products',
                      filteredProducts.length,
                      Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricChip(
                      'Low Stock',
                      filteredProducts
                          .where(
                            (p) => p.stockQuantity > 0 && p.stockQuantity <= 10,
                          )
                          .length,
                      Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricChip(
                      'Out of Stock',
                      filteredProducts
                          .where((p) => p.stockQuantity == 0)
                          .length,
                      Colors.red,
                    ),
                  ],
                ),
                SizedBox(
                  width: 200,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryBlue),
                      ),
                    ),
                    onChanged: (_) => setState(() => _currentPage = 1),
                  ),
                ),
              ],
            ),
          ),
          _buildTableHeader(),
          if (products.isEmpty)
            _buildEmptyState()
          else
            ...products.map((p) => _buildTableRow(p)),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: color)),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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
      child: const Row(
        children: [
          SizedBox(width: 30),
          Expanded(
            flex: 4,
            child: Text(
              'Product Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF555555),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Category',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF555555),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Stock',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF555555),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Unit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF555555),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF555555),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(ProductEntity product) {
    final stock = product.stockQuantity;
    final status = _getStockStatus(stock);

    Color stockColor = Colors.green[600]!;
    Color statusBg = Colors.green[50]!;
    Color statusColor = Colors.green[600]!;

    if (stock == 0) {
      stockColor = Colors.red[600]!;
      statusBg = Colors.red[50]!;
      statusColor = Colors.red[600]!;
    } else if (stock <= 10) {
      stockColor = Colors.orange[600]!;
      statusBg = Colors.orange[50]!;
      statusColor = Colors.orange[600]!;
    }

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
            flex: 4,
            child: Text(
              product.name,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _categoryNames[product.categoryId] ?? 'Uncategorized',
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              stock.toString(),
              style: TextStyle(fontWeight: FontWeight.bold, color: stockColor),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _unitNames[product.unitId] ?? 'N/A',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
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
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No products found',
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
            'Showing ${paginatedProducts.length} of ${filteredProducts.length} entries',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          Row(
            children: [
              Text(
                'Page $_currentPage of $totalPages',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: hasPreviousPage ? Colors.grey[700] : Colors.grey[300],
                onPressed: hasPreviousPage
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: hasNextPage ? Colors.grey[700] : Colors.grey[300],
                onPressed: hasNextPage
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
