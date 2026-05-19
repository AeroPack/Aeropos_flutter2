import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../di/service_locator.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;

  AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // On Linux, libsecret can deadlock if the GNOME keyring is locked.
      // Use a short timeout so requests are never silently blocked.
      final token = await _storage
          .read(key: 'auth_token')
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }

      // 2. Company ID header (from stored company.id)
      final companyId = await _storage
          .read(key: 'company_id')
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (companyId != null) {
        options.headers['X-Company-Id'] = companyId;
      }

      // 3. Tenant ID header (from tenant service)
      final tenantId = ServiceLocator.instance.tenantService.tenantIdOrNull;
      if (tenantId != null) {
        options.headers['X-Tenant-Id'] = tenantId.toString();
      }

      handler.next(options);
    } catch (e) {
      // Never block the request — let it proceed even if storage errors out.
      handler.next(options);
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Clear token on 401 Unauthorized
      await _storage.delete(key: 'auth_token');
    }
    super.onError(err, handler);
  }
}
