import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  final FlutterSecureStorage _storage;
  int? _companyId; // null = not initialized

  SessionService(this._storage);

  /// Nullable getter for UI / conditional logic
  int? get companyIdOrNull => _companyId;

  /// Strict getter for network layer - throws if not initialized
  int get companyId {
    if (_companyId == null) {
      throw Exception('Session not initialized - user must login first');
    }
    return _companyId!;
  }

  Future<void> initialize() async {
    debugPrint('DEBUG SessionService: initialize() STARTING');
    final storedIdStr = await _storage.read(key: 'company_id');
    debugPrint('DEBUG SessionService: initialize() storedIdStr=$storedIdStr');
    if (storedIdStr != null) {
      _companyId = int.tryParse(storedIdStr);
      debugPrint('DEBUG SessionService: initialize() LOADED companyId=$_companyId');
    } else {
      debugPrint(
        'DEBUG SessionService: initialize() NO stored, companyId remains null',
      );
    }
  }

  Future<void> setCompanyId(int id) async {
    debugPrint(
      'DEBUG SessionService: setCompanyId CALLED with id=$id (previous=$_companyId)',
    );
    _companyId = id;
    await _storage.write(key: 'company_id', value: id.toString());
    debugPrint('DEBUG SessionService: companyId UPDATED to=$_companyId');
  }
}
