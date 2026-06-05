import 'dart:async';
import 'package:aeropos/features/auth/presentation/providers/auth_controller.dart';
import 'package:aeropos/features/auth/presentation/screens/login_screen.dart';
import 'package:aeropos/features/auth/presentation/screens/signup_screen.dart';
import 'package:aeropos/features/auth/presentation/screens/email_verification_pending_screen.dart';
import 'package:aeropos/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:aeropos/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:aeropos/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:aeropos/features/auth/presentation/screens/company_picker_screen.dart';
import 'package:aeropos/features/inventory/products/item_list.dart';
import 'package:aeropos/features/inventory/products/add_product_screen.dart';
import 'package:aeropos/features/inventory/products/product_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/database/app_database.dart';
import '../layout/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import 'package:aeropos/features/inventory/categories/category_list_screen.dart';
import 'package:aeropos/features/inventory/units/unit_list_screen.dart';
import 'package:aeropos/features/inventory/brands/brand_list_screen.dart';
import 'package:aeropos/features/customers/customer_list_screen.dart';
import 'package:aeropos/features/suppliers/supplier_list_screen.dart';
import 'package:aeropos/features/employees/employee_list_screen.dart';
import 'package:aeropos/features/pos/pos_screen.dart';
import 'package:aeropos/features/inventory/reports/invoice_settings_screen.dart';
import 'package:aeropos/features/stock_mgmt/inventory_dashboard_screen.dart';
import 'package:aeropos/features/purchase_receipt/purchase_receipt_screen.dart';
import 'package:aeropos/features/ledger/customer_ledger/customer_ledger.dart';
import 'package:aeropos/features/ledger/supplier_ledger/supplier_ledger.dart';
import 'package:aeropos/features/purchase_receipt/purchase_entry_screen.dart';
import 'package:aeropos/features/debug_screen.dart';

