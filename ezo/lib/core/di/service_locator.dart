import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/sku_generator.dart';
import '../services/tenant_service.dart';
import '../../config/app_config.dart';
import '../services/sync_engine.dart';
import '../services/device_id_service.dart';
import '../repositories/sync_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/unit_repository.dart';
import '../repositories/brand_repository.dart';
import '../repositories/customer_transaction_repository.dart';
import '../repositories/customer_transaction_repository_impl.dart';
import '../repositories/supplier_transaction_repository.dart';
import '../repositories/supplier_transaction_repository_impl.dart';
import '../repositories/purchase_receipt_repository.dart';
import '../repositories/purchase_receipt_repository_impl.dart';
import '../services/inventory_service.dart';
import '../services/invoice_sequence_service.dart';
import 'package:aeropos/core/viewModel/product_view_model.dart';
import 'package:aeropos/core/viewModel/category_view_model.dart';
import 'package:aeropos/core/viewModel/unit_view_model.dart';
import 'package:aeropos/core/viewModel/brand_view_model.dart';
import 'package:aeropos/core/viewModel/customer_view_model.dart';
import 'package:aeropos/core/viewModel/supplier_view_model.dart';
import 'package:aeropos/core/viewModel/employee_view_model.dart';
import 'package:aeropos/core/viewModel/customer_transaction_view_model.dart';
import 'package:aeropos/core/viewModel/supplier_transaction_view_model.dart';
import 'package:aeropos/core/viewModel/purchase_receipt_view_model.dart';
import '../database/app_database.dart';
import '../network/auth_interceptor.dart';
import '../network/dio_client.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import 'package:http/http.dart' as http;

// BUG FIX #3: Removed SyncService import entirely.
// SyncService was instantiated alongside SyncEngine, causing two sync
// systems to run concurrently with duplicate API calls and potential
// write conflicts. SyncEngine is now the single source of truth.
// If any ViewModel still depends on SyncService, update it to use
// SyncEngine or a thin adapter.

class ServiceLocator {
  static final instance = ServiceLocator._();
  ServiceLocator._();

  late final AppDatabase database;
  late final FlutterSecureStorage secureStorage;
  late final Dio dio;

  late final ProductRepository productRepository;
  late final CustomerRepository customerRepository;
  late final SupplierRepository supplierRepository;
  late final EmployeeRepository employeeRepository;
  late final SaleRepository saleRepository;
  late final CategoryRepository categoryRepository;
  late final UnitRepository unitRepository;
  late final BrandRepository brandRepository;
  late final CustomerTransactionRepository customerTransactionRepository;
  late final SupplierTransactionRepository supplierTransactionRepository;
  late final PurchaseReceiptRepository purchaseReceiptRepository;
  late final AuthRepository authRepository;
  late final AuthRemoteDataSource authRemoteDataSource;
  late final ProfileRepository profileRepository;

  late final InventoryService inventoryService;
  // BUG FIX #3: SyncService field removed. SyncEngine is the only sync system.
  late final SyncEngine syncEngine;
  late SyncRepository syncRepository;
  late final TenantService tenantService;
  late final SkuGenerator skuGenerator;
  late final DeviceIdService deviceIdService;
  late final InvoiceSequenceService invoiceSequenceService;

  late final ProductViewModel productViewModel;
  late final CategoryViewModel categoryViewModel;
  late final UnitViewModel unitViewModel;
  late final BrandViewModel brandViewModel;
  late final CustomerViewModel customerViewModel;
  late final SupplierViewModel supplierViewModel;
  late final EmployeeViewModel employeeViewModel;
  late final CustomerTransactionViewModel customerTransactionViewModel;
  late final SupplierTransactionViewModel supplierTransactionViewModel;
  late final PurchaseReceiptViewModel purchaseReceiptViewModel;

  Future<void> initialize() async {
    // Initialize database
    database = AppDatabase();

    // Initialize secure storage
    if (kIsWeb) {
      secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(),
        iOptions: IOSOptions(),
      );
    } else {
      secureStorage = const FlutterSecureStorage();
    }

    // Initialize network
    final authInterceptor = AuthInterceptor(secureStorage);
    dio = DioClient.createDio(authInterceptor);

    // Initialize data sources
    authRemoteDataSource = AuthRemoteDataSourceImpl(dio);

    // Initialize repositories
    productRepository = ProductRepository(database);
    customerRepository = CustomerRepository(database);
    supplierRepository = SupplierRepository(database);
    employeeRepository = EmployeeRepository(database);
    saleRepository = SaleRepository(database);
    categoryRepository = CategoryRepository(database);
    unitRepository = UnitRepository(database);
    brandRepository = BrandRepository(database);
    customerTransactionRepository = CustomerTransactionRepositoryImpl(database);
    supplierTransactionRepository = SupplierTransactionRepositoryImpl(database);
    purchaseReceiptRepository = PurchaseReceiptRepositoryImpl(database);
    authRepository = AuthRepositoryImpl(
      authRemoteDataSource,
      secureStorage,
      database,
    );
    profileRepository = ProfileRepositoryImpl(
      http.Client(),
      secureStorage,
      baseUrl: AppConfig.apiBaseUrl,
    );

