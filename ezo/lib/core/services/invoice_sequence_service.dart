import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../di/service_locator.dart';

class InvoiceSequenceService {
  final AppDatabase _db;

  InvoiceSequenceService() : _db = ServiceLocator.instance.database;

  String _dateTag(DateTime dt) {
    final y = dt.year.toString().substring(2);
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Future<String> getNextInvoiceNumber(int companyId) async {
    return _db.transaction(() async {
      final settings = await (_db.select(_db.invoiceSettings)
        ..where((t) => t.companyId.equals(companyId)))
          .getSingleOrNull();

      final now = DateTime.now();
      final todayTag = _dateTag(now);

      final prefix = settings?.invoicePrefix ?? 'INV';
      final code = settings?.deviceCode ?? 'A';

      if (settings == null) {
        final companion = InvoiceSettingsCompanion(
          companyId: Value(companyId),
          layout: const Value('thermal'),
          invoiceCounter: const Value(1),
          invoicePrefix: const Value('INV'),
          deviceCode: const Value('A'),
          updatedAt: Value(now),
        );
        await _db.into(_db.invoiceSettings).insert(companion);
        return '$prefix-$code$todayTag-0001';
      }

      final lastDate = settings.updatedAt;
      final nextCounter = (_dateTag(lastDate) == todayTag)
          ? settings.invoiceCounter + 1
          : 1;

      final companion = settings.toCompanion(true).copyWith(
        invoiceCounter: Value(nextCounter),
        updatedAt: Value(now),
      );
      await _db.upsertInvoiceSettings(companion);

      return '$prefix-$code$todayTag-${nextCounter.toString().padLeft(4, '0')}';
    });
  }

  Future<String> regenerateOnConflict(int companyId, String currentNumber) async {
    final settings = await (_db.select(_db.invoiceSettings)
      ..where((t) => t.companyId.equals(companyId)))
        .getSingleOrNull();

    final now = DateTime.now();
    final todayTag = _dateTag(now);
    final prefix = settings?.invoicePrefix ?? 'INV';
    final code = settings?.deviceCode ?? 'A';

    final nextCounter = (settings != null) ? settings.invoiceCounter + 1 : 1;

    if (settings != null) {
      final companion = settings.toCompanion(true).copyWith(
        invoiceCounter: Value(nextCounter),
        updatedAt: Value(now),
      );
      await _db.upsertInvoiceSettings(companion);
    }

    return '$prefix-$code$todayTag-${nextCounter.toString().padLeft(4, '0')}';
  }

  Future<int> getCurrentCounter(int companyId) async {
    final settings = await (_db.select(_db.invoiceSettings)
      ..where((t) => t.companyId.equals(companyId)))
        .getSingleOrNull();
    return settings?.invoiceCounter ?? 0;
  }

  Future<void> resetCounter(int companyId) async {
    final settings = await (_db.select(_db.invoiceSettings)
      ..where((t) => t.companyId.equals(companyId)))
        .getSingleOrNull();
    if (settings != null) {
      final companion = settings.toCompanion(true).copyWith(
        invoiceCounter: const Value(0),
        updatedAt: Value(DateTime.now()),
      );
      await _db.upsertInvoiceSettings(companion);
    }
  }
}
