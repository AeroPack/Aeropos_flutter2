import '../templates/fresh_mart_grocery_template.dart';
import '../templates/electronics_detailed_template.dart';
import '../templates/hardware_shop_a4_template.dart';
import '../templates/design_systems_india_template.dart';
import '../templates/quick_serve_thermal_template.dart';
import '../templates/dine_plus_thermal_template.dart';
import '../templates/service_a4_template.dart';
import '../templates/pharmacy_a5_template.dart';
import '../templates/bistro_half_page_template.dart';
import '../templates/fashionista_a4_template.dart';
import '../templates/grocery_saver_a5_template.dart';
import '../templates/delivery_challan_template.dart';
import '../templates/proforma_invoice_a4_template.dart';
import '../templates/grocery_wholesale_a4_template.dart';
import '../templates/credit_note_template.dart';
import '../templates/restaurant_a4_template.dart';
import 'invoice_template.dart';

class TemplateRegistry {
  static final List<InvoiceTemplate> availableTemplates = <InvoiceTemplate>[
    // === THERMAL (58mm/72mm/80mm) ===
    FreshMartGroceryTemplate(),
    QuickServeThermalTemplate(),
    DinePlusThermalTemplate(),

    // === A5 Half-Page ===
    BistroHalfPageTemplate(),
    FashionShopA4Template(),
    GroceryTaxInvoiceTemplate(),

    // === A4 Full-Page ===
    DesignSystemsIndiaTemplate(),
    ElectronicsDetailedTemplate(),
    HardwareShopA4Template(),
    BusinessDeliveryChallanTemplate(),
    QuotationBusinessTemplate(),
    RestaurantA4InvoiceTemplate(),
    GroceryWholesaleA4Template(),
    PharmacyWholesaleA5Template(),
    BoutiqueA4InvoiceTemplate(),
    TallyCreditNoteTemplate(),
  ];

  static InvoiceTemplate getTemplateById(String id) {
    return availableTemplates.firstWhere(
      (t) => t.id == id,
      orElse: () => availableTemplates.first,
    );
  }
}
