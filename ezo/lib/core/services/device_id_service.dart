import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'package:drift/drift.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  final AppDatabase _database;

  DeviceIdService(this._database);

  String? _cachedDeviceId;

  Future<String> getDeviceId() async {
    // 1) In-memory cache (fastest, survives hot reload via singleton)
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // 2) SharedPreferences (survives hot restart, not wiped by clearAllData)
    final prefs = await SharedPreferences.getInstance();
    final prefsDeviceId = prefs.getString(_deviceIdKey);
    if (prefsDeviceId != null && prefsDeviceId.isNotEmpty) {
      _cachedDeviceId = prefsDeviceId;
      return prefsDeviceId;
    }

    // 3) Drift syncMetadata table (may be wiped by clearAllData)
    String deviceId;
    try {
      final record = await (_database.select(
        _database.syncMetadata,
      )..where((t) => t.key.equals(_deviceIdKey))).getSingleOrNull();

      if (record == null || record.value == null) {
        deviceId = await _generateDeviceId();
      } else {
        deviceId = record.value!;
      }
    } catch (e) {
      deviceId = await _generateDeviceId();
    }

    // Persist in all three stores so the next lookup finds it
    _cachedDeviceId = deviceId;
    await prefs.setString(_deviceIdKey, deviceId);
    await _database
        .into(_database.syncMetadata)
        .insertOnConflictUpdate(
          SyncMetadataCompanion(
            key: const Value(_deviceIdKey),
            value: Value(deviceId),
            updatedAt: Value(DateTime.now()),
          ),
        );

    return deviceId;
  }

  Future<String> _generateDeviceId() async {
    try {
      String prefix;
      if (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows ||
          Platform.isLinux) {
        final hostname = Platform.localHostname;
        final cleaned = hostname.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        prefix = cleaned.isEmpty
            ? 'DEV'
            : cleaned.toUpperCase().substring(
                  0,
                  cleaned.length >= 4 ? 4 : cleaned.length,
                );
      } else {
        prefix = 'WEB';
      }

      final uuid = const Uuid();
      final suffix = uuid.v4().substring(0, 4).toUpperCase();

      return '$prefix$suffix';
    } catch (e) {
      final uuid = const Uuid();
      final suffix = uuid.v4().substring(0, 5).toUpperCase();
      return 'DEV$suffix';
    }
  }

  Future<void> resetDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    await (_database.delete(
      _database.syncMetadata,
    )..where((t) => t.key.equals(_deviceIdKey))).go();
    _cachedDeviceId = null;
  }
}