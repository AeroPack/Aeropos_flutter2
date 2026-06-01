import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TenantService {
  final FlutterSecureStorage _storage;
  int? _tenantId; // null = not initialized

  TenantService(this._storage);

  /// Nullable getter for UI / conditional logic
  int? get tenantIdOrNull => _tenantId;

  /// Strict getter for network layer - throws if not initialized
  int get tenantId {
    if (_tenantId == null) {
      throw Exception('Tenant not initialized - user must login first');
    }
    return _tenantId!;
  }

  Future<void> initialize() async {
    debugPrint('DEBUG TenantService: initialize() STARTING');
    final storedIdStr = await _storage.read(key: 'tenant_id');
    debugPrint('DEBUG TenantService: initialize() storedIdStr=$storedIdStr');
    if (storedIdStr != null) {
      _tenantId = int.tryParse(storedIdStr);
      debugPrint('DEBUG TenantService: initialize() LOADED tenantId=$_tenantId');
    } else {
      debugPrint(
        'DEBUG TenantService: initialize() NO stored, tenantId remains null',
      );
    }
  }

  Future<void> setTenantId(int id) async {
    debugPrint(
      'DEBUG TenantService: setTenantId CALLED with id=$id (previous=$_tenantId)',
    );
    _tenantId = id;
    await _storage.write(key: 'tenant_id', value: id.toString());
    debugPrint('DEBUG TenantService: tenantId UPDATED to=$_tenantId');
  }
}
