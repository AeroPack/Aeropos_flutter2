import 'dart:async';

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/di/service_locator.dart';
// BUG FIX #3: SyncService import removed. AuthController now drives sync
// exclusively through ServiceLocator.activateSyncEngine() and SyncEngine.
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/models/user.dart';
import '../../../../core/models/company.dart';

enum AuthStatus { authenticated, unauthenticated, loading, companySelection }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final User? user;
  final Company? company;
  final List<Company>? companies;
  final String? pendingEmail;
  final String? pendingPassword;
  final String? pendingGoogleIdToken;
  final String? pendingGoogleAccessToken;

  AuthState({
    required this.status,
    this.errorMessage,
    this.user,
    this.company,
    this.companies,
    this.pendingEmail,
    this.pendingPassword,
    this.pendingGoogleIdToken,
    this.pendingGoogleAccessToken,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(User user, Company? company) =>
      AuthState(status: AuthStatus.authenticated, user: user, company: company);
  factory AuthState.unauthenticated([String? error]) =>
      AuthState(status: AuthStatus.unauthenticated, errorMessage: error);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  factory AuthState.companySelection({
    required List<Company> companies,
    String? email,
    String? password,
    String? googleIdToken,
    String? googleAccessToken,
  }) => AuthState(
    status: AuthStatus.companySelection,
    companies: companies,
    pendingEmail: email,
    pendingPassword: password,
    pendingGoogleIdToken: googleIdToken,
    pendingGoogleAccessToken: googleAccessToken,
  );

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    User? user,
    Company? company,
    List<Company>? companies,
    String? pendingEmail,
    String? pendingPassword,
    String? pendingGoogleIdToken,
    String? pendingGoogleAccessToken,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      user: user ?? this.user,
      company: company ?? this.company,
      companies: companies ?? this.companies,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      pendingPassword: pendingPassword ?? this.pendingPassword,
      pendingGoogleIdToken: pendingGoogleIdToken ?? this.pendingGoogleIdToken,
      pendingGoogleAccessToken:
          pendingGoogleAccessToken ?? this.pendingGoogleAccessToken,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  // BUG FIX #3: SyncService parameter removed from constructor.
  // Sync lifecycle is now managed by ServiceLocator.activateSyncEngine().
  AuthController(this._authRepository) : super(AuthState.initial()) {
    checkAuthStatus();
  }

  Map<String, dynamic> _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw Exception('Invalid JWT');
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded);
  }

  Future<void> checkAuthStatus() async {
    state = AuthState.loading();
    try {
      // On Linux, flutter_secure_storage uses libsecret (GNOME keyring).
      // If the keyring daemon is locked the platform channel can deadlock
      // indefinitely — add a hard timeout so the spinner always clears.
      final token = await ServiceLocator.instance.secureStorage
          .read(key: 'auth_token')
          .timeout(const Duration(seconds: 8));
      if (token == null) {
        state = AuthState.unauthenticated();
        return;
      }

      final isLoggedIn = await _authRepository.checkAuthStatus();
      if (isLoggedIn) {
        await _completeLogin();
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, 'Check authentication failed'),
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthState.loading();
    try {
      final response = await _authRepository.login(email, password);

      if (response['requiresCompanySelection'] == true) {
        final companiesList = (response['companies'] as List)
            .map((c) => Company.fromJson(c))
            .toList();
        state = AuthState.companySelection(
          companies: companiesList,
          email: email,
          password: password,
        );
        return;
      }

      await _completeLogin();
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, 'Login failed'),
      );
    }
  }

  Future<void> selectCompany(int companyId) async {
    final email = state.pendingEmail;
    final password = state.pendingPassword;
    final googleIdToken = state.pendingGoogleIdToken;
    final googleAccessToken = state.pendingGoogleAccessToken;

    state = AuthState.loading();
    try {
      if (email != null && password != null) {
        await _authRepository.login(email, password, companyId: companyId);
      } else if (googleIdToken != null || googleAccessToken != null) {
        await _authRepository.googleLogin(
          idToken: googleIdToken,
          accessToken: googleAccessToken,
          companyId: companyId,
        );
      } else {
        throw Exception('No pending credentials for company selection');
      }

      await _completeLogin();
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, 'Company selection failed'),
      );
    }
  }

  Future<void> switchCompany(int companyId) async {
    print(
      'DEBUG switchCompany: CALLED with companyId=$companyId '
      '(current tenantId=${ServiceLocator.instance.tenantService.tenantId})',
    );
    state = AuthState.loading();
    try {
      await _authRepository.switchCompany(companyId);
      await ServiceLocator.instance.tenantService.setTenantId(companyId);

      final database = ServiceLocator.instance.database;
      await database.clearAllData();

      // BUG FIX #1: Instead of calling _syncService.pull() directly,
      // go through _completeLogin which activates SyncEngine with the
      // correct credentials for the new company before syncing.
      await _completeLogin();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: _extractErrorMessage(e, 'Company switch failed'),
      );
    }
  }

  Future<void> refreshCompanies() async {
    if (state.status != AuthStatus.authenticated) return;
    try {
      final companies = await _authRepository.getMyCompanies();
      state = state.copyWith(companies: companies);
    } catch (e) {
      // Non-fatal
    }
  }

  Future<bool> createCompany({
    required String businessName,
    String? businessAddress,
    String? companyPhone,
    String? companyEmail,
  }) async {
    final prevState = state;
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _authRepository.createCompany({
        'businessName': businessName,
        'businessAddress': businessAddress,
        'companyPhone': companyPhone,
        'companyEmail': companyEmail,
      });

      state = prevState;
      await refreshCompanies();
      return true;
    } catch (e) {
      state = prevState.copyWith(
        errorMessage: _extractErrorMessage(e, 'Failed to create company'),
      );
      return false;
    }
  }

  Future<void> signup(Map<String, dynamic> data) async {
    state = AuthState.loading();
    try {
      await _authRepository.signup(data);
      await _completeLogin();
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, 'Signup failed'),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = AuthState.loading();
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = AuthState.unauthenticated();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null && googleAuth.accessToken == null) {
        throw Exception('Failed to retrieve Google Sign-In Tokens');
      }

      final response = await _authRepository.googleLogin(
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      if (response['requiresCompanySelection'] == true) {
        final companiesList = (response['companies'] as List)
            .map((c) => Company.fromJson(c))
            .toList();
        state = AuthState.companySelection(
          companies: companiesList,
          googleIdToken: idToken,
          googleAccessToken: googleAuth.accessToken,
        );
        return;
      }

      await _completeLogin();
    } catch (e) {
      if (e.toString().contains('canceled')) {
        state = AuthState.unauthenticated();
        return;
      }
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, 'Google Sign-In failed'),
      );
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    // Stop sync before clearing credentials so no in-flight request
    // tries to write after the token is gone.
    ServiceLocator.instance.syncEngine.stopAutoSync();
    await _authRepository.logout();
    await GoogleSignIn().signOut();
    state = AuthState.unauthenticated();
  }

  Future<void> forgotPassword(String email) async {
    state = AuthState.loading();
    try {
      await _authRepository.forgotPassword(email);
      state = AuthState.unauthenticated(
        'Password reset link sent to your email',
      );
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, 'Failed to send reset link'),
      );
    }
  }

  Future<void> resendVerificationEmail(String email) async {
    state = AuthState.loading();
    try {
      await _authRepository.resendVerificationEmail(email);
      state = AuthState.unauthenticated(
        'Verification email sent! Please check your inbox.',
      );
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, 'Failed to resend verification email'),
      );
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    state = AuthState.loading();
    try {
      await _authRepository.resetPassword(token, newPassword);
      state = AuthState.unauthenticated(
        'Password reset successfully. Please login.',
      );
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, 'Failed to reset password'),
      );
    }
  }

  Future<void> verifyEmail(String token) async {
    state = AuthState.loading();
    try {
      await _authRepository.verifyEmail(token);
      if (state.user != null) {
        await _completeLogin();
      } else {
        state = AuthState.unauthenticated(
          'Email verified successfully! Please login.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _extractErrorMessage(
          e,
          'Verification failed. The link may be expired or invalid.',
        ),
      );
    }
  }

  /// Complete login flow: decode JWT → set tenant → activate SyncEngine → sync.
  ///
  /// Order matters:
  ///   1. Fetch user/company from API (needs token, already in storage).
  ///   2. Decode JWT to get authoritative tenantId.
  ///   3. Persist tenantId via TenantService.
  ///   4. Activate SyncEngine with real IDs — this is the ONLY place
  ///      startAutoSync() is called (BUG FIX #1).
  ///   5. Fire one immediate pull in the background.
  ///   6. Set authenticated state.
  Future<void> _completeLogin() async {
    try {
      final response = await ServiceLocator.instance.authRemoteDataSource
          .getCurrentUser();
      print('DEBUG: getCurrentUser response = $response');

      final user = User.fromJson(response['employee'] ?? response);
      final company = response['company'] != null
          ? Company.fromJson(response['company'])
          : null;

      print('DEBUG: Parsed company.id = ${company?.id}');

      // Decode JWT for the authoritative tenantId
      final token = await ServiceLocator.instance.secureStorage
          .read(key: 'auth_token')
          .timeout(const Duration(seconds: 8));
      if (token == null) throw Exception('No auth token found');

      final jwtPayload = _decodeJwt(token);
      final tenantIdFromJwt = int.parse(jwtPayload['tenant_id'].toString());
      final companyIdFromJwt =
          company?.id ?? int.parse(jwtPayload['company_id']?.toString() ?? '0');

      print('DEBUG: tenantId from JWT = $tenantIdFromJwt');

      if (company != null &&
          company.tenantId != null &&
          company.tenantId != tenantIdFromJwt) {
        print(
          'DEBUG WARNING: Tenant mismatch - '
          'JWT=$tenantIdFromJwt, company=${company.tenantId}',
        );
      }

      if (company != null) {
        print(
          'DEBUG: ABOUT TO CALL setTenantId with tenantIdFromJwt=$tenantIdFromJwt',
        );
        await ServiceLocator.instance.tenantService.setTenantId(tenantIdFromJwt);
        print(
          'DEBUG: AFTER setTenantId, current tenantId='
          '${ServiceLocator.instance.tenantService.tenantId}',
        );

        // Persist company profile to local Tenants table so invoice
        // generation reads real data instead of template dummy fallbacks.
        await ServiceLocator.instance.database.upsertTenantFromCompany(
          tenantId: tenantIdFromJwt,
          name: company.businessName,
          email: company.email,
          phone: company.phone,
          businessAddress: company.businessAddress,
          taxId: company.taxId,
        );

        // BUG FIX #1: Activate SyncEngine HERE, with real credentials,
        // AFTER we have confirmed the user is authenticated and have a
        // valid tenantId and companyId. This replaces the old
        // startAutoSync() call in ServiceLocator.initialize().
        print(
          'DEBUG: Activating SyncEngine '
          '(tenantId=$tenantIdFromJwt, companyId=$companyIdFromJwt)',
        );
        await ServiceLocator.instance.activateSyncEngine(
          tenantId: tenantIdFromJwt,
          companyId: companyIdFromJwt,
        );
      } else {
        print('DEBUG WARNING: company is NULL — SyncEngine NOT activated');
      }

      // Fire one background pull immediately after activation.
      print('DEBUG: Scheduling background sync...');
      unawaited(_runPostLoginSync());

      final companies = await _authRepository.getMyCompanies();

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        company: company,
        companies: companies,
      );
    } catch (e) {
      print('_completeLogin FAILED: ${e.toString()}');
      if (e is DioException) {
        print('  status: ${e.response?.statusCode}');
        print('  body: ${e.response?.data}');
      }
      rethrow;
    }
  }

  bool _isRunningPostLoginSync = false;

  Future<void> _runPostLoginSync() async {
    if (_isRunningPostLoginSync) {
      print('DEBUG: Post-login sync already running — skipping');
      return;
    }

    _isRunningPostLoginSync = true;
    try {
      print(
        '[DIAG][${DateTime.now().toIso8601String()}] _runPostLoginSync: STARTING',
      );

      // syncNow() bypasses the 2-second debounce and awaits the full
      // push+pull cycle before returning, so the log below is accurate.
      final result = await ServiceLocator.instance.syncEngine.syncNow();

      print(
        '[DIAG][${DateTime.now().toIso8601String()}] _runPostLoginSync: COMPLETED '
        '(pulled=${result.pulled} pushed=${result.pushed} '
        'errors=${result.errors.length})',
      );
      if (result.errors.isNotEmpty) {
        print('[DIAG] Sync errors: ${result.errors}');
      }

      final productsResult = await ServiceLocator.instance.database
          .getAllProducts();
      print(
        '[DIAG][${DateTime.now().toIso8601String()}] '
        'Products in DB after sync: ${productsResult.length}',
      );
    } catch (e) {
      print(
        '[DIAG][${DateTime.now().toIso8601String()}] _runPostLoginSync: ERROR — $e',
      );
    } finally {
      _isRunningPostLoginSync = false;
    }
  }

  String _extractErrorMessage(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.response?.data is Map && e.response!.data['error'] != null) {
        return e.response!.data['error'].toString();
      }
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) return 'Session expired. Please log in again.';
      if (statusCode == 403) {
        return 'You do not have permission to perform this action.';
      }
      if (statusCode == 500) {
        return 'Internal server error. Please try again later.';
      }
      return e.message ?? fallback;
    }
    return '$fallback: ${e.toString()}';
  }
}

// BUG FIX #3: SyncService removed from provider constructor.
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ServiceLocator.instance.authRepository);
  },
);
