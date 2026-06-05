import 'package:drift/drift.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/models/supplier_transaction.dart';
import 'package:aeropos/core/repositories/supplier_transaction_repository.dart';
import 'package:flutter/material.dart';

enum SortField { supplierName, amount, date, type }

enum SortOrder { ascending, descending }

class SupplierTransactionViewModel extends ChangeNotifier {
  final SupplierTransactionRepository _repository;
  final AppDatabase _db;

  List<SupplierTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  List<SupplierEntity> _suppliers = [];

  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedSupplierId;
  TransactionType? _selectedType;

  String _searchQuery = '';
  SortField _sortField = SortField.date;
  SortOrder _sortOrder = SortOrder.descending;
  int _currentPage = 1;
  final int _pageSize = 10;

  SupplierTransactionViewModel(this._repository, this._db);

  List<SupplierTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SupplierEntity> get suppliers => _suppliers;

  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  int? get selectedSupplierId => _selectedSupplierId;
  TransactionType? get selectedType => _selectedType;

  String get searchQuery => _searchQuery;
  SortField get sortField => _sortField;
  SortOrder get sortOrder => _sortOrder;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;

  List<SupplierTransaction> get filteredTransactions {
    var list = _transactions.where((t) {
      if (_selectedSupplierId != null &&
          t.supplierId != _selectedSupplierId.toString()) {
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
        final nameMatch = t.supplierName.toLowerCase().contains(query);
        final phoneMatch =
            t.supplierPhone?.toLowerCase().contains(query) ?? false;
        if (!nameMatch && !phoneMatch) return false;
      }
      return true;
    }).toList();

    // Compute running balance grouped by supplier, sorted by date ascending
    list.sort((a, b) {
      final cmp = a.supplierId.compareTo(b.supplierId);
      return cmp != 0 ? cmp : a.createdAt.compareTo(b.createdAt);
    });

    final withBalance = <SupplierTransaction>[];
    double running = 0;
    String? lastSupplierId;

    for (final t in list) {
      if (lastSupplierId != null && t.supplierId != lastSupplierId) {
        running = 0;
      }
      running += t.type == TransactionType.credit ? t.amount : -t.amount;
      lastSupplierId = t.supplierId;
      withBalance.add(SupplierTransaction(
        id: t.id,
        supplierId: t.supplierId,
        supplierName: t.supplierName,
        supplierPhone: t.supplierPhone,
        amount: t.amount,
        type: t.type,
        remarks: t.remarks,
        createdAt: t.createdAt,
        syncStatus: t.syncStatus,
        runningBalance: running,
      ));
    }

    withBalance.sort((a, b) {
      int comparison;
      switch (_sortField) {
        case SortField.supplierName:
          comparison = a.supplierName.compareTo(b.supplierName);
        case SortField.amount:
          comparison = a.amount.compareTo(b.amount);
        case SortField.date:
          comparison = a.createdAt.compareTo(b.createdAt);
        case SortField.type:
          comparison = a.type.name.compareTo(b.type.name);
      }
      return _sortOrder == SortOrder.ascending ? comparison : -comparison;
    });

    return withBalance;
  }

  List<SupplierTransaction> get paginatedTransactions {
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

  Future<void> loadSuppliers() async {
    _suppliers =
        await (db.select(db.suppliers)
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

  void setSelectedSupplier(int? supplierId) {
    _selectedSupplierId = supplierId;
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
    _selectedSupplierId = null;
    _selectedType = null;
    _searchQuery = '';
    _sortField = SortField.date;
    _sortOrder = SortOrder.descending;
    _currentPage = 1;
    notifyListeners();
  }

  Future<void> addTransaction({
    required String supplierId,
    required double amount,
    required TransactionType type,
    String? remarks,
  }) async {
    final transaction = SupplierTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      supplierId: supplierId,
      supplierName: '',
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
