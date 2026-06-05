import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:excel/excel.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:uuid/uuid.dart';

class CustomerExcelImportService {
  final _uuid = const Uuid();

  AppDatabase get _database => ServiceLocator.instance.database;

  Future<List<CustomerExcelImportRow>> parseExcelFileData(
    List<int>? bytes,
    File? file,
  ) async {
    List<int> fileBytes;
    if (bytes != null) {
      fileBytes = bytes;
    } else if (file != null) {
      fileBytes = await file.readAsBytes();
    } else {
      return [];
    }

    final excel = Excel.decodeBytes(fileBytes);

    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    final rows = sheet?.rows ?? [];

    if (rows.isEmpty) return [];

    final headerRow = rows.first;
    final headers = headerRow
        .map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '')
        .toList();

    final List<CustomerExcelImportRow> importRows = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && row[0]?.value == null)) continue;

      final Map<String, String> data = <String, String>{};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        if (headers[j].isNotEmpty && row[j]?.value != null) {
          data[headers[j]] = row[j]!.value.toString().trim();
        }
      }

      if (data.isEmpty) continue;

      final validation = _validateRow(data, i + 1);
      importRows.add(
        CustomerExcelImportRow(
          rowNumber: i + 1,
          data: data,
          isValid: validation.isValid,
          errorMessage: validation.errorMessage,
        ),
      );
    }

    return importRows;
  }

  RowValidation _validateRow(Map<String, String> data, int rowNumber) {
    if (!data.containsKey('name') || data['name']!.isEmpty) {
      return RowValidation(false, 'Row $rowNumber: Name is required');
    }

    if (!data.containsKey('phone') || data['phone']!.isEmpty) {
      return RowValidation(false, 'Row $rowNumber: Phone is required');
    }

    if (data.containsKey('credit_limit') && data['credit_limit']!.isNotEmpty) {
      final creditLimit = double.tryParse(data['credit_limit']!);
      if (creditLimit == null || creditLimit < 0) {
        return RowValidation(
          false,
          'Row $rowNumber: Invalid credit limit value',
        );
      }
    }

    if (data.containsKey('current_balance') &&
        data['current_balance']!.isNotEmpty) {
      final currentBalance = double.tryParse(data['current_balance']!);
      if (currentBalance == null || currentBalance < 0) {
        return RowValidation(
          false,
          'Row $rowNumber: Invalid current balance value',
        );
      }
    }

    return RowValidation(true, null);
  }

  Future<ImportResult> importCustomers(
    List<CustomerExcelImportRow> rows,
  ) async {
    int created = 0;
    int updated = 0;
    int skipped = 0;
    final List<String> errors = [];

    for (final row in rows) {
      if (!row.isValid) {
        skipped++;
        errors.add(row.errorMessage ?? 'Unknown error');
        continue;
      }

      try {
        final data = row.data;
        final phone = data['phone']?.trim();

        if (phone == null || phone.isEmpty) {
          skipped++;
          errors.add('Row ${row.rowNumber}: Phone is required');
          continue;
        }

        final existingCustomer =
            await (_database.select(_database.customers)..where(
                  (t) => t.phone.equals(phone) & t.isDeleted.equals(false),
                ))
                .getSingleOrNull();

        final name = data['name']!.trim();
        final email = data['email']?.trim();
        final address = data['address']?.trim();
        final creditLimit =
            data['credit_limit']?.trim() != null &&
                data['credit_limit']!.isNotEmpty
            ? double.parse(data['credit_limit']!)
            : 0.0;
        final currentBalance =
            data['current_balance']?.trim() != null &&
                data['current_balance']!.isNotEmpty
            ? double.parse(data['current_balance']!)
            : 0.0;

        if (existingCustomer != null) {
          await (_database.update(
            _database.customers,
          )..where((t) => t.id.equals(existingCustomer.id))).write(
            CustomersCompanion(
              name: Value(name),
              phone: Value(phone),
              email: email != null && email.isNotEmpty
                  ? Value(email)
                  : const Value.absent(),
              address: address != null && address.isNotEmpty
                  ? Value(address)
                  : const Value.absent(),
              creditLimit: Value(creditLimit),
              currentBalance: Value(currentBalance),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(1),
            ),
          );
          updated++;
        } else {
          await _database
              .into(_database.customers)
              .insert(
                CustomersCompanion(
                  uuid: Value(_uuid.v4()),
                  name: Value(name),
                  phone: Value(phone),
                  email: email != null && email.isNotEmpty
                      ? Value(email)
                      : const Value.absent(),
                  address: address != null && address.isNotEmpty
                      ? Value(address)
                      : const Value.absent(),
                  creditLimit: Value(creditLimit),
                  currentBalance: Value(currentBalance),
                  companyId: Value(ServiceLocator.instance.sessionService.companyId),
                  syncStatus: const Value(1),
                  isDeleted: const Value(false),
                  createdAt: Value(DateTime.now()),
                  updatedAt: Value(DateTime.now()),
                ),
              );
          created++;
        }
      } catch (e) {
        skipped++;
        errors.add('Row ${row.rowNumber}: ${e.toString()}');
      }
    }

    return ImportResult(
      created: created,
      updated: updated,
      skipped: skipped,
      errors: errors,
    );
  }

  List<String> get templateHeaders => [
    'name',
    'phone',
    'email',
    'address',
    'credit_limit',
    'current_balance',
  ];

  List<String> get sampleData => [
    'John Doe',
    '9876543210',
    'john@example.com',
    '123 Main Street, City',
    '10000',
    '0',
  ];
}

class CustomerExcelImportRow {
  final int rowNumber;
  final Map<String, String> data;
  final bool isValid;
  final String? errorMessage;

  CustomerExcelImportRow({
    required this.rowNumber,
    required this.data,
    required this.isValid,
    this.errorMessage,
  });
}

class RowValidation {
  final bool isValid;
  final String? errorMessage;

  RowValidation(this.isValid, this.errorMessage);
}

class ImportResult {
  final int created;
  final int updated;
  final int skipped;
  final List<String> errors;

  ImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.errors,
  });
}
