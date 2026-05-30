import { pgTable, text, uuid, timestamp, serial, integer } from "drizzle-orm/pg-core";
import { companies } from "./companies";
import { invoices } from "./invoices";

export const invoiceAuditLogs = pgTable("invoice_audit_logs", {
    id: serial("id").primaryKey(),
    uuid: uuid("uuid").defaultRandom().notNull().unique(),
    invoiceId: integer("invoice_id").notNull().references(() => invoices.id),
    actionType: text("action_type").notNull(), // 'RETURN' | 'EXCHANGE' | 'DELETE' | 'NOTE_UPDATE'
    performedBy: integer("performed_by").notNull(),
    performedAt: timestamp("performed_at").defaultNow().notNull(),
    versionNumber: integer("version_number").notNull(),
    changes: text("changes").notNull(), // JSON delta
    summarySnapshot: text("summary_snapshot"), // optional lightweight snapshot
    reason: text("reason"),
    metadata: text("metadata"), // JSON
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
});

export type InvoiceAuditLog = typeof invoiceAuditLogs.$inferSelect;
export type NewInvoiceAuditLog = typeof invoiceAuditLogs.$inferInsert;
