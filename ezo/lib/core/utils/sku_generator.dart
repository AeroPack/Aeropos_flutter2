import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SkuGenerator {
  final List<String> _reservedSkus = [];
  final List<Map<String, dynamic>> _localReservations = [];

  /// Generate SKU using the existing database method
  Future<String> generateNextSku() async {
    final tenantId = await getCurrentTenantId();
    final db = ServiceLocator.instance.database;
    final deviceId = await _getDeviceId();

    if (_reservedSkus.isNotEmpty) {
      final sku = _reservedSkus.removeAt(0);
      _trackLocalUsage(sku);
      return sku;
    }

    try {
      final sku = await db.getNextSku(deviceId);
      _trackLocalUsage(sku);
      return sku;
    } catch (e) {
      return await _generateOfflineSku(tenantId);
    }
  }

  Future<String> _generateOfflineSku(int tenantId) async {
    final deviceId = await _getDeviceId();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    final sku = 'OFFLINE-$tenantId-$deviceId-$random';

    await _storeOfflineSku(sku);
    _trackLocalUsage(sku);

    return sku;
  }

  void _trackLocalUsage(String sku) {
    _localReservations.add({
      'sku': sku,
      'usedAt': DateTime.now().toIso8601String(),
      'synced': false,
    });
    _saveLocalReservations();
  }

  Future<void> _storeOfflineSku(String sku) async {
    final prefs = await SharedPreferences.getInstance();
    final offlineSkus = prefs.getStringList('offline_skus') ?? [];
    offlineSkus.add(sku);
    await prefs.setStringList('offline_skus', offlineSkus);
  }

  Future<void> _saveLocalReservations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_reservations', jsonEncode(_localReservations));
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = const Uuid().v4().substring(0, 8);
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }

  Future<int> getCurrentTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tenant_id') ?? 1;
  }

  Future<bool> hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  Future<void> syncOfflineSkus() async {
    final prefs = await SharedPreferences.getInstance();
    final offlineSkus = prefs.getStringList('offline_skus');

    if (offlineSkus == null || offlineSkus.isEmpty) return;

    await prefs.remove('offline_skus');
  }
}
