import '../templates/fresh_mart_grocery_template.dart';
import '../templates/electronics_detailed_template.dart';
import '../templates/retail_basic_template.dart';
import '../templates/design_systems_india_template.dart';
import '../templates/quick_serve_thermal_template.dart';
import '../templates/dine_plus_thermal_template.dart';
import '../templates/style_craft_thermal_template.dart';
import '../templates/tech_bill_thermal_template.dart';
import '../templates/bistro_half_page_template.dart';
import '../templates/fashionista_a5_template.dart';
import '../templates/grocery_saver_a5_template.dart';
import '../templates/restaurant_pro_a4_template.dart';
import '../templates/garment_collection_a4_template.dart';
import '../templates/grocery_wholesale_a4_template.dart';
import 'invoice_template.dart';

class TemplateRegistry {
  static final List<InvoiceTemplate> availableTemplates = <InvoiceTemplate>[
    // === THERMAL (58mm/72mm/80mm) ===
    FreshMartGroceryTemplate(),
    QuickServeThermalTemplate(),
    DinePlusThermalTemplate(),
    StyleCraftThermalTemplate(),
    TechBillThermalTemplate(),

    // === A5 Half-Page ===
    BistroHalfPageTemplate(),
    FashionistaA5Template(),
    GrocerySaverA5Template(),

    // === A4 Full-Page ===
    DesignSystemsIndiaTemplate(),
    RetailBasicTemplate(),
    ElectronicsDetailedTemplate(),
    RestaurantProA4Template(),
    GarmentCollectionA4Template(),
    GroceryWholesaleA4Template(),
  ];

  static InvoiceTemplate getTemplateById(String id) {
    return availableTemplates.firstWhere(
      (t) => t.id == id,
      orElse: () => availableTemplates.first,
    );
  }
}
