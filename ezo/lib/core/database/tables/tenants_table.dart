import 'package:drift/drift.dart';

@DataClassName('TenantEntity')
class Tenants extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get businessName => text().nullable()();
  TextColumn get businessAddress => text().nullable()();
  TextColumn get taxId => text().nullable()();

  // Backend SaaS/org fields
  TextColumn get externalKey => text().nullable()();
  TextColumn get slug => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get plan => text().withDefault(const Constant('free'))();
  DateTimeColumn get planExpiresAt => dateTime().nullable()();
  TextColumn get billingEmail => text().nullable()();
  TextColumn get settings => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns - keeping them consistent with other tables for potential sync
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}
