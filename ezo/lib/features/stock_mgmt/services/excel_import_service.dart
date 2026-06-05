import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:excel/excel.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:uuid/uuid.dart';

class ExcelImportService {
  final _uuid = const Uuid();

  AppDatabase get _database => ServiceLocator.instance.database;

  Map<String, int> _categoryNameToId = {};
  Map<String, int> _unitNameToId = {};
  Map<String, int> _brandNameToId = {};

  Future<void> _loadLookups() async {
    final categories = await _database.select(_database.categories).get();
    _categoryNameToId = {for (var c in categories) c.name.toLowerCase(): c.id};

    final units = await _database.select(_database.units).get();
    _unitNameToId = {for (var u in units) u.name.toLowerCase(): u.id};

    final brands = await _database.select(_database.brands).get();
    _brandNameToId = {for (var b in brands) b.name.toLowerCase(): b.id};
  }

  Future<List<ExcelImportRow>> parseExcelFile(File file) async {
    return parseExcelFileData(null, file);
  }

  Future<List<ExcelImportRow>> parseExcelFileData(
    List<int>? bytes,
    File? file,
  ) async {
    await _loadLookups();

    // Get bytes from either source
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

    // First row is header
    final headerRow = rows.first;
    final headers = headerRow
        .map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '')
        .toList();

