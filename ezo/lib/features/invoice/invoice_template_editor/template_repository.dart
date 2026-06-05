import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/providers/tenant_provider.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'template_engine/invoice_template.dart';
import 'template_engine/template_registry.dart';

class InvoiceTemplateRepository {
  final AppDatabase _db;

  InvoiceTemplateRepository(this._db);

  final Map<int, Uint8List?> _logoBytesCache = {};

  void invalidateLogoCache(int companyId) {
    _logoBytesCache.remove(companyId);
  }

  Future<InvoiceTemplate> getSelectedTemplate(int companyId) async {
    final settings = await (_db.select(
      _db.invoiceSettings,
    )..where((t) => t.companyId.equals(companyId))).getSingleOrNull();

    if (settings == null) {
      return TemplateRegistry.getTemplateById('default_a4');
    }
    return TemplateRegistry.getTemplateById(settings.layout);
  }

  Stream<InvoiceTemplate> watchSelectedTemplate(int companyId) {
    return (_db.select(_db.invoiceSettings)
          ..where((t) => t.companyId.equals(companyId)))
        .watchSingleOrNull()
        .map((settings) {
          if (settings == null) {
            return TemplateRegistry.getTemplateById('default_a4');
          }
          return TemplateRegistry.getTemplateById(settings.layout);
        });
  }

