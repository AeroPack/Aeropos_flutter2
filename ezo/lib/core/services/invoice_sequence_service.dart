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

      // Source of truth is the invoices table, not the stored counter.
      // The stored counter drifts below reality whenever invoices arrive
      // without advancing it (sync pull from another device, restore), which
      // makes a plain counter+1 re-issue a used number and trip the
      // UNIQUE(invoice_number, company_id) constraint at insert time.
      final dbMaxCounter = await _maxCounterForToday(
        companyId: companyId,
        prefix: prefix,
        code: code,
        todayTag: todayTag,
      );

      // The stored counter still matters: it reserves numbers already handed
      // out this session whose invoice rows have not been committed yet
      // (e.g. two rapid checkouts), which the table max cannot see.
      final storedCounter =
          (settings != null && _dateTag(settings.updatedAt) == todayTag)
              ? settings.invoiceCounter
              : 0;

      final nextCounter =
          (storedCounter > dbMaxCounter ? storedCounter : dbMaxCounter) + 1;

      if (settings == null) {
        await _db.into(_db.invoiceSettings).insert(
              InvoiceSettingsCompanion(
                companyId: Value(companyId),
                layout: const Value('thermal'),
                invoiceCounter: Value(nextCounter),
                invoicePrefix: const Value('INV'),
                deviceCode: const Value('A'),
                updatedAt: Value(now),
              ),
            );
      } else {
        final companion = settings.toCompanion(true).copyWith(
          invoiceCounter: Value(nextCounter),
          updatedAt: Value(now),
        );
        await _db.upsertInvoiceSettings(companion);
      }

      return '$prefix-$code$todayTag-${nextCounter.toString().padLeft(4, '0')}';
    });
  }

  /// Highest trailing counter among invoices already stored for today's tag.
  /// Includes soft-deleted rows: a soft delete keeps the row, so its number
  /// still occupies the UNIQUE(invoice_number, company_id) slot.
  Future<int> _maxCounterForToday({
    required int companyId,
    required String prefix,
    required String code,
    required String todayTag,
  }) async {
    final pattern = '$prefix-$code$todayTag-%';
    final invoices = await (_db.select(_db.invoices)
          ..where((t) =>
              t.companyId.equals(companyId) & t.invoiceNumber.like(pattern)))
        .get();

    var maxCounter = 0;
    for (final inv in invoices) {
      final dash = inv.invoiceNumber.lastIndexOf('-');
      if (dash == -1) continue;
      final parsed = int.tryParse(inv.invoiceNumber.substring(dash + 1));
      if (parsed != null && parsed > maxCounter) maxCounter = parsed;
    }
    return maxCounter;
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