    final List<ExcelImportRow> importRows = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && row[0]?.value == null)) continue;

      final Map<String, String> data = {};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        if (headers[j].isNotEmpty && row[j]?.value != null) {
          data[headers[j]] = row[j]!.value.toString().trim();
        }
      }

      if (data.isEmpty) continue;

      final validation = _validateRow(data, i + 1);
      importRows.add(
        ExcelImportRow(
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
      return RowValidation(false, 'Row $rowNumber: Product name is required');
    }

    if (!data.containsKey('price') || data['price']!.isEmpty) {
      return RowValidation(false, 'Row $rowNumber: Price is required');
    }

    final price = double.tryParse(data['price']!);
    if (price == null || price < 0) {
      return RowValidation(false, 'Row $rowNumber: Invalid price value');
    }

    if (data.containsKey('stock_quantity') &&
        data['stock_quantity']!.isNotEmpty) {
      final stock = int.tryParse(data['stock_quantity']!);
      if (stock == null || stock < 0) {
        return RowValidation(false, 'Row $rowNumber: Invalid stock quantity');
      }
    }

    if (data.containsKey('cost') && data['cost']!.isNotEmpty) {
      final cost = double.tryParse(data['cost']!);
      if (cost == null || cost < 0) {
        return RowValidation(false, 'Row $rowNumber: Invalid cost value');
      }
    }

    if (data.containsKey('gst_rate') && data['gst_rate']!.isNotEmpty) {
      final gstRate = double.tryParse(data['gst_rate']!);
      if (gstRate == null || gstRate < 0 || gstRate > 100) {
        return RowValidation(false, 'Row $rowNumber: Invalid GST rate (0-100)');
      }
    }

    return RowValidation(true, null);
  }

  Future<ImportResult> importProducts(List<ExcelImportRow> rows) async {
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
        final sku = data['sku']?.isNotEmpty == true ? data['sku'] : null;

        // Check if product exists by SKU or name
        ProductEntity? existingProduct;

        if (sku != null) {
          final bySku =
              await (_database.select(_database.products)..where(
                    (t) => t.sku.equals(sku) & t.isDeleted.equals(false),
                  ))
                  .getSingleOrNull();
          existingProduct = bySku;
        }

        if (existingProduct == null && data['name'] != null) {
          final byName =
              await (_database.select(_database.products)..where(
                    (t) =>
                        t.name.equals(data['name']!) &
                        t.isDeleted.equals(false),
                  ))
                  .getSingleOrNull();
          existingProduct = byName;
        }

        final categoryId = data['category_name'] != null
            ? _categoryNameToId[data['category_name']!.toLowerCase()]
            : null;
        final unitId = data['unit_name'] != null
            ? _unitNameToId[data['unit_name']!.toLowerCase()]
            : null;
        final brandId = data['brand_name'] != null
            ? _brandNameToId[data['brand_name']!.toLowerCase()]
            : null;

        if (existingProduct != null) {
          // Update existing product
          await (_database.update(
            _database.products,
          )..where((t) => t.id.equals(existingProduct!.id))).write(
            ProductsCompanion(
              name: Value(data['name']!),
              sku: sku != null ? Value(sku) : const Value.absent(),
              price: Value(double.parse(data['price']!)),
              cost: data['cost'] != null
                  ? Value(double.parse(data['cost']!))
                  : const Value.absent(),
              stockQuantity: data['stock_quantity'] != null
                  ? Value(int.parse(data['stock_quantity']!))
                  : const Value.absent(),
              categoryId: categoryId != null
                  ? Value(categoryId)
                  : const Value.absent(),
              unitId: unitId != null ? Value(unitId) : const Value.absent(),
              brandId: brandId != null ? Value(brandId) : const Value.absent(),
              gstType: data['gst_type'] != null
                  ? Value(data['gst_type'])
                  : const Value.absent(),
              gstRate: data['gst_rate'] != null
                  ? Value(data['gst_rate'])
                  : const Value.absent(),
              description: data['description'] != null
                  ? Value(data['description'])
                  : const Value.absent(),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(1),
            ),
          );
          updated++;
        } else {
          // Create new product
          await _database
              .into(_database.products)
              .insert(
                ProductsCompanion(
                  uuid: Value(_uuid.v4()),
                  name: Value(data['name']!),
                  sku: sku != null ? Value(sku) : const Value.absent(),
                  price: Value(double.parse(data['price']!)),
                  cost: data['cost'] != null
                      ? Value(double.parse(data['cost']!))
                      : const Value.absent(),
                  stockQuantity: data['stock_quantity'] != null
                      ? Value(int.parse(data['stock_quantity']!))
                      : const Value(0),
                  categoryId: categoryId != null
                      ? Value(categoryId)
                      : const Value.absent(),
                  unitId: unitId != null ? Value(unitId) : const Value.absent(),
                  brandId: brandId != null
                      ? Value(brandId)
                      : const Value.absent(),
                  gstType: data['gst_type'] != null
                      ? Value(data['gst_type'])
                      : const Value.absent(),
                  gstRate: data['gst_rate'] != null
                      ? Value(data['gst_rate'])
                      : const Value.absent(),
                  description: data['description'] != null
                      ? Value(data['description'])
                      : const Value.absent(),
                  isActive: const Value(true),
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

  List<List<dynamic>> getTemplateHeaders() {
    return [
      [
        'name',
        'sku',
        'price',
        'cost',
        'stock_quantity',
        'category_name',
        'unit_name',
        'brand_name',
        'gst_type',
        'gst_rate',
        'description',
      ],
      [
        'Sample Product',
        'SKU001',
        '99.99',
        '49.99',
        '100',
        'General',
        'Piece',
        '',
        'GST',
        '18',
        'Sample product description',
      ],
    ];
  }

  List<String> get templateHeaders => [
    'name',
    'sku',
    'price',
    'cost',
    'stock_quantity',
    'category_name',
    'unit_name',
    'brand_name',
    'gst_type',
    'gst_rate',
    'description',
  ];

  List<String> get sampleData => [
    'Sample Product',
    'SKU001',
    '99.99',
    '49.99',
    '100',
    'General',
    'Piece',
    '',
    'GST',
    '18',
    'Sample product description',
  ];
}

class ExcelImportRow {
  final int rowNumber;
  final Map<String, String> data;
  final bool isValid;
  final String? errorMessage;

  ExcelImportRow({
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
