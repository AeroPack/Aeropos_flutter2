import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../di/service_locator.dart';
import '../providers/tenant_provider.dart';
import '../../features/invoice/invoice_template_editor/template_repository.dart';

enum InvoiceLayout {
  thermal,
  modern,
  classic,
  luxury,
  stylish,
  advancedGst,
  simple,
  dreams,
  custom,
}

class InvoiceTemplate {
  final InvoiceLayout layout;
  final String footerMessage;

  // Customization
  final String accentColor;
  final String fontFamily;
  final double fontSizeMultiplier;

  // Toggles
  final bool showAddress;
  final bool showCustomerDetails;
  final bool showFooter;
  final bool showLogo;

  // Custom Template Configuration
  final String? customConfig;

  InvoiceTemplate({
    this.layout = InvoiceLayout.thermal,
    this.footerMessage = "Thank you for shopping with Ezo POS!",
    this.accentColor = '#2A2D64',
    this.fontFamily = 'Roboto',
    this.fontSizeMultiplier = 1.0,
    this.showAddress = true,
    this.showCustomerDetails = true,
    this.showFooter = true,
    this.showLogo = true,
    this.customConfig,
  });

  factory InvoiceTemplate.defaults() {
    return InvoiceTemplate();
  }

  factory InvoiceTemplate.fromEntity(InvoiceSettingEntity entity) {
    return InvoiceTemplate(
      layout: InvoiceLayout.values.firstWhere(
        (e) => e.name == entity.layout,
        orElse: () => InvoiceLayout.thermal,
      ),
      footerMessage: entity.footerMessage,
      accentColor: entity.accentColor,
      fontFamily: entity.fontFamily,
      fontSizeMultiplier: entity.fontSizeMultiplier,
      showAddress: entity.showAddress,
      showCustomerDetails: entity.showCustomerDetails,
      showFooter: entity.showFooter,
      showLogo: entity.showLogo,
      customConfig: entity.customConfig,
    );
  }
}

class InvoiceTemplateNotifier extends Notifier<InvoiceTemplate> {
  late final AppDatabase _db;

  @override
  InvoiceTemplate build() {
    _db = ServiceLocator.instance.database;
    _loadFromDb();
    return InvoiceTemplate.defaults();
  }

  Future<void> _loadFromDb() async {
    final tenantId = ref.read(tenantIdProvider);
    final entity = await _db.getInvoiceSettingsForTenant(tenantId);
    if (entity != null) {
      state = InvoiceTemplate.fromEntity(entity);
    }
  }

  Future<void> updateTemplate({
    InvoiceLayout? layout,
    String? footerMessage,
    String? accentColor,
    String? fontFamily,
    double? fontSizeMultiplier,
    bool? showAddress,
    bool? showCustomerDetails,
    bool? showFooter,
    String? customConfig,
  }) async {
    final newState = InvoiceTemplate(
      layout: layout ?? state.layout,
      footerMessage: footerMessage ?? state.footerMessage,
      accentColor: accentColor ?? state.accentColor,
      fontFamily: fontFamily ?? state.fontFamily,
      fontSizeMultiplier: fontSizeMultiplier ?? state.fontSizeMultiplier,
      showAddress: showAddress ?? state.showAddress,
      showCustomerDetails: showCustomerDetails ?? state.showCustomerDetails,
      showFooter: showFooter ?? state.showFooter,
      customConfig: customConfig ?? state.customConfig,
    );

    state = newState;

    final tenantId = ref.read(tenantIdProvider);
    final repo = ref.read(invoiceTemplateRepositoryProvider);

    await repo.saveTemplateSelection(
      tenantId: tenantId,
      templateId: newState.layout.name,
      accentColorHex: newState.accentColor,
      fontFamily: newState.fontFamily,
      logoPath: null,
      thermalWidth: null,
      showTaxBreakdown: null,
    );
  }
}

final invoiceTemplateProvider =
    NotifierProvider<InvoiceTemplateNotifier, InvoiceTemplate>(
      InvoiceTemplateNotifier.new,
    );