  Future<void> saveTemplateSelection({
    required int companyId,
    required String templateId,
    String? accentColorHex,
    String? fontFamily,
    String? logoPath,
    String? logoLocalPath,
    Uint8List? logoBytes,
    int? thermalWidth,
    bool? showTaxBreakdown,
    bool? showLogo,
    bool? showAddress,
    bool? showCustomerDetails,
    bool? showFooter,
    String? customConfigJson,
    String? bankName,
    String? bankAccountNo,
    String? bankIfsc,
    String? upiId,
    bool? showBankDetails,
    bool? showUpiQr,
    String? invoicePrefix,
    String? taxLabel,
    double? taxRate,
    String? termsAndConditions,
    String? authorizedSignatory,
  }) async {
    final existing = await (_db.select(
      _db.invoiceSettings,
    )..where((t) => t.companyId.equals(companyId))).getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.invoiceSettings)
          .insert(
            InvoiceSettingsCompanion.insert(
              layout: templateId,
              footerMessage: const Value(''),
              accentColor: accentColorHex != null
                  ? Value(accentColorHex)
                  : const Value('#2196F3'),
              fontFamily: fontFamily != null
                  ? Value(fontFamily)
                  : const Value('Inter'),
              logoPath: logoPath != null
                  ? Value(logoPath)
                  : const Value.absent(),
              logoLocalPath: logoLocalPath != null
                  ? Value(logoLocalPath)
                  : const Value.absent(),
              thermalWidth: thermalWidth != null
                  ? Value(thermalWidth)
                  : const Value(80),
              showTaxBreakdown: showTaxBreakdown != null
                  ? Value(showTaxBreakdown)
                  : const Value(true),
              showLogo: showLogo != null ? Value(showLogo) : const Value(true),
              showAddress: showAddress != null
                  ? Value(showAddress)
                  : const Value(true),
              showCustomerDetails: showCustomerDetails != null
                  ? Value(showCustomerDetails)
                  : const Value(true),
              showFooter: showFooter != null
                  ? Value(showFooter)
                  : const Value(true),
              bankName: bankName != null
                  ? Value(bankName)
                  : const Value.absent(),
              bankAccountNo: bankAccountNo != null
                  ? Value(bankAccountNo)
                  : const Value.absent(),
              bankIfsc: bankIfsc != null
                  ? Value(bankIfsc)
                  : const Value.absent(),
              upiId: upiId != null
                  ? Value(upiId)
                  : const Value.absent(),
              showBankDetails: showBankDetails != null
                  ? Value(showBankDetails)
                  : const Value(false),
              showUpiQr: showUpiQr != null
                  ? Value(showUpiQr)
                  : const Value(false),
              invoicePrefix: invoicePrefix != null
                  ? Value(invoicePrefix)
                  : const Value('INV'),
              taxLabel: taxLabel != null ? Value(taxLabel) : const Value.absent(),
              taxRate: taxRate != null ? Value(taxRate) : const Value.absent(),
              termsAndConditions: termsAndConditions != null
                  ? Value(termsAndConditions)
                  : const Value.absent(),
              authorizedSignatory: authorizedSignatory != null
                  ? Value(authorizedSignatory)
                  : const Value.absent(),
              companyId: Value(companyId),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } else {
      await (_db.update(
        _db.invoiceSettings,
      )..where((t) => t.companyId.equals(companyId))).write(
        InvoiceSettingsCompanion(
          layout: Value(templateId),
          accentColor: accentColorHex != null
              ? Value(accentColorHex)
              : const Value.absent(),
          fontFamily: fontFamily != null
              ? Value(fontFamily)
              : const Value.absent(),
          logoPath: logoPath != null ? Value(logoPath) : const Value.absent(),
          logoLocalPath: logoLocalPath != null
              ? Value(logoLocalPath)
              : const Value.absent(),
          thermalWidth: thermalWidth != null
              ? Value(thermalWidth)
              : const Value.absent(),
          showTaxBreakdown: showTaxBreakdown != null
              ? Value(showTaxBreakdown)
              : const Value.absent(),
          showLogo: showLogo != null ? Value(showLogo) : const Value.absent(),
          showAddress: showAddress != null
              ? Value(showAddress)
              : const Value.absent(),
          showCustomerDetails: showCustomerDetails != null
              ? Value(showCustomerDetails)
              : const Value.absent(),
          showFooter: showFooter != null
              ? Value(showFooter)
              : const Value.absent(),
          bankName: bankName != null ? Value(bankName) : const Value.absent(),
          bankAccountNo: bankAccountNo != null
              ? Value(bankAccountNo)
              : const Value.absent(),
          bankIfsc: bankIfsc != null ? Value(bankIfsc) : const Value.absent(),
          upiId: upiId != null ? Value(upiId) : const Value.absent(),
          showBankDetails: showBankDetails != null
              ? Value(showBankDetails)
              : const Value.absent(),
          showUpiQr: showUpiQr != null
              ? Value(showUpiQr)
              : const Value.absent(),
          invoicePrefix: invoicePrefix != null
              ? Value(invoicePrefix)
              : const Value.absent(),
          taxLabel: taxLabel != null ? Value(taxLabel) : const Value.absent(),
          taxRate: taxRate != null ? Value(taxRate) : const Value.absent(),
          termsAndConditions: termsAndConditions != null
              ? Value(termsAndConditions)
              : const Value.absent(),
          authorizedSignatory: authorizedSignatory != null
              ? Value(authorizedSignatory)
              : const Value.absent(),
          customConfig: customConfigJson != null
              ? Value(customConfigJson)
              : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    if (logoLocalPath != null || logoBytes != null) {
      invalidateLogoCache(companyId);
    }
  }

  Future<({InvoiceData data, String templateId})> getHydratedInvoiceData(
    int companyId,
    String? templateId,
  ) async {
    // Fetch tenant + settings in parallel to halve the sequential DB latency.
    final results = await Future.wait([
      (_db.select(_db.tenants)..where((t) => t.id.equals(companyId)))
          .getSingleOrNull(),
      (_db.select(_db.invoiceSettings)
            ..where((t) => t.companyId.equals(companyId)))
          .getSingleOrNull(),
    ]);
    final tenant = results[0] as dynamic;
    final settings = results[1] as dynamic;

    final activeId = templateId ?? (settings?.layout as String?) ?? 'default_a4';
    final template = TemplateRegistry.getTemplateById(activeId);
    final defaultData = template.getDefaultData();

    // Zero out all data fields that come from the template's getDefaultData()
    // so that missing real values render as blank rather than fake text.
    // Design fields (themeColorArgb, fontFamily, isThermal, thermalWidth,
    // show* toggles) are intentionally left as template defaults until
    // overridden by invoice_settings below.
    defaultData.businessName = '';
    defaultData.businessAddress = '';
    defaultData.businessEmail = '';
    defaultData.businessPhone = '';
    defaultData.gstin = '';
    defaultData.taxLabel = '';
    defaultData.taxRate = 0.0;
    defaultData.termsAndConditions = '';
    defaultData.authorizedSignatory = '';
    defaultData.bankName = '';
    defaultData.bankAccountNo = '';
    defaultData.bankIfsc = '';
    defaultData.upiId = '';

    if (tenant != null) {
      defaultData.businessName = tenant.businessName ?? tenant.name;
      defaultData.businessAddress = tenant.businessAddress ?? '';
      defaultData.businessEmail = tenant.email ?? '';
      defaultData.businessPhone = tenant.phone ?? '';
      if (tenant.taxId != null) defaultData.gstin = tenant.taxId!;
    }

    if (settings != null) {
      if (settings.accentColor.startsWith('#')) {
        final hexColor = settings.accentColor.replaceAll('#', '0xFF');
        defaultData.themeColorArgb = Color(int.parse(hexColor)).toARGB32();
      }
      defaultData.fontFamily = settings.fontFamily;
      defaultData.logoLocalPath = settings.logoLocalPath;
      defaultData.logoPath = settings.logoPath;
      defaultData.thermalWidth = settings.thermalWidth;
      defaultData.showTaxBreakdown = settings.showTaxBreakdown;
      defaultData.showLogo = settings.showLogo;
      defaultData.showBusinessAddress = settings.showAddress;
      defaultData.showClientContact = settings.showCustomerDetails;
      defaultData.showNotes = settings.showFooter;
      defaultData.showBankDetails = settings.showBankDetails ?? false;
      defaultData.showUpiQr = settings.showUpiQr ?? false;
      defaultData.bankName = settings.bankName ?? '';
      defaultData.bankAccountNo = settings.bankAccountNo ?? '';
      defaultData.bankIfsc = settings.bankIfsc ?? '';
      defaultData.upiId = settings.upiId ?? '';
      if ((settings.taxLabel ?? '').isNotEmpty) {
        defaultData.taxLabel = settings.taxLabel!;
      }
      if ((settings.taxRate ?? 0.0) > 0) {
        defaultData.taxRate = settings.taxRate!;
      }
      if ((settings.termsAndConditions ?? '').isNotEmpty) {
        defaultData.termsAndConditions = settings.termsAndConditions!;
      }
      if ((settings.authorizedSignatory ?? '').isNotEmpty) {
        defaultData.authorizedSignatory = settings.authorizedSignatory!;
      }

      if (settings.showLogo) {
        final cached = _logoBytesCache[companyId];
        if (cached != null) {
          defaultData.logoBytes = cached;
        } else {
          Uint8List? storedBytes;

          // 1. File system — fast, non-blocking local read
          if (settings.logoLocalPath != null &&
              settings.logoLocalPath!.isNotEmpty) {
            try {
              final file = File(settings.logoLocalPath!);
              if (await file.exists()) {
                storedBytes = await file.readAsBytes();
              }
            } catch (_) {
              // File read failed — fall through to HTTP
            }
          }

          // 2. HTTP fallback — 500 ms cap for remote URL
          if (storedBytes == null &&
              settings.logoPath != null &&
              settings.logoPath!.isNotEmpty) {
            try {
              final response = await http
                  .get(Uri.parse(settings.logoPath!))
                  .timeout(const Duration(milliseconds: 500));
              if (response.statusCode == 200) {
                storedBytes = response.bodyBytes;
              }
            } catch (_) {
              // Logo fetch failed — PDF will be generated without logo
            }
          }

          if (storedBytes != null) {
            _logoBytesCache[companyId] = storedBytes;
            defaultData.logoBytes = storedBytes;
          }
        }
      }
    }

    return (data: defaultData, templateId: activeId);
  }

  void seedLogoCache(int companyId, Uint8List bytes) {
    _logoBytesCache[companyId] = bytes;
  }

}

final invoiceTemplateRepositoryProvider = Provider<InvoiceTemplateRepository>((
  ref,
) {
  return InvoiceTemplateRepository(ServiceLocator.instance.database);
});

final activeTemplateProvider = StreamProvider.autoDispose<InvoiceTemplate>((ref) {
  final repo = ref.watch(invoiceTemplateRepositoryProvider);
  final companyId = ref.watch(companyIdProvider);
  return repo.watchSelectedTemplate(companyId);
});
