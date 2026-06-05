import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'connection/connection.dart' as impl;

import 'package:aeropos/core/di/service_locator.dart';
import 'tables/products_table.dart';
import 'tables/categories_table.dart';
import 'tables/units_table.dart';
import 'tables/product_units_table.dart';
import 'tables/tenants_table.dart';
import 'tables/companies_table.dart';
import 'tables/customers_table.dart';
import 'tables/suppliers_table.dart';
import 'tables/employees_table.dart';
import 'tables/invoice_settings.dart';
import 'tables/invoices_table.dart';
import 'tables/invoice_items_table.dart';
import 'tables/sync_metadata.dart';
import 'tables/brands_table.dart';
import 'tables/sku_counter_table.dart';
import 'tables/reserved_skus_table.dart';
import 'tables/customer_transactions_table.dart';
import 'tables/supplier_transactions_table.dart';
import 'tables/purchase_receipts_table.dart';
import 'tables/purchase_receipt_items_table.dart';
import 'tables/sync_outbox.dart';
import 'tables/sync_errors.dart';
import 'tables/sync_state.dart';
import 'tables/stock_outbox.dart';
import 'tables/returns_table.dart';
import 'tables/return_items_table.dart';
import 'tables/wallet_transactions_table.dart';
import 'tables/inventory_movements_table.dart';
import 'tables/invoice_audit_logs_table.dart';
import 'dao/customer_transaction_dao.dart';
import 'dao/supplier_transaction_dao.dart';
import 'dao/product_unit_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Products,
    Categories,
    Units,
    ProductUnits,
    Tenants,
    Companies,
    Customers,
    Suppliers,
    Employees,
    InvoiceSettings,
    Invoices,
    InvoiceItems,
    Brands,
    SyncMetadata,
    SkuCounters,
    ReservedSkus,
    CustomerTransactions,
    SupplierTransactions,
    PurchaseReceipts,
    PurchaseReceiptItems,
    SyncOutbox,
    SyncErrors,
    SyncState,
    StockOutbox,
    Returns,
    ReturnItems,
    WalletTransactions,
    InventoryMovements,
    InvoiceAuditLogs,
  ],
  daos: [CustomerTransactionDao, SupplierTransactionDao, ProductUnitDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? impl.connect());

  @override
  int get schemaVersion => 55;

  Future<void> _addColumnIfNotExists(
    String table,
    String column,
    String definition,
  ) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    final exists = rows.any((r) => r.read<String>('name') == column);
    if (exists) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        // debugPrint('DRIFT: Running onCreate - creating all tables');
        await m.createAll();

        await _seedDefaultUnits();

        // Create performance indexes for fresh databases
        final indexes = [
          'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
          'CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku)',
          'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)',
          'CREATE INDEX IF NOT EXISTS idx_products_company ON products(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)',
          'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)',
          'CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(date)',
          'CREATE INDEX IF NOT EXISTS idx_invoices_company ON invoices(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id)',
          'CREATE INDEX IF NOT EXISTS idx_customers_company ON customers(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_suppliers_company ON suppliers(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_categories_company ON categories(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_units_company ON units(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_brands_company ON brands(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_employees_company ON employees(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_product_units_company ON product_units(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_invoice_items_company ON invoice_items(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_returns_company ON returns(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_return_items_company ON return_items(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_customer_transactions_company ON customer_transactions(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_supplier_transactions_company ON supplier_transactions(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_wallet_transactions_company ON wallet_transactions(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_inventory_movements_company ON inventory_movements(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_purchase_receipts_company ON purchase_receipts(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_invoice_audit_logs_company ON invoice_audit_logs(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_reserved_skus_company ON reserved_skus(company_id)',
          'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice_id ON invoice_items(invoice_id)',
          'CREATE INDEX IF NOT EXISTS idx_invoice_items_product_id ON invoice_items(product_id)',
          'CREATE INDEX IF NOT EXISTS idx_invoice_items_deleted ON invoice_items(is_deleted)',
          'CREATE INDEX IF NOT EXISTS idx_invoices_tenant_deleted_date ON invoices(company_id, is_deleted, date DESC)',
          'CREATE INDEX IF NOT EXISTS idx_product_units_barcode ON product_units(barcode) WHERE barcode IS NOT NULL AND is_deleted = 0',
        ];
        for (final stmt in indexes) {
          try {
            await customStatement(stmt);
          } catch (e) {
            // ignore
          }
        }

        // debugPrint('DRIFT: onCreate complete');
      },

      onUpgrade: (m, from, to) async {
        if (from < 36) {
          await m.createTable(syncOutbox);
          await m.createTable(syncState);
          await m.createTable(stockOutbox);
        }

        if (from < 35) {
          try {
            await _addColumnIfNotExists('products', 'base_unit_id', 'INTEGER');
          } catch (e) {
            if (!e.toString().contains('duplicate column name')) rethrow;
          }
          try {
            await _addColumnIfNotExists(
                'products', 'allow_loose_sale', 'INTEGER NOT NULL DEFAULT 1');
          } catch (e) {
            if (!e.toString().contains('duplicate column name')) rethrow;
          }
          // Create product_units table
          await m.createTable(productUnits);

          await _seedDefaultUnits();
        }

        // Existing migrations...
        if (from < 18) {
          // ... (keep existing logic if possible, but for simplicity relying on previous state)
          // If we are at 18, we don't need to repeat.
        }

        if (from < 19) {
          // Rename users to tenants
          try {
            await customStatement('ALTER TABLE users RENAME TO tenants');
          } catch (e) {
            // Attempt to create tenants if rename failed (maybe users didn't exist)
            await m.createTable(tenants);
          }

          // Create new tables
          await m.createTable(customers);
          await m.createTable(suppliers);
          await m.createTable(employees);

          // Add companyId to existing tables
          final tablesWithTenantId = [
            products,
            categories,
            units,
            brands,
            invoices,
            invoiceItems,
          ];
          for (final table in tablesWithTenantId) {
            // Cast to dynamic to access companyId property which exists on all these tables
            await _safeAddColumn(
              m,
              table,
              'company_id',
              (table as dynamic).companyId,
            );
          }
        }

        if (from < 20) {
          // Backfill tenant_id for existing rows that might be NULL
          // We default to 1 as the primary tenant
          final tablesToCheck = [
            'products',
            'categories',
            'units',
            'brands',
            'invoices',
            'invoice_items',
          ];

          for (final tableName in tablesToCheck) {
            try {
              await customStatement(
                'UPDATE "$tableName" SET tenant_id = 1 WHERE tenant_id IS NULL',
              );
            } catch (e) {
              // ignore: avoid_print
            }
          }
        }

        if (from < 21) {
          // Add role column to employees table
          await _safeAddColumn(m, employees, 'role', employees.role);
        }

        if (from < 22) {
          // Add password column to employees table
          await _safeAddColumn(m, employees, 'password', employees.password);
        }

        if (from < 23) {
          // Create SKU counter table
          await m.createTable(skuCounters);
        }

        if (from < 24) {
          // Add device_id column to sku_counters table
          await _safeAddColumn(
            m,
            skuCounters,
            'device_id',
            skuCounters.deviceId,
          );
        }

        if (from < 25) {
          // Add google_auth column to employees table
          await _safeAddColumn(
            m,
            employees,
            'google_auth',
            employees.googleAuth,
          );
        }

        if (from < 28) {
          // Add all missing invoice settings enhancements
          final cols = [
            'company_id',
            'custom_config',
            'updated_at',
            'footer_message',
            'accent_color',
            'font_family',
            'font_size_multiplier',
            'logo_path',
            'thermal_width',
            'show_logo',
            'show_tax_breakdown',
            'show_address',
            'show_customer_details',
            'show_footer',
          ];

          for (final colName in cols) {
            GeneratedColumn? col;
            if (colName == 'company_id') col = invoiceSettings.companyId;
            if (colName == 'custom_config') col = invoiceSettings.customConfig;
            if (colName == 'updated_at') col = invoiceSettings.updatedAt;
            if (colName == 'footer_message') {
              col = invoiceSettings.footerMessage;
            }
            if (colName == 'accent_color') col = invoiceSettings.accentColor;
            if (colName == 'font_family') col = invoiceSettings.fontFamily;
            if (colName == 'font_size_multiplier') {
              col = invoiceSettings.fontSizeMultiplier;
            }
            if (colName == 'logo_path') col = invoiceSettings.logoPath;
            if (colName == 'thermal_width') col = invoiceSettings.thermalWidth;
            if (colName == 'show_logo') col = invoiceSettings.showLogo;
            if (colName == 'show_tax_breakdown') {
              col = invoiceSettings.showTaxBreakdown;
            }
            if (colName == 'show_address') col = invoiceSettings.showAddress;
            if (colName == 'show_customer_details') {
              col = invoiceSettings.showCustomerDetails;
            }
            if (colName == 'show_footer') col = invoiceSettings.showFooter;

            if (col != null) {
              await _safeAddColumn(m, invoiceSettings, colName, col);
            }
          }

          // Data Fix: Update any existing NULL values to defaults to avoid Null-check crashes
          await customStatement(
            'UPDATE "invoice_settings" SET "accent_color" = \'#2A2D64\' WHERE "accent_color" IS NULL',
          );
          await customStatement(
            'UPDATE "invoice_settings" SET "font_family" = \'Roboto\' WHERE "font_family" IS NULL',
          );
          await customStatement(
            'UPDATE "invoice_settings" SET "font_size_multiplier" = 1.0 WHERE "font_size_multiplier" IS NULL',
          );
          await customStatement(
            'UPDATE "invoice_settings" SET "thermal_width" = 80 WHERE "thermal_width" IS NULL',
          );
          await customStatement(
            'UPDATE "invoice_settings" SET "show_logo" = 1 WHERE "show_logo" IS NULL',
          );
          await customStatement(
            'UPDATE "invoice_settings" SET "show_tax_breakdown" = 1 WHERE "show_tax_breakdown" IS NULL',
          );
          await customStatement(
            'UPDATE "invoice_settings" SET "show_address" = 1 WHERE "show_address" IS NULL',
          );
          await customStatement(
            'UPDATE "invoice_settings" SET "show_customer_details" = 1 WHERE "show_customer_details" IS NULL',
          );
          await customStatement(
            'UPDATE "invoice_settings" SET "show_footer" = 1 WHERE "show_footer" IS NULL',
          );
          await customStatement(
            'UPDATE "invoice_settings" SET "footer_message" = \'\' WHERE "footer_message" IS NULL',
          );
          await customStatement(
            'UPDATE "invoice_settings" SET "updated_at" = CURRENT_TIMESTAMP WHERE "updated_at" IS NULL',
          );
        }
        if (from < 29) {
          // Add payment_method column to invoices table
          await _safeAddColumn(
            m,
            invoices,
            'payment_method',
            invoices.paymentMethod as GeneratedColumn<Object>,
          );
        }
        if (from < 30) {
          // Create Reserved SKUs table
          await m.createTable(reservedSkus);
        }
        if (from < 31) {
          // Create Customer Transactions table
          await m.createTable(customerTransactions);
        }
        if (from < 32) {
          // Create Supplier Transactions table
          await m.createTable(supplierTransactions);
        }
        if (from < 33) {
          // debugPrint(
          //   'DRIFT: Running migration from < 33 - Creating Purchase Receipts tables',
          // );
          try {
            await m.createTable(purchaseReceipts);
            await m.createTable(purchaseReceiptItems);
            // debugPrint('DRIFT: Purchase Receipts tables created');
          } catch (e) {
            debugPrint('ERROR creating purchase_receipts tables: $e');
          }
        }
        if (from < 34) {
          // debugPrint(
          //   'DRIFT: Running migration to 34 - Creating Purchase Receipts tables',
          // );
          try {
            await m.createTable(purchaseReceipts);
            await m.createTable(purchaseReceiptItems);
            // debugPrint('DRIFT: Purchase Receipts tables created successfully');
          } catch (e) {
            // debugPrint('DRIFT: Tables may already exist or error: $e');
          }
        }

        // Migration 38: Add version column to invoices table
        if (from < 38) {
          // debugPrint(
          //   'DRIFT: Running migration to 38 - Adding version column to invoices',
          // );
          try {
            await customStatement(
              'ALTER TABLE invoices ADD COLUMN version INTEGER NOT NULL DEFAULT 1',
            );
            // debugPrint('DRIFT: version column added to invoices');
          } catch (e) {
            // debugPrint('DRIFT: version column may already exist: $e');
          }
        }

        // Migration 39: UUID backfill + sync improvements
        if (from < 39) {
          // debugPrint(
          //   'DRIFT: Running migration 39 - UUID backfill + sync improvements',
          // );

          try {
            // UUID backfill for all tables
            // debugPrint('DRIFT: Backfilling UUIDs for units');
            await customStatement(
              "UPDATE units SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL OR uuid = ''",
            );

            // debugPrint('DRIFT: Backfilling UUIDs for categories');
            await customStatement(
              "UPDATE categories SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL OR uuid = ''",
            );

            // debugPrint('DRIFT: Backfilling UUIDs for brands');
            await customStatement(
              "UPDATE brands SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL OR uuid = ''",
            );

            // debugPrint('DRIFT: Backfilling UUIDs for products');
            await customStatement(
              "UPDATE products SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL OR uuid = ''",
            );

            // debugPrint('DRIFT: Backfilling UUIDs for customers');
            await customStatement(
              "UPDATE customers SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL OR uuid = ''",
            );

            // debugPrint('DRIFT: Backfilling UUIDs for suppliers');
            await customStatement(
              "UPDATE suppliers SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL OR uuid = ''",
            );

            // debugPrint('DRIFT: Backfilling UUIDs for employees');
            await customStatement(
              "UPDATE employees SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL OR uuid = ''",
            );

            // Add columns to sync_outbox (if table exists)
            try {
              // debugPrint('DRIFT: Adding retry columns to sync_outbox');
              await customStatement(
                "ALTER TABLE sync_outbox ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0",
              );
              await customStatement(
                "ALTER TABLE sync_outbox ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'",
              );
              await customStatement(
                "ALTER TABLE sync_outbox ADD COLUMN last_error TEXT",
              );
              await customStatement(
                "ALTER TABLE sync_outbox ADD COLUMN next_retry_at TEXT",
              );
            } catch (e) {
              // debugPrint('DRIFT: sync_outbox columns may already exist: $e');
            }

            // debugPrint('DRIFT: Migration 39 completed');
          } catch (e) {
            // debugPrint('DRIFT: Migration 39 error: $e');
          }
        }

        // Migration 40: Add hsn column to products table
        if (from < 40) {
          // debugPrint('DRIFT: Running migration 40 - Adding hsn column to products');
          try {
            await customStatement(
              "ALTER TABLE products ADD COLUMN hsn TEXT",
            );
            // debugPrint('DRIFT: hsn column added to products');
          } catch (e) {
            // debugPrint('DRIFT: hsn column may already exist: $e');
          }
        }

        // Migration 41: Add invoice_counter column to invoice_settings
        if (from < 41) {
          // debugPrint('DRIFT: Running migration 41 - Adding invoice_counter to invoice_settings');
          try {
            await customStatement(
              'ALTER TABLE invoice_settings ADD COLUMN invoice_counter INTEGER NOT NULL DEFAULT 0',
            );
            // debugPrint('DRIFT: invoice_counter column added');
          } catch (e) {
            // debugPrint('DRIFT: invoice_counter column may already exist: $e');
          }
        }

        // Migration 42: Add gstin column to customers table
        if (from < 42) {
          // debugPrint('DRIFT: Running migration 42 - Adding gstin to customers');
          try {
            await customStatement(
              'ALTER TABLE customers ADD COLUMN gstin TEXT',
            );
            // debugPrint('DRIFT: gstin column added to customers');
          } catch (e) {
            // debugPrint('DRIFT: gstin column may already exist: $e');
          }
        }

        // Migration 43: Add logo_bytes BLOB to invoice_settings
        if (from < 43) {
          // debugPrint('DRIFT: Running migration 43 - Adding logo_bytes to invoice_settings');
          try {
            await customStatement(
              'ALTER TABLE invoice_settings ADD COLUMN logo_bytes BLOB',
            );
            // debugPrint('DRIFT: logo_bytes column added to invoice_settings');
          } catch (e) {
            // debugPrint('DRIFT: logo_bytes column may already exist: $e');
          }
        }

        // Migration 44: Add performance indexes for common queries
        if (from < 44) {
          final indexes = [
            'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
            'CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku)',
            'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)',
            'CREATE INDEX IF NOT EXISTS idx_products_company ON products(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)',
            'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)',
            'CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(date)',
            'CREATE INDEX IF NOT EXISTS idx_invoices_company ON invoices(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id)',
          ];
          for (final stmt in indexes) {
            try {
              await customStatement(stmt);
            } catch (e) {
              // debugPrint('DRIFT: Index creation warning: $e');
            }
          }
        }

        // Migration 47: Add logo_local_path column for file-system based logo storage
        if (from < 47) {
          await _addColumnIfNotExists('invoice_settings', 'logo_local_path', 'TEXT');
        }

        // Migration 50: Add phone to tenants; add tax/footer fields to invoice_settings
        if (from < 50) {
          final cols50 = <String, String>{
            'phone': 'ALTER TABLE tenants ADD COLUMN phone TEXT',
            'tax_label': 'ALTER TABLE invoice_settings ADD COLUMN tax_label TEXT',
            'tax_rate': 'ALTER TABLE invoice_settings ADD COLUMN tax_rate REAL',
            'terms_and_conditions': 'ALTER TABLE invoice_settings ADD COLUMN terms_and_conditions TEXT',
            'authorized_signatory': 'ALTER TABLE invoice_settings ADD COLUMN authorized_signatory TEXT',
          };
          for (final sql in cols50.values) {
            try {
              await customStatement(sql);
            } catch (_) {}
          }
        }

        // Migration 49: Add uuid column to product_units for sync support
        if (from < 49) {
          await _addColumnIfNotExists('product_units', 'uuid', 'TEXT');
          final rows = await customStatement(
            'SELECT id FROM product_units WHERE uuid IS NULL',
          ) as List<Map<String, dynamic>>? ?? [];
          for (final row in rows) {
            final uuid = const Uuid().v4();
            await customStatement(
              "UPDATE product_units SET uuid = '$uuid' WHERE id = ${row['id']}",
            );
          }
        }

        // Migration 48: Add barcode index for fast product lookup
        if (from < 48) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_product_units_barcode '
            'ON product_units(barcode) '
            'WHERE barcode IS NOT NULL AND is_deleted = 0',
          );
        }

        // Migration 46: Add join-columns and composite indexes for invoice queries
        if (from < 46) {
          final indexes = [
            'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice_id ON invoice_items(invoice_id)',
            'CREATE INDEX IF NOT EXISTS idx_invoice_items_product_id ON invoice_items(product_id)',
            'CREATE INDEX IF NOT EXISTS idx_invoice_items_deleted ON invoice_items(is_deleted)',
            'CREATE INDEX IF NOT EXISTS idx_invoices_tenant_deleted_date ON invoices(company_id, is_deleted, date DESC)',
          ];
          for (final stmt in indexes) {
            try {
              await customStatement(stmt);
            } catch (e) {
              // debugPrint('DRIFT: Migration 46 index creation warning: $e');
            }
          }
        }

        // Migration 45: Add multi-tenant indexes for all remaining tenant-scoped tables
        if (from < 45) {
          final indexes = [
            'CREATE INDEX IF NOT EXISTS idx_customers_company ON customers(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_suppliers_company ON suppliers(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_categories_company ON categories(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_units_company ON units(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_brands_company ON brands(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_employees_company ON employees(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_product_units_company ON product_units(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_invoice_items_company ON invoice_items(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_returns_company ON returns(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_return_items_company ON return_items(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_customer_transactions_company ON customer_transactions(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_supplier_transactions_company ON supplier_transactions(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_wallet_transactions_company ON wallet_transactions(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_inventory_movements_company ON inventory_movements(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_purchase_receipts_company ON purchase_receipts(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_invoice_audit_logs_company ON invoice_audit_logs(company_id)',
            'CREATE INDEX IF NOT EXISTS idx_reserved_skus_company ON reserved_skus(company_id)',
          ];
          for (final stmt in indexes) {
            try {
              await customStatement(stmt);
            } catch (e) {
              // debugPrint('DRIFT: Index creation warning: $e');
            }
          }
        }

        // Migration 51: Add backend columns to tenants, employees, and deletedAt fields
        if (from < 51) {
          // Tenants: backend SaaS/org fields
          await _addColumnIfNotExists('tenants', 'external_key', 'TEXT');
          await _addColumnIfNotExists('tenants', 'slug', 'TEXT');
          await _addColumnIfNotExists('tenants', 'status',
              'TEXT NOT NULL DEFAULT \'active\'');
          await _addColumnIfNotExists('tenants', 'plan',
              'TEXT NOT NULL DEFAULT \'free\'');
          await _addColumnIfNotExists('tenants', 'plan_expires_at', 'TEXT');
          await _addColumnIfNotExists('tenants', 'billing_email', 'TEXT');
          await _addColumnIfNotExists('tenants', 'settings', 'TEXT');
          // Required by $TenantsTable.map() non-null assertions
          await _addColumnIfNotExists(
              'tenants', 'sync_status', 'INTEGER NOT NULL DEFAULT 0');
          await _addColumnIfNotExists(
              'tenants', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
          await _addColumnIfNotExists('tenants', 'business_name', 'TEXT');
          await _addColumnIfNotExists('tenants', 'business_address', 'TEXT');

          // Employees: avatar, ownership, verification, password reset
          await _addColumnIfNotExists('employees', 'avatar_url', 'TEXT');
          await _addColumnIfNotExists('employees', 'is_owner', 'INTEGER NOT NULL DEFAULT 0');
          await _addColumnIfNotExists('employees', 'is_email_verified', 'INTEGER NOT NULL DEFAULT 0');
          await _addColumnIfNotExists('employees', 'email_verification_token', 'TEXT');
          await _addColumnIfNotExists('employees', 'email_verification_expires', 'TEXT');
          await _addColumnIfNotExists('employees', 'password_reset_token', 'TEXT');
          await _addColumnIfNotExists('employees', 'password_reset_expires', 'TEXT');

          // deletedAt on backend-matching tables for soft-delete timestamp
          await _addColumnIfNotExists('products', 'deleted_at', 'TEXT');
          await _addColumnIfNotExists('categories', 'deleted_at', 'TEXT');
          await _addColumnIfNotExists('units', 'deleted_at', 'TEXT');
          await _addColumnIfNotExists('brands', 'deleted_at', 'TEXT');
        }

        // Migration 52: Backfill missing non-nullable tenants columns for
        // databases that went through v51 before sync_status/is_deleted were added.
        if (from < 52) {
          for (final sql in [
            "ALTER TABLE tenants ADD COLUMN sync_status INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE tenants ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE tenants ADD COLUMN business_name TEXT",
            "ALTER TABLE tenants ADD COLUMN business_address TEXT",
          ]) {
            try {
              await customStatement(sql);
            } catch (_) {}
          }
        }

        // Migration 53: Re-run same columns with the now-safe _addColumnIfNotExists
        // to fix the duplicate-column crash on Flutter web where the try/catch in
        // migration 52 leaked before the Future resolved.
        if (from < 53) {
          await _addColumnIfNotExists(
              'tenants', 'sync_status', 'INTEGER NOT NULL DEFAULT 0');
          await _addColumnIfNotExists(
              'tenants', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
          await _addColumnIfNotExists('tenants', 'business_name', 'TEXT');
          await _addColumnIfNotExists('tenants', 'business_address', 'TEXT');
        }

        // Migration 54: Add invoice columns that existed in the Drift schema
        // but were never added via ALTER TABLE for users upgrading from older DBs.
        if (from < 54) {
          await _addColumnIfNotExists(
              'invoices', 'payment_status', "TEXT NOT NULL DEFAULT 'PENDING'");
          await _addColumnIfNotExists('invoices', 'sign_url', 'TEXT');
          await _addColumnIfNotExists('invoices', 'transaction_id', 'TEXT');
          await _addColumnIfNotExists('invoices', 'deleted_at', 'TEXT');
          await _addColumnIfNotExists('invoices', 'deleted_by', 'INTEGER');
          await _addColumnIfNotExists('invoices', 'delete_reason', 'TEXT');
          await _addColumnIfNotExists(
              'invoices', 'sync_status', 'INTEGER NOT NULL DEFAULT 0');
          await _addColumnIfNotExists(
              'invoices', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
          await _addColumnIfNotExists('invoices', 'idempotency_key', 'TEXT');
        }

        // Migration 55: Create Companies table, rename tenant_id → company_id
        if (from < 55) {
          await m.createTable(companies);
          final tablesToRename = [
            'products', 'categories', 'units', 'brands',
            'customers', 'suppliers', 'employees',
            'invoices', 'invoice_items', 'returns', 'return_items',
            'customer_transactions', 'supplier_transactions',
            'purchase_receipts', 'purchase_receipt_items',
            'inventory_movements', 'wallet_transactions',
            'product_units', 'reserved_skus', 'invoice_audit_logs',
            'invoice_settings',
          ];
          for (final table in tablesToRename) {
            try {
              final info = await customSelect(
                'PRAGMA table_info($table)',
              ).get();
              final hasCompanyId = info.any(
                (r) => r.read<String>('name') == 'company_id',
              );
              final hasTenantId = info.any(
                (r) => r.read<String>('name') == 'tenant_id',
              );
              if (!hasCompanyId && hasTenantId) {
                await customStatement(
                  'ALTER TABLE "$table" RENAME COLUMN tenant_id TO company_id',
                );
              }
            } catch (e) {
              debugPrint('Migration 55: skip rename on $table — $e');
            }
          }
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _safeAddColumn(
    Migrator m,
    dynamic table,
    String columnName,
    GeneratedColumn column,
  ) async {
    try {
      final tableName = (table as TableInfo).actualTableName;
      final result = await customSelect("PRAGMA table_info($tableName)").get();
      final columnNames = result
          .map((row) => row.read<String>('name'))
          .toList();

      if (!columnNames.contains(columnName)) {
        // SQLite doesn't support adding UNIQUE or NOT NULL without default via ALTER TABLE easily
        // We add it as a plain nullable column first to ensure the column exists for queries
        String sql = 'ALTER TABLE "$tableName" ADD COLUMN "$columnName" ';
        if (column.type == DriftSqlType.string) {
          sql += 'TEXT';
        } else if (column.type == DriftSqlType.int ||
            column.type == DriftSqlType.bool ||
            column.type == DriftSqlType.dateTime) {
          sql += 'INTEGER';
        } else if (column.type == DriftSqlType.double) {
          sql += 'REAL';
        } else {
          sql += 'TEXT';
        }

        await customStatement(sql);
      }
    } catch (e) {
      // ignored
    }
  }

  // Basic CRUD for Products
  Future<List<ProductEntity>> getAllProducts() => select(products).get();
  Stream<List<ProductEntity>> watchAllProducts() =>
      (select(products)
        ..where((tbl) => tbl.isDeleted.equals(false))
        ..orderBy([
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ])
      ).watch();

  /// Returns products filtered by name/sku search and category, sorted by name.
  /// No client-side filtering needed — filtering happens in SQL.
  Future<List<ProductEntity>> getFilteredProducts({
    String query = '',
    int? categoryId,
  }) async {
    final q = select(products)
      ..where((t) => t.isDeleted.equals(false));

    if (query.isNotEmpty) {
      q.where((t) =>
        t.name.contains(query) | t.sku.contains(query)
      );
    }
    if (categoryId != null) {
      q.where((t) => t.categoryId.equals(categoryId));
    }

    return q.get();
  }

  /// Returns paginated products with optional search/category filter.
  /// This is a one-time read ([Future]), not a reactive stream.
  Future<List<ProductEntity>> getPagedProducts({
    required int limit,
    required int offset,
    String query = '',
    int? categoryId,
  }) async {
    final q = select(products)
      ..where((t) => t.isDeleted.equals(false))
      ..limit(limit, offset: offset);

    if (query.isNotEmpty) {
      q.where((t) =>
        t.name.contains(query) | t.sku.contains(query)
      );
    }
    if (categoryId != null) {
      q.where((t) => t.categoryId.equals(categoryId));
    }

    return q.get();
  }
  Future<int> insertProduct(ProductsCompanion entry) =>
      into(products).insert(entry);
  Future<bool> updateProduct(ProductEntity entry) =>
      update(products).replace(entry);
  Future<int> deleteProduct(int id) async {
    final product = await (select(
      products,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    final updated = product.copyWith(
      isDeleted: true,
      syncStatus: 1,
      updatedAt: DateTime.now(),
    );
    final success = await update(products).replace(updated);
    return success ? 1 : 0;
  }

  // Products with category names
  Stream<List<TypedResult>> watchProductsWithCategory() {
    final query = select(products).join([
      leftOuterJoin(categories, categories.id.equalsExp(products.categoryId)),
      leftOuterJoin(brands, brands.id.equalsExp(products.brandId)),
    ])
      ..where(products.isDeleted.equals(false))
      ..orderBy([OrderingTerm(expression: products.updatedAt, mode: OrderingMode.desc)]);
    return query.watch();
  }

  Future<({ProductEntity product, ProductUnitEntity unit})> insertQuickProduct({
    required String barcode,
    required String name,
    required double sellingPrice,
    required int defaultUnitId,
    required int initialStock,
  }) async {
    return transaction(() async {
      const uuidGen = Uuid();
      final productUuid = uuidGen.v4();
      final unitUuid = uuidGen.v4();
      final companyId = ServiceLocator.instance.sessionService.companyId;
      const syncStatus = 1;

      final productId = await into(products).insert(
        ProductsCompanion.insert(
          uuid: productUuid,
          companyId: companyId,
          syncStatus: const Value(syncStatus),
          name: name,
          price: sellingPrice,
          stockQuantity: Value(initialStock),
          isDeleted: const Value(false),
        ),
      );

      final unitId = await into(productUnits).insert(
        ProductUnitsCompanion.insert(
          uuid: unitUuid,
          companyId: companyId,
          syncStatus: const Value(syncStatus),
          productId: productId,
          unitId: defaultUnitId,
          barcode: Value(barcode),
          conversionFactor: 1.0,
          sellingPrice: Value(sellingPrice),
          isDefault: const Value(true),
          isDeleted: const Value(false),
        ),
      );

      final newProduct =
          await (select(products)..where((t) => t.id.equals(productId))).getSingle();
      final newUnit =
          await (select(productUnits)..where((t) => t.id.equals(unitId))).getSingle();

      return (product: newProduct, unit: newUnit);
    });
  }

  /// Returns all active (non-deleted) product+unit matches for a barcode.
  /// An empty list means no match. Length > 1 means duplicate barcodes.
  Future<List<({ProductEntity product, ProductUnitEntity unit})>> getProductsByBarcode(
    String barcode,
  ) async {
    final query = select(productUnits).join([
      innerJoin(products, products.id.equalsExp(productUnits.productId)),
    ])
      ..where(productUnits.barcode.equals(barcode))
      ..where(productUnits.isDeleted.equals(false))
      ..where(products.isDeleted.equals(false));

    final rows = await query.get();
    return rows.map((row) => (
      product: row.readTable(products),
      unit: row.readTable(productUnits),
    )).toList();
  }

  // Basic CRUD for Categories
  Future<List<CategoryEntity>> getAllCategories() => select(categories).get();
  Stream<List<CategoryEntity>> watchAllCategories() =>
      (select(categories)..where((tbl) => tbl.isDeleted.equals(false))).watch();
  Future<int> insertCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);
  Future<bool> updateCategory(CategoryEntity entry) =>
      update(categories).replace(entry);
  Future<int> deleteCategory(int id) async {
    final category = await (select(
      categories,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    final updated = category.copyWith(
      isDeleted: true,
      syncStatus: 1,
      updatedAt: DateTime.now(),
    );
    final success = await update(categories).replace(updated);
    return success ? 1 : 0;
  }

  // Basic CRUD for Units
  Future<List<UnitEntity>> getAllUnits() => select(units).get();
  Stream<List<UnitEntity>> watchAllUnits() =>
      (select(units)..where((tbl) => tbl.isDeleted.equals(false))).watch();
  Future<int> insertUnit(UnitsCompanion entry) => into(units).insert(entry);
  Future<bool> updateUnit(UnitEntity entry) => update(units).replace(entry);
  Future<int> deleteUnit(int id) async {
    final unit = await (select(
      units,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    final updated = unit.copyWith(
      isDeleted: true,
      syncStatus: 1,
      updatedAt: DateTime.now(),
    );
    final success = await update(units).replace(updated);
    return success ? 1 : 0;
  }

  // Basic CRUD for Tenants
  Future<TenantEntity?> getCurrentTenant() => select(tenants).getSingleOrNull();
  Future<int> insertTenant(TenantsCompanion entry) =>
      into(tenants).insert(entry);
  Future<bool> updateTenant(TenantEntity entry) =>
      update(tenants).replace(entry);

  /// Upserts a tenant row from company profile data received from the backend.
  /// Called after login and after profile updates so the invoice hydration
  /// always reads real data instead of template dummy fallbacks.
  Future<void> upsertTenantFromCompany({
    required int companyId,
    required String name,
    String? email,
    String? phone,
    String? businessAddress,
    String? taxId,
  }) async {
    final existing = await (select(tenants)
          ..where((t) => t.id.equals(companyId)))
        .getSingleOrNull();

    final companion = TenantsCompanion(
      id: Value(companyId),
      uuid: existing != null
          ? Value(existing.uuid)
          : Value('tenant-$companyId'),
      name: Value(name),
      email: Value(email),
      phone: Value(phone),
      businessName: Value(name),
      businessAddress: Value(businessAddress),
      taxId: Value(taxId),
      updatedAt: Value(DateTime.now()),
    );

    if (existing == null) {
      await into(tenants).insert(companion,
          mode: InsertMode.insertOrReplace);
    } else {
      await (update(tenants)..where((t) => t.id.equals(companyId)))
          .write(companion);
    }
  }

  // Basic CRUD for Customers
  Future<List<CustomerEntity>> getAllCustomers() => select(customers).get();
  Stream<List<CustomerEntity>> watchAllCustomers() =>
      (select(customers)..where((tbl) => tbl.isDeleted.equals(false))).watch();

  /// Returns customers filtered by name/phone search.
  Future<List<CustomerEntity>> getFilteredCustomers({String query = ''}) async {
    final q = select(customers)
      ..where((t) => t.isDeleted.equals(false));

    if (query.isNotEmpty) {
      q.where((t) =>
        t.name.contains(query) | t.phone.contains(query)
      );
    }

    return q.get();
  }

  /// Returns paginated customers with optional search filter.
  Future<List<CustomerEntity>> getPagedCustomers({
    required int limit,
    required int offset,
    String query = '',
  }) async {
    final q = select(customers)
      ..where((t) => t.isDeleted.equals(false))
      ..limit(limit, offset: offset);

    if (query.isNotEmpty) {
      q.where((t) =>
        t.name.contains(query) | t.phone.contains(query)
      );
    }

    return q.get();
  }
  Future<int> insertCustomer(CustomersCompanion entry) =>
      into(customers).insert(entry);
  Future<bool> updateCustomer(CustomerEntity entry) =>
      update(customers).replace(entry);
  Future<int> deleteCustomer(int id) async {
    final item = await (select(
      customers,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    final updated = item.copyWith(
      isDeleted: true,
      syncStatus: 1,
      updatedAt: DateTime.now(),
    );
    return (await update(customers).replace(updated)) ? 1 : 0;
  }

  // Basic CRUD for Suppliers
  Future<List<SupplierEntity>> getAllSuppliers() => select(suppliers).get();
  Stream<List<SupplierEntity>> watchAllSuppliers() =>
      (select(suppliers)..where((tbl) => tbl.isDeleted.equals(false))).watch();
  Future<int> insertSupplier(SuppliersCompanion entry) =>
      into(suppliers).insert(entry);
  Future<bool> updateSupplier(SupplierEntity entry) =>
      update(suppliers).replace(entry);
  Future<int> deleteSupplier(int id) async {
    final item = await (select(
      suppliers,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    final updated = item.copyWith(
      isDeleted: true,
      syncStatus: 1,
      updatedAt: DateTime.now(),
    );
    return (await update(suppliers).replace(updated)) ? 1 : 0;
  }

  // Basic CRUD for Employees
  Future<List<EmployeeEntity>> getAllEmployees() => select(employees).get();
  Stream<List<EmployeeEntity>> watchAllEmployees() =>
      (select(employees)..where((tbl) => tbl.isDeleted.equals(false))).watch();
  Future<int> insertEmployee(EmployeesCompanion entry) =>
      into(employees).insert(entry);
  Future<bool> updateEmployee(EmployeeEntity entry) =>
      update(employees).replace(entry);
  Future<int> deleteEmployee(int id) async {
    final item = await (select(
      employees,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    final updated = item.copyWith(
      isDeleted: true,
      syncStatus: 1,
      updatedAt: DateTime.now(),
    );
    return (await update(employees).replace(updated)) ? 1 : 0;
  }

  // Basic CRUD for Brands
  Future<List<BrandEntity>> getAllBrands() => select(brands).get();
  Stream<List<BrandEntity>> watchAllBrands() =>
      (select(brands)..where((tbl) => tbl.isDeleted.equals(false))).watch();
  Future<int> insertBrand(BrandsCompanion entry) => into(brands).insert(entry);
  Future<bool> updateBrand(BrandEntity entry) => update(brands).replace(entry);
  Future<int> deleteBrand(int id) async {
    final brand = await (select(
      brands,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    final updated = brand.copyWith(
      isDeleted: true,
      syncStatus: 1,
      updatedAt: DateTime.now(),
    );
    final success = await update(brands).replace(updated);
    return success ? 1 : 0;
  }

  // Invoice Settings CRUD
  Future<InvoiceSettingEntity?> getInvoiceSettings() =>
      select(invoiceSettings).getSingleOrNull();

  Future<InvoiceSettingEntity?> getInvoiceSettingsForTenant(int companyId) =>
      (select(
        invoiceSettings,
      )..where((t) => t.companyId.equals(companyId))).getSingleOrNull();

  Future<int> upsertInvoiceSettings(InvoiceSettingsCompanion entry) =>
      into(invoiceSettings).insertOnConflictUpdate(entry);

  // Invoice CRUD
  Future<int> insertInvoice(InvoicesCompanion entry) =>
      into(invoices).insert(entry);
  Future<void> insertInvoiceItems(List<InvoiceItemsCompanion> entries) async {
    await batch((batch) {
      batch.insertAll(invoiceItems, entries);
    });
  }

  Future<int> createInvoiceWithItems(
    InvoicesCompanion invoice,
    List<InvoiceItemsCompanion> items,
  ) async {
    return transaction(() async {
      final id = await insertInvoice(invoice);
      final itemsWithId = items
          .map((i) => i.copyWith(invoiceId: Value(id)))
          .toList();
      await insertInvoiceItems(itemsWithId);
      return id;
    });
  }

  Future<List<InvoiceEntity>> getAllInvoices() async {
    final result = await select(invoices).get();
    return result;
  }

  Stream<List<InvoiceEntity>> watchAllInvoices() => select(invoices).watch();

  /// Returns the most recent N invoices, with their customer data.
  Future<List<TypedResult>> getTopInvoices({int limit = 5, int? companyId}) async {
    final query = select(invoices).join([
      leftOuterJoin(customers, customers.id.equalsExp(invoices.customerId)),
    ]);
    if (companyId != null) {
      query.where(invoices.companyId.equals(companyId));
    }
    query
      ..orderBy([OrderingTerm.desc(invoices.date)])
      ..limit(limit);
    return query.get();
  }

  Future<List<InvoiceItemEntity>> getInvoiceItems(int invoiceId) => (select(
    invoiceItems,
  )..where((tbl) => tbl.invoiceId.equals(invoiceId))).get();

  Future<List<TypedResult>> getInvoiceItemsWithProduct(int invoiceId) {
    final query = select(invoiceItems).join([
      innerJoin(products, products.id.equalsExp(invoiceItems.productId)),
    ])..where(invoiceItems.invoiceId.equals(invoiceId));
    return query.get();
  }

  // Joined query for history
  Stream<List<TypedResult>> watchInvoicesWithCustomer({int? companyId}) {
    final query = select(invoices).join([
      leftOuterJoin(customers, customers.id.equalsExp(invoices.customerId)),
    ]);
    if (companyId != null) {
      query.where(invoices.companyId.equals(companyId));
    }
    query.orderBy([OrderingTerm.desc(invoices.date)]);
    return query.watch();
  }

  Stream<List<TypedResult>> watchInvoiceItemsDetailed({int? companyId}) {
    final query = select(invoiceItems).join([
      innerJoin(invoices, invoices.id.equalsExp(invoiceItems.invoiceId)),
      innerJoin(products, products.id.equalsExp(invoiceItems.productId)),
      leftOuterJoin(customers, customers.id.equalsExp(invoices.customerId)),
    ]);
    if (companyId != null) {
      query.where(invoices.companyId.equals(companyId));
    }
    query.orderBy([
      OrderingTerm.desc(invoices.date),
      OrderingTerm.desc(invoiceItems.id),
    ]);
    return query.watch();
  }

  Future<List<TypedResult>> getInvoiceItemsDetailedPaginated({
    required int limit,
    required int offset,
    String? queryStr,
    int? companyId,
  }) {
    final query = select(invoices).join([
      leftOuterJoin(invoiceItems, invoiceItems.invoiceId.equalsExp(invoices.id)),
      leftOuterJoin(products, products.id.equalsExp(invoiceItems.productId)),
      leftOuterJoin(customers, customers.id.equalsExp(invoices.customerId)),
    ]);

    if (companyId != null) {
      query.where(invoices.companyId.equals(companyId));
    }

    if (queryStr != null && queryStr.isNotEmpty) {
      final q = queryStr.toLowerCase();
      query.where(
        invoices.invoiceNumber.lower().contains(q) |
            products.name.lower().contains(q) |
            customers.name.lower().contains(q),
      );
    }

    query.where(invoices.isDeleted.equals(false));

    query.orderBy([OrderingTerm.desc(invoices.date)]);

    query.limit(limit, offset: offset);

    return query.get();
  }

  Future<int> getInvoiceItemsCount({String? queryStr, int? companyId}) async {
    final countExp = invoices.id.count(distinct: true);
    final query = selectOnly(invoices)..addColumns([countExp]);

    query.join([
      leftOuterJoin(invoiceItems, invoiceItems.invoiceId.equalsExp(invoices.id)),
      leftOuterJoin(products, products.id.equalsExp(invoiceItems.productId)),
      leftOuterJoin(customers, customers.id.equalsExp(invoices.customerId)),
    ]);

    if (companyId != null) {
      query.where(invoices.companyId.equals(companyId));
    }

    if (queryStr != null && queryStr.isNotEmpty) {
      final q = queryStr.toLowerCase();
      query.where(
        invoices.invoiceNumber.lower().contains(q) |
            products.name.lower().contains(q) |
            customers.name.lower().contains(q),
      );
    }

    query.where(invoices.isDeleted.equals(false));

    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  // Clear all data from the database
  Future<void> clearAllData() async {
    debugPrint('CLEAR DB: start');

    // Delete child tables first (FK constraints), then parent tables
    // Each in try-catch to isolate failures
    try {
      await delete(invoiceItems).go();
      debugPrint('CLEAR DB: deleted invoiceItems');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on invoiceItems - $e');
    }

    try {
      await delete(invoices).go();
      debugPrint('CLEAR DB: deleted invoices');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on invoices - $e');
    }

    try {
      await delete(products).go();
      debugPrint('CLEAR DB: deleted products');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on products - $e');
    }

    try {
      await delete(tenants).go();
      debugPrint('CLEAR DB: deleted tenants');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on tenants - $e');
    }

    try {
      await delete(customers).go();
      debugPrint('CLEAR DB: deleted customers');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on customers - $e');
    }

    try {
      await delete(suppliers).go();
      debugPrint('CLEAR DB: deleted suppliers');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on suppliers - $e');
    }

    try {
      await delete(employees).go();
      debugPrint('CLEAR DB: deleted employees');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on employees - $e');
    }

    try {
      await delete(brands).go();
      debugPrint('CLEAR DB: deleted brands');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on brands - $e');
    }

    try {
      await delete(units).go();
      debugPrint('CLEAR DB: deleted units');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on units - $e');
    }

    try {
      await delete(categories).go();
      debugPrint('CLEAR DB: deleted categories');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on categories - $e');
    }

    try {
      await delete(syncMetadata).go();
      debugPrint('CLEAR DB: deleted syncMetadata');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on syncMetadata - $e');
    }

    // Clear sync cursor so the next login always pulls from epoch
    // (avoiding a stale lastSyncAt that would skip historical data).
    try {
      await delete(syncState).go();
      debugPrint('CLEAR DB: deleted syncState');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on syncState - $e');
    }

    // Clear any pending outbox entries from the previous session.
    // Unsynced local writes will be lost on logout by design (offline
    // data belongs to the session; a re-login starts fresh).
    try {
      await delete(syncOutbox).go();
      debugPrint('CLEAR DB: deleted syncOutbox');
    } catch (e) {
      debugPrint('CLEAR DB: FAILED on syncOutbox - $e');
    }

    debugPrint('CLEAR DB: completed');
  }

  Future<void> clearInvoiceData() async {
    debugPrint('CLEAR INVOICE DATA: start');
    try {
      await delete(invoiceItems).go();
      debugPrint('CLEAR INVOICE DATA: deleted invoiceItems');
    } catch (e) {
      debugPrint('CLEAR INVOICE DATA: FAILED on invoiceItems - $e');
    }
    try {
      await delete(invoices).go();
      debugPrint('CLEAR INVOICE DATA: deleted invoices');
    } catch (e) {
      debugPrint('CLEAR INVOICE DATA: FAILED on invoices - $e');
    }
    debugPrint('CLEAR INVOICE DATA: completed');
  }

  // SKU Counter methods
  Future<SkuCounterEntity?> getSkuCounter(String deviceId) async {
    return await (select(
      skuCounters,
    )..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
  }

  Future<String> getNextSku(String deviceId) async {
    return await transaction(() async {
      // Get or create counter for this device
      var counter = await getSkuCounter(deviceId);

      if (counter == null) {
        // Initialize counter for this device
        await into(skuCounters).insert(
          SkuCountersCompanion(
            prefix: const Value('SKU'),
            deviceId: Value(deviceId),
            currentNumber: const Value(1),
            updatedAt: Value(DateTime.now()),
          ),
        );
        return 'SKU-$deviceId-0001';
      }

      // Increment counter
      final nextNumber = counter.currentNumber + 1;
      final updated = counter.copyWith(
        currentNumber: nextNumber,
        updatedAt: DateTime.now(),
      );
      await update(skuCounters).replace(updated);

      // Format SKU with device ID and leading zeros (e.g., SKU-DEV1-0001)
      return '${counter.prefix}-$deviceId-${nextNumber.toString().padLeft(4, '0')}';
    });
  }

  // Reserved SKU methods
  Future<int?> getMaxSkuSequence(int companyId) async {
    final query = selectOnly(reservedSkus)
      ..addColumns([reservedSkus.sku])
      ..where(reservedSkus.companyId.equals(companyId));
    final skus = await query.map((row) => row.read(reservedSkus.sku)).get();

    if (skus.isEmpty) return null;

    int maxSeq = 0;
    for (final sku in skus) {
      if (sku == null) continue;
      final parts = sku.split('-');
      if (parts.length >= 3) {
        final seq = int.tryParse(parts.last) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    }
    return maxSeq;
  }

  Future<void> reserveSku(String sku, int companyId) async {
    await into(
      reservedSkus,
    ).insert(ReservedSkusCompanion.insert(sku: sku, companyId: companyId));
  }

  Future<bool> checkSkuExists(String sku, int companyId) async {
    final result =
        await (select(reservedSkus)
              ..where((t) => t.sku.equals(sku) & t.companyId.equals(companyId)))
            .getSingleOrNull();
    if (result != null) return true;

    // Check products table too
    final product =
        await (select(products)
              ..where((t) => t.sku.equals(sku) & t.companyId.equals(companyId)))
            .getSingleOrNull();
    return product != null;
  }

  Future<void> _seedDefaultUnits() async {
    final existingUnits = await select(units).get();
    if (existingUnits.isNotEmpty) return;

    final defaultUnits = [
      UnitsCompanion.insert(
        uuid: Uuid().v4(),
        name: 'Gram',
        symbol: 'g',
        companyId: 1,
      ),
      UnitsCompanion.insert(
        uuid: Uuid().v4(),
        name: 'Kilogram',
        symbol: 'kg',
        companyId: 1,
      ),
      UnitsCompanion.insert(
        uuid: Uuid().v4(),
        name: 'Piece',
        symbol: 'pc',
        companyId: 1,
      ),
      UnitsCompanion.insert(
        uuid: Uuid().v4(),
        name: 'Packet',
        symbol: 'pkt',
        companyId: 1,
      ),
    ];

    for (final unit in defaultUnits) {
      await into(units).insert(unit);
    }
  }
}
