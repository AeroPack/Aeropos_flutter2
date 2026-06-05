import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../di/service_locator.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/unit_repository.dart';
import '../repositories/brand_repository.dart';
import '../../config/app_config.dart';

final _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

class SyncValidationError implements Exception {
  final String message;
  SyncValidationError(this.message);

  @override
  String toString() => 'SyncValidationError: $message';
}

class PendingChangesDetail {
  final int categories;
  final int units;
  final int brands;
  final int products;
  final int customers;
  final int suppliers;
  final int employees;
  final int invoices;

  PendingChangesDetail({
    required this.categories,
    required this.units,
    required this.brands,
    required this.products,
    required this.customers,
    required this.suppliers,
    required this.employees,
    required this.invoices,
  });

  int get total =>
      categories +
      units +
      brands +
      products +
      customers +
      suppliers +
      employees +
      invoices;

  bool get hasPending => total > 0;
}

bool isValidUUID(String? value) {
  if (value == null || value.isEmpty) return false;
  return _uuidRegex.hasMatch(value);
}

Future<void> validateProductForSync(AppDatabase db, ProductEntity prod) async {
  if (prod.unitId != null) {
    final unit = await (db.select(
      db.units,
    )..where((t) => t.id.equals(prod.unitId!))).getSingleOrNull();
    if (unit == null) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid unit reference (unit not found)',
      );
    }
    if (!isValidUUID(unit.uuid)) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid unit UUID for unit ID ${prod.unitId}',
      );
    }
  }
  if (prod.categoryId != null) {
    final cat = await (db.select(
      db.categories,
    )..where((t) => t.id.equals(prod.categoryId!))).getSingleOrNull();
    if (cat == null) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid category reference (category not found)',
      );
    }
    if (!isValidUUID(cat.uuid)) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid category UUID for category ID ${prod.categoryId}',
      );
    }
  }
  if (prod.brandId != null) {
    final brand = await (db.select(
      db.brands,
    )..where((t) => t.id.equals(prod.brandId!))).getSingleOrNull();
    if (brand == null) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid brand reference (brand not found)',
      );
    }
    if (!isValidUUID(brand.uuid)) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid brand UUID for brand ID ${prod.brandId}',
      );
    }
  }
}

class SyncResult {
  final bool success;
  final Map<String, int> syncedCounts;
  final Map<String, int> failedCounts;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.syncedCounts,
    required this.failedCounts,
    required this.errors,
  });

  bool get hasFailures => failedCounts.values.any((count) => count > 0);
  int get totalSynced =>
      syncedCounts.values.fold(0, (sum, count) => sum + count);
  int get totalFailed =>
      failedCounts.values.fold(0, (sum, count) => sum + count);
}

// ----------------------------------------------------------------------
// Internal helpers for push operations
// ----------------------------------------------------------------------

class _RecordRef {
  final String table;
  final String uuid;
  final int localId;
  _RecordRef(this.table, this.uuid, this.localId);
}

class _PendingOp {
  final String table;
  final String uuid;
  final int localId;
  final Map<String, dynamic> data;
  _PendingOp(this.table, this.uuid, this.localId, this.data);
}

// ----------------------------------------------------------------------

@Deprecated(
  'Use SyncEngine from sync_engine.dart instead. Will be removed after v2.0. Migration required.',
)
class SyncService {
  final AppDatabase db;
  final Dio dio;
  final ProductRepository productRepo;
  final CustomerRepository customerRepo;
  final SupplierRepository supplierRepo;
  final EmployeeRepository employeeRepo;
  final SaleRepository saleRepo;
  final CategoryRepository categoryRepo;
  final UnitRepository unitRepo;
  final BrandRepository brandRepo;

  int get _companyId => ServiceLocator.instance.sessionService.companyId;

  Timer? _syncTimer;
  Timer? _syncDebounceTimer;
  bool _isSyncing = false;
  bool _isPulling = false;

