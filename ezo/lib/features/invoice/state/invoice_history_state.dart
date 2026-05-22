import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:aeropos/core/di/service_locator.dart';

class SalesHistoryState {
  final List<TypedResult> items;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String query;
  final int limit;
  final int totalItems;

  const SalesHistoryState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 0,
    this.query = '',
    this.limit = 20,
    this.totalItems = 0,
  });

  SalesHistoryState copyWith({
    List<TypedResult>? items,
    bool? isLoading,
    bool? hasMore,
    int? page,
    String? query,
    int? limit,
    int? totalItems,
  }) {
    return SalesHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      query: query ?? this.query,
      limit: limit ?? this.limit,
      totalItems: totalItems ?? this.totalItems,
    );
  }
}

class SalesHistoryNotifier extends StateNotifier<SalesHistoryState> {
  SalesHistoryNotifier() : super(const SalesHistoryState()) {
    loadInitial();
    _listenToChanges();
  }

  final _db = ServiceLocator.instance.database;
  StreamSubscription? _subscription;
  Timer? _debounceTimer;

  int get _tenantId {
    final tenantId = ServiceLocator.instance.tenantService.tenantId;
    return tenantId;
  }

  void _listenToChanges() {
    _subscription?.cancel();
    // Watch the latest invoice to trigger refresh on new inserts
    // Ordering by descending ID guarantees the result changes on insert, circumventing Drift's stream deduplication.
    final trigger = _db.select(_db.invoices)
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(1);

    _subscription = trigger.watch().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _loadData(fetchCount: true);
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, page: 0, items: [], totalItems: 0);
    await _loadData(fetchCount: true);
  }

  Future<void> setPage(int page) async {
    if (state.isLoading || state.page == page) return;
    state = state.copyWith(isLoading: true, page: page);
    await _loadData(fetchCount: false);
  }

  Future<void> setQuery(String query) async {
    if (state.query == query) return;
    state = state.copyWith(query: query, page: 0, items: [], isLoading: true);
    await _loadData(fetchCount: true);
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }
    await _loadData(fetchCount: true);
  }

  Future<void> _loadData({bool fetchCount = false}) async {
    try {
      final offset = state.page * state.limit;

      // Fetch items
      final newItems = await _db.getInvoiceItemsDetailedPaginated(
        limit: state.limit,
        offset: offset,
        queryStr: state.query.isEmpty ? null : state.query,
        tenantId: _tenantId,
      );

      int totalItems = state.totalItems;
      if (fetchCount) {
        totalItems = await _db.getInvoiceItemsCount(
          queryStr: state.query.isEmpty ? null : state.query,
          tenantId: _tenantId,
        );
      }

      // Calculate hasMore based on total count
      // page is 0-indexed. (page + 1) * limit < totalItems
      final hasMore = (state.page + 1) * state.limit < totalItems;

      state = state.copyWith(
        items: newItems, // Replace items for table view
        isLoading: false,
        hasMore: hasMore,
        totalItems: totalItems,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, hasMore: false);
    }
  }
}

final salesHistoryProvider =
    StateNotifierProvider.autoDispose<SalesHistoryNotifier, SalesHistoryState>((ref) {
      return SalesHistoryNotifier();
    });