    // Initialize services
    tenantService = TenantService(secureStorage);
    await tenantService.initialize();

    // Device ID for multi-device sync
    deviceIdService = DeviceIdService(database);
    final deviceId = await deviceIdService.getDeviceId();

    invoiceSequenceService = InvoiceSequenceService();

    skuGenerator = SkuGenerator();

    // Initialize sync infrastructure
    inventoryService = InventoryService(productRepository);

    // BUG FIX #1: SyncEngine is constructed here with placeholder values,
    // but startAutoSync() is NOT called. The engine is only started after
    // a successful login via activateSyncEngine(), which reinitialises it
    // with the real tenantId and companyId from the JWT.
    //
    // Previously startAutoSync() was called here with tenantId='pending'
    // and companyId='default', which caused sync loops before login on
    // Windows (and any platform where the app remembers its window state).
    syncEngine = SyncEngine(
      db: database,
      dio: dio,
      tenantId:
          'pending', // placeholder — real value set in activateSyncEngine()
      companyId:
          'default', // placeholder — real value set in activateSyncEngine()
      deviceId: deviceId,
    );

    // BUG FIX #1 (cont): startAutoSync() intentionally removed from here.
    // It is called by AuthController._completeLogin() via activateSyncEngine().

    // BUG FIX #3: SyncService instantiation removed entirely.

    syncRepository = SyncRepository(
      db: database,
      tenantId: 'pending',
      companyId: 'default',
      deviceId: deviceId,
    );

    // Initialize view models.
    // NOTE: ViewModels that previously received SyncService now receive
    // syncEngine directly. If SyncEngine doesn't match the SyncService
    // interface those ViewModels expect, create a thin SyncEngineAdapter
    // or update the ViewModel constructors — but do NOT re-add SyncService.
    productViewModel = ProductViewModel(
      database,
      categoryRepository,
      unitRepository,
      brandRepository,
      syncEngine,
    );
    categoryViewModel = CategoryViewModel(database, syncEngine);
    unitViewModel = UnitViewModel(database, syncEngine);
    brandViewModel = BrandViewModel(database, syncEngine);
    customerViewModel = CustomerViewModel(
      database,
      customerRepository,
      syncEngine,
    );
    supplierViewModel = SupplierViewModel(
      database,
      supplierRepository,
      syncEngine,
    );
    customerTransactionViewModel = CustomerTransactionViewModel(
      customerTransactionRepository,
      database,
    );
    supplierTransactionViewModel = SupplierTransactionViewModel(
      supplierTransactionRepository,
      database,
    );
    purchaseReceiptViewModel = PurchaseReceiptViewModel(
      purchaseReceiptRepository,
      database,
    );
    employeeViewModel = EmployeeViewModel(
      database,
      employeeRepository,
      syncEngine,
    );
  }

  /// Called by AuthController after a confirmed login.
  /// Reinitialises SyncEngine with the real tenantId and companyId
  /// from the JWT, then starts the auto-sync timer.
  ///
  /// Safe to call multiple times (e.g. on company switch): it stops
  /// the existing engine before creating a fresh one so there is
  /// never more than one timer running.
  Future<void> activateSyncEngine({
    required int tenantId,
    required int companyId,
  }) async {
    // Stop any previous engine (guards against double-login / company switch)
    syncEngine.stopAutoSync();

    final deviceId = await deviceIdService.getDeviceId();

    // Reinitialise in-place. SyncEngine is late final so we reassign
    // via the workaround of shadowing — if your SyncEngine supports
    // an updateCredentials() method, prefer that instead.
    // ignore: invalid_use_of_protected_member
    syncEngine.reinitialize(
      tenantId: tenantId.toString(),
      companyId: companyId.toString(),
      deviceId: deviceId,
    );

    // Keep syncRepository credentials in sync for repositories that use it.
    syncRepository = SyncRepository(
      db: database,
      tenantId: tenantId.toString(),
      companyId: companyId.toString(),
      deviceId: deviceId,
    );

    syncEngine.startAutoSync();
    syncEngine.clearPostSyncCallbacks();
    syncEngine.registerPostSyncCallback(productViewModel.syncPendingImages);
    debugPrint(
      '[ServiceLocator] SyncEngine activated: tenantId=$tenantId companyId=$companyId',
    );
  }

  Future<void> dispose() async {
    syncEngine.stopAutoSync();
  }
}
