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
    print('DEBUG TenantService: initialize() STARTING');
    final storedIdStr = await _storage.read(key: 'tenant_id');
    print('DEBUG TenantService: initialize() storedIdStr=$storedIdStr');
    if (storedIdStr != null) {
      _tenantId = int.tryParse(storedIdStr);
      print('DEBUG TenantService: initialize() LOADED tenantId=$_tenantId');
    } else {
      print(
        'DEBUG TenantService: initialize() NO stored, tenantId remains null',
      );
    }
  }

  Future<void> setTenantId(int id) async {
    print(
      'DEBUG TenantService: setTenantId CALLED with id=$id (previous=$_tenantId)',
    );
    _tenantId = id;
    await _storage.write(key: 'tenant_id', value: id.toString());
    print('DEBUG TenantService: tenantId UPDATED to=$_tenantId');
  }
}