import 'package:aeropos/features/invoice/screens/invoice_history_screen.dart';
import 'package:aeropos/features/invoice/invoice_template_editor/main.dart';
import 'package:aeropos/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:aeropos/features/profile/presentation/screens/company_profile_screen.dart';
import 'package:aeropos/features/profile/presentation/screens/my_companies_screen.dart';
import 'package:aeropos/features/settings/screens/settings_screen.dart';
import 'package:aeropos/features/settings/screens/role_settings_screen.dart';
import 'package:aeropos/features/ledger/customer_ledger/add_customer_ledger.dart';
import 'package:aeropos/features/ledger/supplier_ledger/add_supplier_ledger.dart';
import 'package:aeropos/features/barcode/screens/barcode_generation_screen.dart';
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authController = ref.watch(authControllerProvider.notifier);
  // Stores the path the user was trying to reach before auth loading started.
  // After auth completes, the redirect restores them there instead of /dashboard.
  String? intendedPath;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authController.stream),
    redirect: (context, state) {
      // 1. URL Sanitizer: Fixes occurrences of "//" or absolute placeholders.
      if (kIsWeb) {
        // Resolve absolute mismatch if backend used a placeholder hostname
        if (state.uri.isAbsolute && state.uri.host == 'verify-email') {
          final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '/verify-email$query';
        }

        // Clean double slashes recursively in the full URI string if path was misparsed
        if (state.uri.toString().contains('//') &&
            !state.uri.toString().contains('://')) {
          final cleanPath = state.uri.path.replaceAll(RegExp(r'/+'), '/');
          final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '$cleanPath$query';
        }

        if (state.uri.path.contains('//')) {
          final cleanPath = state.uri.path.replaceAll(RegExp(r'/+'), '/');
          final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '$cleanPath$query';
        }
      }

      final authState = ref.read(authControllerProvider);

      // While auth is being determined, hold on a neutral loading screen.
      // Save where the user was so we can restore them after auth completes.
      if (authState.status == AuthStatus.loading) {
        final current = state.uri.path;
        final isAlreadySplash = current == '/splash';
        // Only remember authenticated-area paths (ignore public/splash paths).
        if (!isAlreadySplash &&
            current != '/login' &&
            current != '/signup' &&
            current != '/forgot-password' &&
            current != '/reset-password' &&
            current != '/verify-email' &&
            current != '/select-company') {
          intendedPath = current;
        }
        return isAlreadySplash ? null : '/splash';
      }

      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isCompanySelection =
          authState.status == AuthStatus.companySelection;
      final isPublicRoute =
          state.uri.path == '/login' ||
          state.uri.path == '/signup' ||
          state.uri.path == '/forgot-password' ||
          state.uri.path == '/reset-password' ||
          state.uri.path == '/verify-email' ||
          state.uri.path == '/select-company' ||
          state.uri.path == '/splash';

      // Redirect to company selection screen
      if (isCompanySelection && state.uri.path != '/select-company') {
        return '/select-company';
      }

      // Splash is "public" only while auth is loading. Once auth resolves,
      // unauthenticated users must leave splash or the spinner never clears.
      if (!isLoggedIn && !isCompanySelection &&
          (!isPublicRoute || state.uri.path == '/splash')) {
        return '/login';
      }

      if (isLoggedIn) {
        final user = authState.user;
        final isVerified = user?.isEmailVerified ?? false;
        final isPendingScreen = state.uri.path == '/verify-pending';

        if (!isVerified) {
          // Allow internal verification route even if not verified yet
          if (state.uri.path == '/verify-email') return null;

          if (!isPendingScreen) return '/verify-pending';
          return null;
        }

        if (isPublicRoute || isPendingScreen) {
          // Restore the page the user was on before loading interrupted them.
          // Falls back to /dashboard for fresh logins (no intended path saved).
          final destination = intendedPath ?? '/dashboard';
          intendedPath = null;
          return destination;
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-pending',
        builder: (context, state) => const EmailVerificationPendingScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return ResetPasswordScreen(token: token);
        },
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return VerifyEmailScreen(token: token);
        },
      ),
      GoRoute(
        path: '/select-company',
        builder: (context, state) => const CompanyPickerScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Index 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          // Index 1: Products
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const ProductListScreen(),
                routes: [
                  GoRoute(
                    path: 'view',
                    builder: (context, state) {
                      final product = state.extra as ProductEntity;
                      return ProductDetailScreen(product: product);
                    },
                  ),
                  GoRoute(
                    path: 'add',
                    builder: (context, state) {
                      final extra = state.extra;
                      final product = extra is ProductEntity ? extra : null;
                      final barcode = extra is String ? extra : null;
                      return AddItemScreen(product: product, initialBarcode: barcode);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Index 2: Add Product
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add-product',
                builder: (context, state) {
                  final extra = state.extra;
                  final product = extra is ProductEntity ? extra : null;
                  final barcode = extra is String ? extra : null;
                  return AddItemScreen(product: product, initialBarcode: barcode);
                },
              ),
            ],
          ),
          // Index 3: Category List
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/category-list',
                builder: (context, state) => const CategoryListScreen(),
              ),
            ],
          ),
          // Index 4: Unit List
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/unit-list',
                builder: (context, state) => const UnitListScreen(),
              ),
            ],
          ),
          // Index 5: Brand List
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/brand-list',
                builder: (context, state) => const BrandListScreen(),
              ),
            ],
          ),
          // Index 6: Customers
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customers',
                builder: (context, state) => const CustomerListScreen(),
              ),
            ],
          ),

          // Index 7: Suppliers
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/suppliers',
                builder: (context, state) => const SupplierListScreen(),
              ),
            ],
          ),

          // Index 8: Sales History
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sales-history',
                builder: (context, state) => const InvoiceHistoryScreen(),
              ),
            ],
          ),

          // Index 9: Reports
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const Scaffold(
                  body: Center(child: Text("Reports")),
                ), // Inline placeholder
              ),
            ],
          ),

          // Index 10: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'invoice',
                    builder: (context, state) => const InvoiceSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'roles',
                    builder: (context, state) => const RoleSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Index 11: User Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const UserProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'companies',
                    builder: (context, state) => const MyCompaniesScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Index 12: Company Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/company-profile',
                builder: (context, state) => const CompanyProfileScreen(),
              ),
            ],
          ),
          // Index 13: Employees
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/employees',
                builder: (context, state) => const EmployeeListScreen(),
              ),
            ],
          ),

          // Index 14: Inventory Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory-dashboard',
                builder: (context, state) => const InventoryDashboard(),
              ),
            ],
          ),

          // Index 15: Purchase Receipt
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/purchase-receipt',
                builder: (context, state) => const PurchaseReceiptPage(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) {
                      final receipt = state.extra as PurchaseReceiptEntity?;
                      return PurchaseReceiptForm(receiptToEdit: receipt);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Index 16: Customer Ledger
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customer-ledger',
                builder: (context, state) => const CustomerLedgerScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) =>
                        const AddCustomerLedgerScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Index 17: Supplier Ledger
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/supplier-ledger',
                builder: (context, state) => const SupplierLedgerScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) =>
                        const AddSupplierLedgerScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Index 18: Barcode Generation
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/barcode-generation',
                builder: (context, state) => const BarcodeGenerationScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(path: '/pos', builder: (context, state) => const PosScreen()),

      // Full screen route for Invoice Template Editor (outside AppShell)
      GoRoute(
        path: '/invoice-templates',
        builder: (context, state) => const InvoiceTemplateEditorApp(),
      ),

      // Debug route for database troubleshooting
      GoRoute(
        path: '/debug',
        builder: (context, state) => const DatabaseDebugScreen(),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
