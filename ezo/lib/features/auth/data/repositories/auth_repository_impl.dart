import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/models/user.dart';
import '../../../../core/models/company.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final FlutterSecureStorage _storage;
  final AppDatabase _database;

  AuthRepositoryImpl(this._remoteDataSource, this._storage, this._database);

  @override
  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    int? companyId,
  }) async {
    final response = await _remoteDataSource.login(
      email,
      password,
      companyId: companyId,
    );
    // Only store token if login is complete (not company selection)
    final token = response['token'];
    print(
      'DEBUG [AuthRepository] Login response token: ${token != null ? "${token.substring(0, 20)}..." : "NULL"}',
    );
    if (token != null) {
      print('[AUTH][STORE] Writing auth_token, storage hashCode: ${_storage.hashCode}');
      await _storage.write(key: 'auth_token', value: token);
      print('[AUTH][STORE] Verified read-back: ${await _storage.read(key: 'auth_token') != null}');
      print('DEBUG [AuthRepository] Token written to storage');

      // Store company.id for X-Company-Id header
      final company = response['company'] as Map<String, dynamic>?;
      if (company != null) {
        final companyId = company['id']?.toString();
        if (companyId != null) {
          await _storage.write(key: 'company_id', value: companyId);
          print('DEBUG [AuthRepository] Company ID written to storage: $companyId');
        }
      }
    }
    return response;
  }

  @override
  Future<void> signup(Map<String, dynamic> data) async {
    final response = await _remoteDataSource.signup(data);
    final token = response['token'];
    if (token != null) {
      await _storage.write(key: 'auth_token', value: token);
    }
  }

  @override
  Future<Map<String, dynamic>> googleLogin({
    String? idToken,
    String? accessToken,
    int? companyId,
  }) async {
    final response = await _remoteDataSource.googleLogin(
      idToken: idToken,
      accessToken: accessToken,
      companyId: companyId,
    );
    final token = response['token'];
    if (token != null) {
      await _storage.write(key: 'auth_token', value: token);
      final company = response['company'] as Map<String, dynamic>?;
      if (company != null) {
        final cid = company['id']?.toString();
        if (cid != null) {
          await _storage.write(key: 'company_id', value: cid);
        }
      }
    }
    return response;
  }

  @override
  Future<void> logout() async {
    try {
      final hasPending =
          await (_database.select(_database.products)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();

      if (hasPending.isNotEmpty) {
        // Warning: Data will be lost.
      }
    } catch (e) {
      // ignored
    }

    await _database.clearAllData();
    await _storage.delete(key: 'auth_token');
  }

  @override
  Future<bool> checkAuthStatus() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final responseMap = await _remoteDataSource.getCurrentUser();
      if (responseMap.containsKey('employee')) {
        return User.fromJson(responseMap['employee']);
      }
      return User.fromJson(responseMap);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> verifyEmail(String token) async {
    await _remoteDataSource.verifyEmail(token);
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _remoteDataSource.forgotPassword(email);
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    await _remoteDataSource.resetPassword(token, newPassword);
  }

  @override
  Future<void> resendVerificationEmail(String email) async {
    await _remoteDataSource.resendVerificationEmail(email);
  }

  @override
  Future<List<Company>> getMyCompanies() async {
    final response = await _remoteDataSource.getMyCompanies();
    final List<dynamic> companiesJson = response['companies'] ?? [];
    return companiesJson.map((c) => Company.fromJson(c)).toList();
  }

  @override
  Future<Map<String, dynamic>> createCompany(Map<String, dynamic> data) async {
    return await _remoteDataSource.createCompany(data);
  }

  @override
  Future<Map<String, dynamic>> switchCompany(int companyId) async {
    final response = await _remoteDataSource.switchCompany(companyId);
    final token = response['token'];
    if (token != null) {
      await _storage.write(key: 'auth_token', value: token);
      // Update company_id so the X-Company-Id header reflects the new company.
      await _storage.write(key: 'company_id', value: companyId.toString());
    }
    return response;
  }
}
