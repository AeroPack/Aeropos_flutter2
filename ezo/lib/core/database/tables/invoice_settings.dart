import 'package:drift/drift.dart';

@DataClassName('InvoiceSettingEntity')
class InvoiceSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get layout => text().withLength(min: 1, max: 50)();
  TextColumn get footerMessage => text().withLength(max: 1000).withDefault(const Constant(''))();

  // Customization Options
  TextColumn get accentColor => text()
      .withLength(min: 1, max: 10)
      .withDefault(const Constant('#2A2D64'))();
  TextColumn get fontFamily => text()
      .withLength(min: 1, max: 50)
      .withDefault(const Constant('Roboto'))();
  RealColumn get fontSizeMultiplier =>
      real().withDefault(const Constant(1.0))();

  // Personalization
  TextColumn get logoPath => text().nullable()();
  BlobColumn get logoBytes => blob().nullable()();
  
  // Thermal Options
  IntColumn get thermalWidth => integer().withDefault(const Constant(80))();

  // Section Toggles
  BoolColumn get showLogo => boolean().withDefault(const Constant(true))();
  BoolColumn get showTaxBreakdown => boolean().withDefault(const Constant(true))();
  BoolColumn get showAddress => boolean().withDefault(const Constant(true))();
  BoolColumn get showCustomerDetails =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showFooter => boolean().withDefault(const Constant(true))();

  // Multi-tenant Link
  IntColumn get tenantId => integer().nullable()();

  // Custom Template Configuration (JSON)
  TextColumn get customConfig => text().nullable()();

  // Invoice numbering
  IntColumn get invoiceCounter => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
