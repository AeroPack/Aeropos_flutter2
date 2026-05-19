import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../di/service_locator.dart';

class InvoiceSequenceService {
  final AppDatabase _db;

  InvoiceSequenceService() : _db = ServiceLocator.instance.database;

  Future<String> getNextInvoiceNumber(int tenantId) async {
    return _db.transaction(() async {
      final settings = await (_db.select(_db.invoiceSettings)
        ..where((t) => t.tenantId.equals(tenantId)))
          .getSingleOrNull();

      if (settings == null) {
        return 'INV-0001';
      }

      final currentYear = DateTime.now().year;
      final nextNumber = settings.invoiceCounter + 1;

      final companion = settings.toCompanion(true).copyWith(
        invoiceCounter: Value(nextNumber),
        updatedAt: Value(DateTime.now()),
      );
      await _db.upsertInvoiceSettings(companion);

      return 'INV-$currentYear-${nextNumber.toString().padLeft(5, '0')}';
    });
  }

  Future<int> getCurrentCounter(int tenantId) async {
    final settings = await (_db.select(_db.invoiceSettings)
      ..where((t) => t.tenantId.equals(tenantId)))
        .getSingleOrNull();
    return settings?.invoiceCounter ?? 0;
  }

  Future<void> resetCounter(int tenantId) async {
    final settings = await (_db.select(_db.invoiceSettings)
      ..where((t) => t.tenantId.equals(tenantId)))
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
