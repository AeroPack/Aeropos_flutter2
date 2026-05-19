import 'package:drift/drift.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/models/customer_transaction.dart';
import 'package:aeropos/core/repositories/customer_transaction_repository.dart';
import 'package:flutter/material.dart';

enum SortField { customerName, amount, date, type }

enum SortOrder { ascending, descending }

class CustomerTransactionViewModel extends ChangeNotifier {
  final CustomerTransactionRepository _repository;
  final AppDatabase _db;

  List<CustomerTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  List<CustomerEntity> _customers = [];

  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedCustomerId;
  TransactionType? _selectedType;

  String _searchQuery = '';
  SortField _sortField = SortField.date;
  SortOrder _sortOrder = SortOrder.descending;
  int _currentPage = 1;
  final int _pageSize = 10;

  CustomerTransactionViewModel(this._repository, this._db);

  List<CustomerTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<CustomerEntity> get customers => _customers;

  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  int? get selectedCustomerId => _selectedCustomerId;
  TransactionType? get selectedType => _selectedType;

  String get searchQuery => _searchQuery;
  SortField get sortField => _sortField;
  SortOrder get sortOrder => _sortOrder;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;

  List<CustomerTransaction> get filteredTransactions {
    var list = _transactions.where((t) {
      if (_selectedCustomerId != null &&
          t.customerId != _selectedCustomerId.toString()) {
        return false;
      }
      if (_selectedType != null && t.type != _selectedType) {
        return false;
      }
      if (_startDate != null &&
          t.createdAt.isBefore(_startDate!.subtract(const Duration(days: 1)))) {
        return false;
      }
      if (_endDate != null &&
          t.createdAt.isAfter(_endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!t.customerName.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) {
      int comparison;
      switch (_sortField) {
        case SortField.customerName:
          comparison = a.customerName.compareTo(b.customerName);
        case SortField.amount:
          comparison = a.amount.compareTo(b.amount);
        case SortField.date:
          comparison = a.createdAt.compareTo(b.createdAt);
        case SortField.type:
          comparison = a.type.name.compareTo(b.type.name);
      }
      return _sortOrder == SortOrder.ascending ? comparison : -comparison;
    });

    return list;
  }

  List<CustomerTransaction> get paginatedTransactions {
    final start = (_currentPage - 1) * _pageSize;
    final end = start + _pageSize;
    if (start >= filteredTransactions.length) {
      return [];
    }
    return filteredTransactions.sublist(
      start,
      end > filteredTransactions.length ? filteredTransactions.length : end,
    );
  }

  int get totalPages => (filteredTransactions.length / _pageSize).ceil();

  bool get hasNextPage => _currentPage < totalPages;
  bool get hasPreviousPage => _currentPage > 1;

  Future<void> loadCustomers() async {
    _customers =
        await (db.select(db.customers)
              ..where((t) => t.isDeleted.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    notifyListeners();
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await _repository.getTransactions();
      _error = null;
      _currentPage = 1;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    _currentPage = 1;
    notifyListeners();
  }

  void setSelectedCustomer(int? customerId) {
    _selectedCustomerId = customerId;
    _currentPage = 1;
    notifyListeners();
  }

  void setSelectedType(TransactionType? type) {
    _selectedType = type;
    _currentPage = 1;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1;
    notifyListeners();
  }

  void setSorting(SortField field) {
    if (_sortField == field) {
      _sortOrder = _sortOrder == SortOrder.ascending
          ? SortOrder.descending
          : SortOrder.ascending;
    } else {
      _sortField = field;
      _sortOrder = SortOrder.descending;
    }
    notifyListeners();
  }

  void goToPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  void nextPage() {
    if (hasNextPage) {
      _currentPage++;
      notifyListeners();
    }
  }

  void previousPage() {
    if (hasPreviousPage) {
      _currentPage--;
      notifyListeners();
    }
  }

  void resetFilters() {
    _startDate = null;
    _endDate = null;
    _selectedCustomerId = null;
    _selectedType = null;
    _searchQuery = '';
    _sortField = SortField.date;
    _sortOrder = SortOrder.descending;
    _currentPage = 1;
    notifyListeners();
  }

  Future<void> addTransaction({
    required String customerId,
    required double amount,
    required TransactionType type,
    String? remarks,
  }) async {
    final transaction = CustomerTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerId: customerId,
      customerName: '',
      amount: amount,
      type: type,
      remarks: remarks,
      createdAt: DateTime.now(),
    );

    await _repository.addTransaction(transaction);
    await loadTransactions();
  }

  AppDatabase get db => _db;
}