  SyncService({
    required this.db,
    required this.dio,
    required this.productRepo,
    required this.customerRepo,
    required this.supplierRepo,
    required this.employeeRepo,
    required this.saleRepo,
    required this.categoryRepo,
    required this.unitRepo,
    required this.brandRepo,
  }) {
    dio.options.baseUrl = AppConfig.apiBaseUrl;
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);
    debugPrint(
      '[DEPRECATED] SyncService is deprecated. Use SyncEngine instead. Migration required.',
    );
    _initializeDeviceId();
    _isSyncing = false;
    _isPulling = false;
  }

  Future<void> _initializeDeviceId() async {
    final storage = ServiceLocator.instance.secureStorage;
    String? deviceId = await storage.read(key: 'device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await storage.write(key: 'device_id', value: deviceId);
      debugPrint('[SYNC] Generated new device ID: $deviceId');
    }
  }

  void startAutoSync({Duration interval = const Duration(minutes: 5)}) {
    debugPrint('[DIAG][AUTO_SYNC_INIT] Starting with interval: $interval');
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      debugPrint('[DIAG][AUTO_SYNC_TIMER] Timer fired - calling sync()');
      sync();
    });
    Future.delayed(const Duration(seconds: 5), () {
      debugPrint('[DIAG][AUTO_SYNC_INITIAL] Initial sync after 5s delay');
      sync();
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncDebounceTimer?.cancel();
  }

  /// Debounced sync — coalesces rapid-fire calls into one execution
  Future<void> sync() async {
    // ===== DIAG LOG: Sync entry point =====
    debugPrint('[DIAG][SYNC_ENTRY] sync() called, _isSyncing=$_isSyncing');
    
    if (_isSyncing) {
      debugPrint('[DIAG][SYNC_ENTRY] Early exit - already syncing');
      return;
    }

    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(seconds: 2), () {
      debugPrint('[DIAG][SYNC_ENTRY] Debounce timer fired - calling _doSync()');
      _doSync();
    });
  }

  Future<void> _doSync() async {
    if (_isSyncing) {
      debugPrint('[DIAG][SYNC_SKIP] Already syncing - returning early');
      return;
    }
    _isSyncing = true;

    try {
      final storage = ServiceLocator.instance.secureStorage;
      final token = await storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        debugPrint('[DIAG][SYNC_SKIP] No auth token');
        return;
      }

      final companyId = ServiceLocator.instance.sessionService.companyIdOrNull;
      if (companyId == null || companyId <= 0) {
        debugPrint('[DIAG][SYNC_SKIP] Invalid companyId=$companyId');
        return;
      }

      debugPrint('[DIAG][SYNC_START] push() called');
      await push(); // Push local changes first
      debugPrint('[DIAG][PUSH_DONE] Push completed');

      debugPrint('[DIAG][SYNC_START] pull() called');
      await pull(); // Then fetch remote updates
      debugPrint('[DIAG][PULL_DONE] Pull completed');
    } on Object catch (e) {
      // ===== DIAG LOG: Was silently swallowed before! =====
      debugPrint('[DIAG][SYNC_ERROR] Exception caught: $e');
    } finally {
      _isSyncing = false;
      debugPrint('[DIAG][SYNC_FINISHED] _isSyncing set to false');
    }
  }

  /// Check if there are any pending changes that need to be synced
  Future<bool> hasPendingChanges() async {
    try {
      final pendingCategories =
          await (db.select(db.categories)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingCategories.isNotEmpty) return true;

      final pendingUnits =
          await (db.select(db.units)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingUnits.isNotEmpty) return true;

      final pendingBrands =
          await (db.select(db.brands)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingBrands.isNotEmpty) return true;

      final pendingProducts =
          await (db.select(db.products)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingProducts.isNotEmpty) return true;

      final pendingCustomers =
          await (db.select(db.customers)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingCustomers.isNotEmpty) return true;

      final pendingSuppliers =
          await (db.select(db.suppliers)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingSuppliers.isNotEmpty) return true;

      final pendingEmployees =
          await (db.select(db.employees)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingEmployees.isNotEmpty) return true;

      final pendingInvoices =
          await (db.select(db.invoices)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingInvoices.isNotEmpty) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get detailed count of pending changes by entity type
  Future<PendingChangesDetail> getPendingChangesDetails() async {
    try {
      final pendingCategories = await (db.select(
        db.categories,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingUnits = await (db.select(
        db.units,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingBrands = await (db.select(
        db.brands,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingProducts = await (db.select(
        db.products,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingCustomers = await (db.select(
        db.customers,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingSuppliers = await (db.select(
        db.suppliers,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingEmployees = await (db.select(
        db.employees,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingInvoices = await (db.select(
        db.invoices,
      )..where((t) => t.syncStatus.equals(1))).get();

      return PendingChangesDetail(
        categories: pendingCategories.length,
        units: pendingUnits.length,
        brands: pendingBrands.length,
        products: pendingProducts.length,
        customers: pendingCustomers.length,
        suppliers: pendingSuppliers.length,
        employees: pendingEmployees.length,
        invoices: pendingInvoices.length,
      );
    } catch (e) {
      return PendingChangesDetail(
        categories: 0,
        units: 0,
        brands: 0,
        products: 0,
        customers: 0,
        suppliers: 0,
        employees: 0,
        invoices: 0,
      );
    }
  }

  /// Clean all local data and perform a full sync from the API
  Future<bool> cleanAndSync() async {
    if (_isSyncing) {
      return false;
    }

    _isSyncing = true;

    try {
      await db.clearAllData();
      await pull();
      return true;
    } catch (e) {
      if (e is DioException) {}
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // ----------------------------------------------------------------------
  // PULL (unchanged from original)
  // ----------------------------------------------------------------------
  Future<void> pull() async {
    if (_isPulling) {
      debugPrint('[SYNC] pull() already in progress, skipping');
      return;
    }

    _isPulling = true;
    debugPrint('[SYNC] pull() STARTING with companyId=$_companyId');

    try {
      await _doPull();
    } catch (e) {
      debugPrint('[SYNC] pull() ERROR: $e');
      rethrow;
    } finally {
      _isPulling = false;
      debugPrint('[SYNC] pull() finished, flag reset');
    }
  }

  Future<void> _doPull() async {
    debugPrint('[DIAG] 1: enter _doPull');

    final currentTenantId =
        ServiceLocator.instance.sessionService.companyIdOrNull;
    if (currentTenantId == null || currentTenantId <= 0) {
      debugPrint('[SYNC] Invalid companyId=$currentTenantId - skipping pull');
      return;
    }

    final storage = ServiceLocator.instance.secureStorage;
    final token = await storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      debugPrint('[SYNC] No auth token - skipping pull');
      return;
    }

    String? companyId = await storage.read(key: 'company_id');
    if (companyId == null || companyId.isEmpty) {
      debugPrint('[SYNC] Warning: company_id not found in storage.');
    }

    debugPrint('[DIAG] 2: before deviceId');
    String? deviceId = await storage.read(key: 'device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await storage.write(key: 'device_id', value: deviceId);
      debugPrint('[SYNC] Generated new device ID: $deviceId');
    }
    debugPrint('[DIAG] 3: after deviceId: $deviceId');

    debugPrint('[DIAG] 4: before lastSyncTime');
    final lastSyncTime = await _getLastSyncTime();
    final lastCursor = await _getLastSyncCursor();
    debugPrint('[DIAG] 5: after lastSyncTime: $lastSyncTime, lastCursor: $lastCursor');

    // Prefer cursor over timestamp — cursor is more precise
    final String syncFrom = lastCursor 
        ?? lastSyncTime?.toUtc().toIso8601String() 
        ?? '2020-01-01T00:00:00.000Z';

    // ===== DIAG LOG 1: When pull is triggered =====
    debugPrint('[DIAG][PULL_TRIGGER] syncFrom=$syncFrom (cursor: $lastCursor, timestamp: ${lastSyncTime?.toIso8601String()})');

    debugPrint('[DIAG] 6: before payload');
    final syncPayload = {
      'deviceId': deviceId,
      'lastPulledAt': syncFrom,
      'operations': <Map<String, dynamic>>[],
    };
    debugPrint('[SYNC][PULL] Payload: ${jsonEncode(syncPayload)}');
    debugPrint(
      '[SYNC][PULL] Requesting since: $syncFrom',
    );
    debugPrint('[SYNC][PULL] Tenant: $_companyId');

    debugPrint('[DIAG] 7: about to call dio.post');
    final response = await dio
        .post(
          'api/sync',
          data: syncPayload,
          options: Options(
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        )
        .timeout(
          const Duration(seconds: 35),
          onTimeout: () => throw TimeoutException('Sync request timed out'),
        );

    debugPrint('[SYNC][PULL] Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final responseData = response.data as Map<String, dynamic>;

      final operations = responseData['operations'] as List<dynamic>?;

      // ===== DIAG LOG 2: When server response arrives =====
      debugPrint('[DIAG][PULL_RECORDS] ${operations?.length ?? 0} records received from server');

      if (operations != null && operations.isNotEmpty) {
        debugPrint('[SYNC][PULL] Received ${operations.length} operations');

        for (var op in operations) {
          // ===== DIAG LOG 3: When each pulled record is upserted =====
          debugPrint('[DIAG][PULL_UPSERT] ${op['table']}:${op['recordId']} type=${op['type']}');
          await _processOperation(op);
        }
      } else {
        debugPrint('[SYNC][PULL] No operations to process');
      }

      final nextCursor = responseData['nextCursor'] as String?;
      if (nextCursor != null) {
        await _updateLastSyncCursor(nextCursor);
        debugPrint('[DIAG][CURSOR_SAVED] nextCursor=$nextCursor');
      }

      // Use server's time to avoid local clock drift
      final serverTime = responseData['serverTime'] as String?;
      if (serverTime != null) {
        await _updateLastSyncTime(DateTime.parse(serverTime).toLocal());
        debugPrint('[DIAG][SYNC_TIME_UPDATED] serverTime=$serverTime -> local=${DateTime.parse(serverTime).toLocal().toIso8601String()}');
      } else {
        await _updateLastSyncTime(DateTime.now());
      }
      
      // ===== DIAG LOG 4: When sync completes =====
      debugPrint('[DIAG][PULL_COMPLETE] Success - all records upserted');
      debugPrint('[SYNC][PULL] ✓ Completed');
    } else {
      debugPrint('[DIAG][PULL_ERROR] Server returned status: ${response.statusCode}');
    }
  }

  Future<void> _processOperation(Map<String, dynamic> op) async {
    final table = op['table'] as String?;
    final type = op['type'] as String?;
    final data = op['data'] as Map<String, dynamic>?;
    final recordId = op['recordId'] as String?;

    if (table == null || type == null) {
      debugPrint('[SYNC][PULL] Skipping op - missing table or type');
      return;
    }

    debugPrint('[SYNC][PULL] $type on $table (recordId: $recordId)');

    switch (table) {
      case 'units':
        await _upsertUnit(data);
        break;
      case 'categories':
        await _upsertCategory(data);
        break;
      case 'brands':
        await _upsertBrand(data);
        break;
      case 'products':
        await _upsertProduct(data);
        break;
      case 'customers':
        await _upsertCustomer(data);
        break;
      case 'suppliers':
        await _upsertSupplier(data);
        break;
      case 'employees':
        await _upsertEmployee(data);
        break;
      case 'invoices':
        await _upsertInvoice(data);
        break;
      default:
        debugPrint('[SYNC][PULL] Unknown table: $table');
    }
  }

  // Individual upsert handlers (unchanged from original)
  Future<void> _upsertUnit(Map<String, dynamic>? data) async {
    if (data == null) return;
    
    final uuid = data['uuid'] as String? ?? '';
    if (uuid.isEmpty) return;
    
    final existing = await (db.select(db.units)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.units)
            ..where((t) => t.uuid.equals(uuid)))
          .write(
            UnitsCompanion(
              uuid: Value(data['uuid'] as String? ?? ''),
              name: Value(data['name'] as String? ?? ''),
              symbol: Value(data['symbol'] as String? ?? ''),
              isActive: Value(data['is_active'] as bool? ?? true),
              companyId: Value(data['company_id'] as int? ?? _companyId),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    } else {
      await db.into(db.units).insert(
        UnitsCompanion(
          uuid: Value(data['uuid'] as String? ?? ''),
          name: Value(data['name'] as String? ?? ''),
          symbol: Value(data['symbol'] as String? ?? ''),
          isActive: Value(data['is_active'] as bool? ?? true),
          companyId: Value(data['company_id'] as int? ?? _companyId),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertCategory(Map<String, dynamic>? data) async {
    if (data == null) return;
    
    final uuid = data['uuid'] as String? ?? '';
    if (uuid.isEmpty) return;
    
    final existing = await (db.select(db.categories)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.categories)
            ..where((t) => t.uuid.equals(uuid)))
          .write(
            CategoriesCompanion(
              uuid: Value(data['uuid'] as String? ?? ''),
              name: Value(data['name'] as String? ?? ''),
              subcategory: Value(data['subcategory'] as String?),
              description: Value(data['description'] as String?),
              isActive: Value(data['is_active'] as bool? ?? true),
              companyId: Value(data['company_id'] as int? ?? _companyId),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    } else {
      await db.into(db.categories).insert(
        CategoriesCompanion(
          uuid: Value(data['uuid'] as String? ?? ''),
          name: Value(data['name'] as String? ?? ''),
          subcategory: Value(data['subcategory'] as String?),
          description: Value(data['description'] as String?),
          isActive: Value(data['is_active'] as bool? ?? true),
          companyId: Value(data['company_id'] as int? ?? _companyId),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertBrand(Map<String, dynamic>? data) async {
    if (data == null) return;
    
    final uuid = data['uuid'] as String? ?? '';
    if (uuid.isEmpty) return;
    
    final existing = await (db.select(db.brands)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.brands)
            ..where((t) => t.uuid.equals(uuid)))
          .write(
            BrandsCompanion(
              uuid: Value(data['uuid'] as String? ?? ''),
              name: Value(data['name'] as String? ?? ''),
              description: Value(data['description'] as String?),
              isActive: Value(data['is_active'] as bool? ?? true),
              companyId: Value(data['company_id'] as int? ?? _companyId),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    } else {
      await db.into(db.brands).insert(
        BrandsCompanion(
          uuid: Value(data['uuid'] as String? ?? ''),
          name: Value(data['name'] as String? ?? ''),
          description: Value(data['description'] as String?),
          isActive: Value(data['is_active'] as bool? ?? true),
          companyId: Value(data['company_id'] as int? ?? _companyId),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertProduct(Map<String, dynamic>? data) async {
    if (data == null) return;
    
    final uuid = data['uuid'] as String? ?? '';
    if (uuid.isEmpty) return;
    
    // Manual upsert by uuid - deterministic, no constraint surprises
    final existing = await (db.select(db.products)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      // UPDATE existing record by uuid
      await (db.update(db.products)
            ..where((t) => t.uuid.equals(uuid)))
          .write(
            ProductsCompanion(
              uuid: Value(data['uuid'] as String? ?? ''),
              name: Value(data['name'] as String? ?? ''),
              sku: Value(data['sku'] as String?),
              price: Value((data['price'] as num?)?.toDouble() ?? 0.0),
              cost: Value((data['cost'] as num?)?.toDouble()),
              stockQuantity: Value(data['stock_quantity'] as int? ?? 0),
              isActive: Value(data['is_active'] as bool? ?? true),
              companyId: Value(data['company_id'] as int? ?? _companyId),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    } else {
      // INSERT new record
      await db.into(db.products).insert(
        ProductsCompanion(
          uuid: Value(data['uuid'] as String? ?? ''),
          name: Value(data['name'] as String? ?? ''),
          sku: Value(data['sku'] as String?),
          price: Value((data['price'] as num?)?.toDouble() ?? 0.0),
          cost: Value((data['cost'] as num?)?.toDouble()),
          stockQuantity: Value(data['stock_quantity'] as int? ?? 0),
          isActive: Value(data['is_active'] as bool? ?? true),
          companyId: Value(data['company_id'] as int? ?? _companyId),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertCustomer(Map<String, dynamic>? data) async {
    if (data == null) return;
    
    final uuid = data['uuid'] as String? ?? '';
    if (uuid.isEmpty) return;
    
    final existing = await (db.select(db.customers)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.customers)
            ..where((t) => t.uuid.equals(uuid)))
          .write(
            CustomersCompanion(
              uuid: Value(data['uuid'] as String? ?? ''),
              name: Value(data['name'] as String? ?? ''),
              phone: Value(data['phone'] as String?),
              email: Value(data['email'] as String?),
              address: Value(data['address'] as String?),
              creditLimit: Value(
                (data['credit_limit'] as num?)?.toDouble() ?? 0.0,
              ),
              currentBalance: Value(
                (data['current_balance'] as num?)?.toDouble() ?? 0.0,
              ),
              companyId: Value(data['company_id'] as int? ?? _companyId),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    } else {
      await db.into(db.customers).insert(
        CustomersCompanion(
          uuid: Value(data['uuid'] as String? ?? ''),
          name: Value(data['name'] as String? ?? ''),
          phone: Value(data['phone'] as String?),
          email: Value(data['email'] as String?),
          address: Value(data['address'] as String?),
          creditLimit: Value(
            (data['credit_limit'] as num?)?.toDouble() ?? 0.0,
          ),
          currentBalance: Value(
            (data['current_balance'] as num?)?.toDouble() ?? 0.0,
          ),
          companyId: Value(data['company_id'] as int? ?? _companyId),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertSupplier(Map<String, dynamic>? data) async {
    if (data == null) return;
    
    final uuid = data['uuid'] as String? ?? '';
    if (uuid.isEmpty) return;
    
    final existing = await (db.select(db.suppliers)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.suppliers)
            ..where((t) => t.uuid.equals(uuid)))
          .write(
            SuppliersCompanion(
              uuid: Value(data['uuid'] as String? ?? ''),
              name: Value(data['name'] as String? ?? ''),
              phone: Value(data['phone'] as String?),
              email: Value(data['email'] as String?),
              address: Value(data['address'] as String?),
              companyId: Value(data['company_id'] as int? ?? _companyId),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    } else {
      await db.into(db.suppliers).insert(
        SuppliersCompanion(
          uuid: Value(data['uuid'] as String? ?? ''),
          name: Value(data['name'] as String? ?? ''),
          phone: Value(data['phone'] as String?),
          email: Value(data['email'] as String?),
          address: Value(data['address'] as String?),
          companyId: Value(data['company_id'] as int? ?? _companyId),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertEmployee(Map<String, dynamic>? data) async {
    if (data == null) return;
    
    final uuid = data['uuid'] as String? ?? '';
    if (uuid.isEmpty) return;
    
    final existing = await (db.select(db.employees)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.employees)
            ..where((t) => t.uuid.equals(uuid)))
          .write(
            EmployeesCompanion(
              uuid: Value(data['uuid'] as String? ?? ''),
              name: Value(data['name'] as String? ?? ''),
              phone: Value(data['phone'] as String?),
              email: Value(data['email'] as String?),
              address: Value(data['address'] as String?),
              role: Value(data['role'] as String? ?? 'employee'),
              password: Value(data['password'] as String?),
              companyId: Value(data['company_id'] as int? ?? _companyId),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    } else {
      await db.into(db.employees).insert(
        EmployeesCompanion(
          uuid: Value(data['uuid'] as String? ?? ''),
          name: Value(data['name'] as String? ?? ''),
          phone: Value(data['phone'] as String?),
          email: Value(data['email'] as String?),
          address: Value(data['address'] as String?),
          role: Value(data['role'] as String? ?? 'employee'),
          password: Value(data['password'] as String?),
          companyId: Value(data['company_id'] as int? ?? _companyId),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertInvoice(Map<String, dynamic>? data) async {
    if (data == null) return;
    
    final uuid = data['uuid'] as String? ?? '';
    if (uuid.isEmpty) return;
    
    final existing = await (db.select(db.invoices)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.invoices)
            ..where((t) => t.uuid.equals(uuid)))
          .write(
            InvoicesCompanion(
              uuid: Value(data['uuid'] as String? ?? ''),
              invoiceNumber: Value(data['invoice_number'] as String? ?? ''),
              customerId: Value(data['customer_id'] as int?),
              date: Value(
                data['created_at'] != null
                    ? DateTime.parse(data['created_at'])
                    : DateTime.now(),
              ),
              subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0.0),
              tax: Value((data['tax'] as num?)?.toDouble() ?? 0.0),
              discount: Value((data['discount'] as num?)?.toDouble() ?? 0.0),
              total: Value((data['total'] as num?)?.toDouble() ?? 0.0),
              paymentMethod: Value(data['payment_method'] as String?),
              companyId: Value(data['company_id'] as int? ?? _companyId),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(0),
              isDeleted: Value(data['is_deleted'] as bool? ?? false),
            ),
          );
    } else {
      await db.into(db.invoices).insert(
        InvoicesCompanion(
          uuid: Value(data['uuid'] as String? ?? ''),
          invoiceNumber: Value(data['invoice_number'] as String? ?? ''),
          customerId: Value(data['customer_id'] as int?),
          date: Value(
            data['created_at'] != null
                ? DateTime.parse(data['created_at'])
                : DateTime.now(),
          ),
          subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0.0),
          tax: Value((data['tax'] as num?)?.toDouble() ?? 0.0),
          discount: Value((data['discount'] as num?)?.toDouble() ?? 0.0),
          total: Value((data['total'] as num?)?.toDouble() ?? 0.0),
          paymentMethod: Value(data['payment_method'] as String?),
          companyId: Value(data['company_id'] as int? ?? _companyId),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(data['is_deleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _updateLastSyncCursor(String cursor) async {
    try {
      await db
          .into(db.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion(
              key: const Value('lastSyncCursor'),
              value: Value(cursor),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } catch (_) {}
  }

  Future<String?> _getLastSyncCursor() async {
    try {
      final record = await (db.select(
        db.syncMetadata,
      )..where((t) => t.key.equals('lastSyncCursor'))).getSingleOrNull();
      return record?.value;
    } catch (e) {
      return null;
    }
  }

  /// Force a full sync, ignoring lastSyncTime
  Future<void> forcePull() async {
    try {
      final storage = ServiceLocator.instance.secureStorage;
      String? deviceId = await storage.read(key: 'device_id');
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await storage.write(key: 'device_id', value: deviceId);
        debugPrint('[SYNC] Generated new device ID: $deviceId');
      }

      debugPrint('[SYNC][FORCE PULL] Starting full sync with deviceId: $deviceId');

      final response = await dio
          .post(
            'api/sync',
            data: {
              'deviceId': deviceId,
              'lastPulledAt': null,
              'operations': <Map<String, dynamic>>[],
            },
            options: Options(
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          )
          .timeout(
            const Duration(seconds: 35),
            onTimeout: () => throw TimeoutException('Force pull timed out'),
          );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        final updates = responseData['updates'] as Map<String, dynamic>?;
        if (updates != null) {
          debugPrint('[SYNC][FORCE PULL] Applying updates...');
          await _applyUpdates(updates);
          debugPrint('[SYNC][FORCE PULL] ✓ Full sync completed');
        }
        await _updateLastSyncTime(DateTime.now());
      } else {
        debugPrint(
          '[SYNC][FORCE PULL] Unexpected status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[SYNC][FORCE PULL] ERROR - $e');
      rethrow;
    }
  }

  // ----------------------------------------------------------------------
  // PUSH – NOW USES UNIFIED /api/sync ENDPOINT
  // ----------------------------------------------------------------------
  Future<SyncResult> push() async {
    debugPrint('DEBUG SYNC: push() STARTING with companyId=$_companyId');
    final syncedCounts = <String, int>{
      'categories': 0,
      'units': 0,
      'brands': 0,
      'products': 0,
      'customers': 0,
      'suppliers': 0,
      'employees': 0,
      'invoices': 0,
    };
    final failedCounts = <String, int>{
      'categories': 0,
      'units': 0,
      'brands': 0,
      'products': 0,
      'customers': 0,
      'suppliers': 0,
      'employees': 0,
      'invoices': 0,
    };
    final errors = <String>[];

    try {
      // 1. Collect all pending local operations (syncStatus = 1)
      final pending = await _collectAllPendingOperations();
      if (pending.isEmpty) {
        debugPrint('[SYNC][PUSH] No local changes to push.');
        return SyncResult(
          success: true,
          syncedCounts: syncedCounts,
          failedCounts: failedCounts,
          errors: errors,
        );
      }

      // 2. Build the operations array and a map to track opId -> local record
      final operations = <Map<String, dynamic>>[];
      final opIdToRecord = <String, _RecordRef>{};

      for (final op in pending) {
        final opId = const Uuid().v4();
        final recordUuid = op.uuid;
        final tableName = op.table;

        final data = _sanitizeData(op.data);

        operations.add({
          'opId': opId,
          'type': 'INSERT', // Server performs UPSERT based on UUID
          'table': tableName,
          'recordId': recordUuid,
          'data': data,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });

        opIdToRecord[opId] = _RecordRef(tableName, recordUuid, op.localId);
      }

      // 3. Send to /api/sync (combined push + pull handled by _doSync)
      final storage = ServiceLocator.instance.secureStorage;
      final deviceId = await storage.read(key: 'device_id') ?? '';
      final lastSyncTime = await _getLastSyncTime() ?? DateTime.utc(2026);

      debugPrint('[SYNC][PUSH] Sending ${operations.length} operations');
      final response = await dio.post(
        '/api/sync',
        data: {
          'deviceId': deviceId,
          'lastPulledAt': lastSyncTime.toUtc().toIso8601String(),
          'operations': operations,
        },
      );

      if (response.statusCode != 200) {
        errors.add('Push failed with status ${response.statusCode}');
        return SyncResult(
          success: false,
          syncedCounts: syncedCounts,
          failedCounts: failedCounts,
          errors: errors,
        );
      }

      // 4. Process acknowledgements
      final ackList = response.data['acknowledged'] as List<dynamic>? ?? [];
      for (final ack in ackList) {
        final opId = ack['opId'] as String?;
        final status = ack['status'] as String?;
        if (opId == null) continue;

        final ref = opIdToRecord[opId];
        if (ref == null) continue;

        if (status == 'SUCCESS') {
          await _markSynced(ref);
          syncedCounts[ref.table] = (syncedCounts[ref.table] ?? 0) + 1;
        } else {
          final errorMsg = ack['error']?['message'] ?? 'Unknown error';
          errors.add('[${ref.table}] $errorMsg (uuid: ${ref.uuid})');
          await _markFailed(ref);
          failedCounts[ref.table] = (failedCounts[ref.table] ?? 0) + 1;
        }
      }

      debugPrint(
        '[SYNC][PUSH] ✓ Completed. Synced: $syncedCounts, Failed: $failedCounts',
      );
    } catch (e, st) {
      errors.add('Unexpected push error: $e');
      debugPrint('[SYNC][PUSH] ERROR: $e\n$st');
    }

    final hasFailures = failedCounts.values.any((c) => c > 0);
    return SyncResult(
      success: !hasFailures && errors.isEmpty,
      syncedCounts: syncedCounts,
      failedCounts: failedCounts,
      errors: errors,
    );
  }

  // ----------------------------------------------------------------------
  // PRIVATE HELPERS FOR PUSH
  // ----------------------------------------------------------------------

  /// Collect all records with syncStatus=1 from every table
  Future<List<_PendingOp>> _collectAllPendingOperations() async {
    final ops = <_PendingOp>[];

    Future<void> collect<T extends Table, D extends DataClass>(
      TableInfo<T, D> table,
      String tableName,
      Map<String, dynamic> Function(D record) toMap,
    ) async {
      final records = await (db.select(
        table,
      )..where((t) => (t as dynamic).syncStatus.equals(1))).get();
      for (final r in records) {
        final uuid = (r as dynamic).uuid as String?;
        final localId = (r as dynamic).id as int;
        if (uuid == null || uuid.isEmpty || !isValidUUID(uuid)) continue;

        Map<String, dynamic> dataMap = toMap(r);

        // For invoices, fetch and attach invoice items
        if (tableName == 'invoices') {
          final items = await _getInvoiceItems(localId);
          dataMap['items'] = items;
        }

        ops.add(_PendingOp(tableName, uuid, localId, dataMap));
      }
    }

    await collect(db.categories, 'categories', (e) => e.toJson());
    await collect(db.units, 'units', (e) => e.toJson());
    await collect(db.brands, 'brands', (e) => e.toJson());
    await collect(db.products, 'products', (e) => e.toJson());
    await collect(db.customers, 'customers', (e) => e.toJson());
    await collect(db.suppliers, 'suppliers', (e) => e.toJson());
    await collect(db.employees, 'employees', (e) => e.toJson());
    await collect(db.invoices, 'invoices', (e) => e.toJson());

    return ops;
  }

  /// Retrieve items for a given invoice (local ID)
  Future<List<Map<String, dynamic>>> _getInvoiceItems(int invoiceId) async {
    final rows = await (db.select(
      db.invoiceItems,
    )..where((t) => t.invoiceId.equals(invoiceId))).get();

    final items = <Map<String, dynamic>>[];
    for (final item in rows) {
      // Optionally fetch product uuid for reference
final productUuid = (await (db.select(db.products)
                ..where((t) => t.id.equals(item.productId)))
              .getSingleOrNull())?.uuid;

      items.add({
        'uuid': item.uuid,
        'productUuid': productUuid,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'totalPrice': item.totalPrice,
        'bonus': item.bonus,
        'discount': item.discount,
      });
    }
    return items;
  }

  /// Remove local-only fields that should not be sent to the server
  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    sanitized.remove('id');
    sanitized.remove('companyId');
    sanitized.remove('companyId'); // Server uses X-Company-Id header
    sanitized.remove('syncStatus');
    sanitized.remove('updatedAt');
    sanitized.remove('createdAt');
    sanitized.remove('uuid'); // Already in recordId
    // Remove any other internal fields your tables may have, e.g.:
    sanitized.remove('isDeleted'); // Usually handled via DELETE operation
    return sanitized;
  }

  /// Mark a local record as synced (syncStatus = 0)
  Future<void> _markSynced(_RecordRef ref) async {
    switch (ref.table) {
      case 'categories':
        await (db.update(db.categories)..where((t) => t.id.equals(ref.localId)))
            .write(const CategoriesCompanion(syncStatus: Value(0)));
        break;
      case 'units':
        await (db.update(db.units)..where((t) => t.id.equals(ref.localId)))
            .write(const UnitsCompanion(syncStatus: Value(0)));
        break;
      case 'brands':
        await (db.update(db.brands)..where((t) => t.id.equals(ref.localId)))
            .write(const BrandsCompanion(syncStatus: Value(0)));
        break;
      case 'products':
        await (db.update(db.products)..where((t) => t.id.equals(ref.localId)))
            .write(const ProductsCompanion(syncStatus: Value(0)));
        break;
      case 'customers':
        await (db.update(db.customers)..where((t) => t.id.equals(ref.localId)))
            .write(const CustomersCompanion(syncStatus: Value(0)));
        break;
      case 'suppliers':
        await (db.update(db.suppliers)..where((t) => t.id.equals(ref.localId)))
            .write(const SuppliersCompanion(syncStatus: Value(0)));
        break;
      case 'employees':
        await (db.update(db.employees)..where((t) => t.id.equals(ref.localId)))
            .write(const EmployeesCompanion(syncStatus: Value(0)));
        break;
      case 'invoices':
        await (db.update(db.invoices)..where((t) => t.id.equals(ref.localId)))
            .write(const InvoicesCompanion(syncStatus: Value(0)));
        break;
    }
  }

  /// Mark a local record as permanently failed (syncStatus = 2)
  Future<void> _markFailed(_RecordRef ref) async {
    switch (ref.table) {
      case 'categories':
        await (db.update(db.categories)..where((t) => t.id.equals(ref.localId)))
            .write(const CategoriesCompanion(syncStatus: Value(2)));
        break;
      case 'units':
        await (db.update(db.units)..where((t) => t.id.equals(ref.localId)))
            .write(const UnitsCompanion(syncStatus: Value(2)));
        break;
      case 'brands':
        await (db.update(db.brands)..where((t) => t.id.equals(ref.localId)))
            .write(const BrandsCompanion(syncStatus: Value(2)));
        break;
      case 'products':
        await (db.update(db.products)..where((t) => t.id.equals(ref.localId)))
            .write(const ProductsCompanion(syncStatus: Value(2)));
        break;
      case 'customers':
        await (db.update(db.customers)..where((t) => t.id.equals(ref.localId)))
            .write(const CustomersCompanion(syncStatus: Value(2)));
        break;
      case 'suppliers':
        await (db.update(db.suppliers)..where((t) => t.id.equals(ref.localId)))
            .write(const SuppliersCompanion(syncStatus: Value(2)));
        break;
      case 'employees':
        await (db.update(db.employees)..where((t) => t.id.equals(ref.localId)))
            .write(const EmployeesCompanion(syncStatus: Value(2)));
        break;
      case 'invoices':
        await (db.update(db.invoices)..where((t) => t.id.equals(ref.localId)))
            .write(const InvoicesCompanion(syncStatus: Value(2)));
        break;
    }
  }

  // (Optional) Sync only products – kept for backward compatibility
  Future<bool> syncProducts() async {
    try {
      await pull();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Legacy full-sync method (used by forcePull)
  Future<void> _applyUpdates(Map<String, dynamic> updates) async {
    Future<void> upsert<T extends Table, D extends DataClass>(
      TableInfo<T, D> table,
      dynamic data,
      D Function(Map<String, dynamic>) fromJson,
    ) async {
      if (data != null && data is List) {
        for (var item in data) {
          try {
            final map = Map<String, dynamic>.from(item);
            map['syncStatus'] = 0;
            if (map.containsKey('companyId') && map['companyId'] != null) {
              map['companyId'] = map['companyId'];
            }
            if (!map.containsKey('updatedAt') || map['updatedAt'] == null) {
              map['updatedAt'] =
                  map['createdAt'] ?? DateTime.now().toIso8601String();
            }
            if (!map.containsKey('isDeleted') || map['isDeleted'] == null) {
              map['isDeleted'] = false;
            }
            final entity = fromJson(map);
            await db
                .into(table)
                .insertOnConflictUpdate(entity as Insertable<D>);
          } catch (e) {
            if (e.toString().contains('UNIQUE constraint failed')) {
            } else {}
          }
        }
      }
    }

    await upsert(db.categories, updates['categories'], CategoryEntity.fromJson);
    await upsert(db.units, updates['units'], UnitEntity.fromJson);
    await upsert(db.brands, updates['brands'], BrandEntity.fromJson);
    await upsert(db.products, updates['products'], ProductEntity.fromJson);
    await upsert(db.customers, updates['customers'], CustomerEntity.fromJson);
    await upsert(db.suppliers, updates['suppliers'], SupplierEntity.fromJson);
    await upsert(db.employees, updates['employees'], EmployeeEntity.fromJson);
    await upsert(db.invoices, updates['invoices'], InvoiceEntity.fromJson);
    await upsert(
      db.invoiceItems,
      updates['invoiceItems'],
      InvoiceItemEntity.fromJson,
    );
  }

  Future<DateTime?> _getLastSyncTime() async {
    try {
      final record = await (db.select(
        db.syncMetadata,
      )..where((t) => t.key.equals('lastSyncTime'))).getSingleOrNull();
      if (record == null || record.value == null) return null;
      return DateTime.tryParse(record.value ?? '');
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateLastSyncTime(DateTime time) async {
    try {
      await db
          .into(db.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion(
              key: const Value('lastSyncTime'),
              value: Value(time.toIso8601String()),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } on Object catch (_) {}
  }
}
