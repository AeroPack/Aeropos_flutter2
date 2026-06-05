import { Pool } from "pg";
import fs from "fs";
import path from "path";

export async function runMigrations() {
  console.log("Running sync migrations...");
  
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL || "postgresql://postgres:test123@localhost:5435/mydb",
  });

  try {
    const migrationFiles = [
      "001_sync_core.sql",
      "002_uuid_constraints.sql",
      "003_soft_delete_columns.sql",
      "004_tenants_and_company_hierarchy.sql",
      "005_operations_log.sql",
      "006_tenants_is_deleted.sql",
      "007_backfill_sync_operations.sql",
      "008_sync_notify_trigger.sql",
      "009_ops_log_archive.sql",
      "010_products_hsn_column.sql",
      "011_add_missing_sync_tables.sql",
      "012_add_payment_method_to_invoices.sql",
      "013_create_product_units.sql",
      "015_full_schema_sync_alignment.sql",
      "016_add_notes_to_invoices.sql",
      "017_fix_company_tenant_id.sql",
    ];

    for (const file of migrationFiles) {
      console.log(`Applying ${file}...`);
      try {
        const sqlPath = path.join(process.cwd(), "migrations", file);
        const sql = fs.readFileSync(sqlPath, "utf-8");
        // Send the whole file as one query — simple-query protocol supports
        // multiple statements. Splitting by ";" breaks dollar-quoted bodies
        // and any semicolons that appear inside SQL comments.
        await pool.query(sql);
        console.log(`✓ ${file} applied successfully`);
      } catch (error) {
        console.error(`Error applying ${file}:`, error);
      }
    }
    
    console.log("Sync migrations complete!");
  } catch (error) {
    console.error("Migration failed:", error);
  } finally {
    await pool.end();
  }
}

runMigrations().catch(console.error);