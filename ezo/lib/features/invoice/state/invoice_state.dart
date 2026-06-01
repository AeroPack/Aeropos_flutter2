import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/repositories/sync_repository.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:aeropos/features/invoice/state/invoice_history_state.dart';

class InvoiceItem {
  final ProductEntity product;
  final int quantity;
  final int bonus;
  final double unitPrice;

  const InvoiceItem({
    required this.product,
    this.quantity = 1,
    this.bonus = 0,
    required this.unitPrice,
  });

  double get totalPrice => unitPrice * quantity;

  InvoiceItem copyWith({
    ProductEntity? product,
    int? quantity,
    int? bonus,
    double? unitPrice,
  }) {
    return InvoiceItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      bonus: bonus ?? this.bonus,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

class InvoiceState {
  final String invoiceNumber;
  final CustomerEntity? selectedCustomer;
  final List<InvoiceItem> items;
  final double taxRate; // 0.15 for 15% as per doc
  final String paymentStatus; // 'PENDING', 'COMPLETED', 'REJECTED'

  const InvoiceState({
    this.invoiceNumber = '',
    this.selectedCustomer,
    this.items = const [],
    this.taxRate = 0.15,
    this.paymentStatus = 'COMPLETED',
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  double get taxAmount => subtotal * taxRate;
  double get total => subtotal + taxAmount;

  InvoiceState copyWith({
    String? invoiceNumber,
    CustomerEntity? selectedCustomer,
    List<InvoiceItem>? items,
    double? taxRate,
    String? paymentStatus,
  }) {
    return InvoiceState(
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      items: items ?? this.items,
      taxRate: taxRate ?? this.taxRate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }
}

class InvoiceNotifier extends StateNotifier<InvoiceState> {
  final Ref ref;

  InvoiceNotifier(this.ref) : super(const InvoiceState()) {
    _initInvoiceNumber();
  }

  Future<void> _initInvoiceNumber() async {
    final tenantId = ServiceLocator.instance.tenantService.tenantId;
    final seq = ServiceLocator.instance.invoiceSequenceService;
    final number = await seq.getNextInvoiceNumber(tenantId);
    state = state.copyWith(invoiceNumber: number);
  }

  void setInvoiceNumber(String value) {
    state = state.copyWith(invoiceNumber: value);
  }

  void setCustomer(CustomerEntity? customer) {
    state = state.copyWith(selectedCustomer: customer);
  }

  void addItem(ProductEntity product, int quantity, int bonus) {
    state = state.copyWith(
      items: [
        ...state.items,
        InvoiceItem(
          product: product,
          quantity: quantity,
          bonus: bonus,
          unitPrice: product.price,
        ),
      ],
    );
  }

  void setPaymentStatus(String value) {
    state = state.copyWith(paymentStatus: value);
  }

  void removeItem(int index) {
    final newItems = List<InvoiceItem>.from(state.items);
    newItems.removeAt(index);
    state = state.copyWith(items: newItems);
  }

  void reset() {
    state = const InvoiceState();
    _initInvoiceNumber();
  }

  Future<void> saveInvoice() async {
    final db = ServiceLocator.instance.database;
    final syncRepo = ServiceLocator.instance.syncRepository;
    final seq = ServiceLocator.instance.invoiceSequenceService;
    final tenantId = ServiceLocator.instance.tenantService.tenantId;
    final invoiceUuid = const Uuid().v4();

    // Pre-save duplicate check scoped to tenant
    var finalNumber = state.invoiceNumber;
    final existing = await (db.select(db.invoices)
      ..where((t) => t.invoiceNumber.equals(finalNumber))
      ..where((t) => t.tenantId.equals(tenantId)))
        .getSingleOrNull();
    if (existing != null) {
      finalNumber = await seq.regenerateOnConflict(tenantId, finalNumber);
      state = state.copyWith(invoiceNumber: finalNumber);
    }

    final invoiceCompanion = InvoicesCompanion(
      uuid: Value(invoiceUuid),
      invoiceNumber: Value(finalNumber),
      customerId: Value(state.selectedCustomer?.id),
      date: Value(DateTime.now()),
      subtotal: Value(state.subtotal),
      tax: Value(state.taxAmount),
      total: Value(state.total),
      paymentStatus: Value(state.paymentStatus),
      syncStatus: const Value(1), // Pending
      tenantId: Value(tenantId),
    );

    final itemCompanions = state.items
        .map(
          (item) => InvoiceItemsCompanion(
            uuid: Value(const Uuid().v4()),
            productId: Value(item.product.id),
            quantity: Value(item.quantity),
            bonus: Value(item.bonus),
            unitPrice: Value(item.unitPrice),
            totalPrice: Value(item.totalPrice),
            tenantId: Value(tenantId),
          ),
        )
        .toList();
    await db.createInvoiceWithItems(invoiceCompanion, itemCompanions);

    await syncRepo.logOperation(
      entity: 'invoices',
      entityId: invoiceUuid,
      opType: SyncOpType.insert,
      data: {
        'uuid': invoiceUuid,
        'invoice_number': finalNumber,
        'customer_id': state.selectedCustomer?.id,
        'subtotal': state.subtotal,
        'tax': state.taxAmount,
        'discount': 0.0,
        'total': state.total,
        'payment_method': null,
        'payment_status': state.paymentStatus,
        'notes': null,
        'created_at': DateTime.now().toIso8601String(),
        'is_deleted': false,
      },
    );

    // Refresh history
    try {
      final historyNotifier = ref.read(salesHistoryProvider.notifier);
      historyNotifier.refresh();
    } catch (e) {
      // ignored
    }

    reset();
  }
}

final invoiceProvider = StateNotifierProvider.autoDispose<InvoiceNotifier, InvoiceState>((
  ref,
) {
  return InvoiceNotifier(ref);
});

final productListProvider = StreamProvider.autoDispose<List<ProductEntity>>((ref) {
  final database = ServiceLocator.instance.database;
  return database.watchAllProducts();
});

final customerListProvider = StreamProvider.autoDispose<List<CustomerEntity>>((ref) {
  final database = ServiceLocator.instance.database;
  return database.select(database.customers).watch();
});

final invoiceHistoryProvider = StreamProvider.autoDispose<List<TypedResult>>((ref) {
  final database = ServiceLocator.instance.database;
  final tenantId = ServiceLocator.instance.tenantService.tenantId;
  return database.watchInvoicesWithCustomer(tenantId: tenantId);
});

final detailedInvoiceItemsProvider = StreamProvider.autoDispose<List<TypedResult>>((ref) {
  final database = ServiceLocator.instance.database;
  final tenantId = ServiceLocator.instance.tenantService.tenantId;
  return database.watchInvoiceItemsDetailed(tenantId: tenantId);
});
