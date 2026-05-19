import 'package:pdf/widgets.dart' as pw;
import '../../features/sales/templates/thermal_layout.dart';
import '../../features/sales/templates/modern_layout.dart';
import '../../features/sales/templates/classic_layout.dart';
import '../../features/sales/templates/luxury_layout.dart';
import '../../features/sales/templates/stylish_layout.dart';
import '../../features/sales/templates/simple_layout.dart';
import '../../features/sales/templates/advanced_gst_layout.dart';
import '../../features/sales/templates/dreams_layout.dart';
import '../models/sale.dart';
import '../models/invoice.dart';
import '../models/invoice_template.dart';
import '../database/app_database.dart';
import '../di/service_locator.dart';
import '../services/tenant_service.dart';

class InvoiceService {
  final AppDatabase _db;
  final TenantService _tenantService;

  InvoiceService()
    : _db = ServiceLocator.instance.database,
      _tenantService = ServiceLocator.instance.tenantService;

  Future<pw.Document> generateInvoicePdf(
    Invoice invoice,
    CustomerEntity? customer,
    InvoiceTemplate template,
  ) async {
    Map<String, dynamic>? profile;
    try {
      final profileRepo = ServiceLocator.instance.profileRepository;
      profile = await profileRepo.getProfile();
    } catch (e) {
      profile = null;
    }

    final tenantId = _tenantService.tenantId;
    final settings = await (_db.select(
      _db.invoiceSettings,
    )..where((t) => t.tenantId.equals(tenantId))).getSingleOrNull();

    final logoPath =
        settings?.logoPath ??
        profile?['logoUrl'] ??
        profile?['imageUrl'] ??
        profile?['profileImage'];

    final mergedProfile = {...?profile, 'logoPath': logoPath};

    switch (template.layout) {
      case InvoiceLayout.modern:
        return await ModernLayout.generate(
          invoice,
          customer,
          template,
          mergedProfile,
        );
      case InvoiceLayout.classic:
        return await ClassicLayout.generate(
          invoice,
          customer,
          template,
          mergedProfile,
        );
      case InvoiceLayout.luxury:
        return await LuxuryLayout.generate(
          invoice,
          customer,
          template,
          mergedProfile,
        );
      case InvoiceLayout.stylish:
        return await StylishLayout.generate(
          invoice,
          customer,
          template,
          mergedProfile,
        );
      case InvoiceLayout.simple:
        return await SimpleLayout.generate(
          invoice,
          customer,
          template,
          mergedProfile,
        );
      case InvoiceLayout.advancedGst:
        return await AdvancedGstLayout.generate(
          invoice,
          customer,
          template,
          mergedProfile,
        );
      case InvoiceLayout.dreams:
        return await DreamsLayout.generate(
          invoice,
          customer,
          template,
          mergedProfile,
        );
      case InvoiceLayout.thermal:
      case InvoiceLayout.custom:
        return await ThermalLayout.generate(
          invoice,
          customer,
          template,
          mergedProfile,
        );
    }
  }

  /// Legacy support for Sales (POS checkout)
  Future<pw.Document> generateInvoice(
    Sale sale,
    InvoiceTemplate template,
  ) async {
    // Map Sale to Invoice for unified layout support
    final invoice = Invoice(
      uuid: sale.uuid,
      invoiceNumber: sale.invoiceNumber,
      customerId: sale.customerId,
      date: sale.createdAt,
      subtotal: sale.subtotal,
      tax: sale.tax,
      discount: sale.discount,
      total: sale.total,
      items: sale.items
          .map(
            (item) => InvoiceItem(
              productId: item.productId,
              productName: item.product.name,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              discount: item.discount, // Map item discount
              totalPrice: item.total,
            ),
          )
          .toList(),
    );

    return await generateInvoicePdf(invoice, null, template);
  }

  Future<pw.Document> generateModernInvoice({
    required Invoice invoice,
    required CustomerEntity? customer,
    required List<InvoiceItem> items,
    required InvoiceTemplate template,
  }) async {
    final fullInvoice = invoice.copyWith(items: items);
    return await generateInvoicePdf(fullInvoice, customer, template);
  }
}
