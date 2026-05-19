import { pgTable, text, uuid, timestamp, serial, boolean, doublePrecision, integer, jsonb } from "drizzle-orm/pg-core";
import { companies } from "./companies";
import { suppliers } from "./suppliers";

export const purchaseReceipts = pgTable("purchase_receipts", {
    id: serial("id").primaryKey(),
    uuid: uuid("uuid").defaultRandom().notNull().unique(),
    invoiceNumber: text("invoice_number").notNull(),
    supplierInvoiceNumber: text("supplier_invoice_number"),
    supplierId: integer("supplier_id").references(() => suppliers.id),
    subtotal: doublePrecision("subtotal").default(0.0).notNull(),
    tax: doublePrecision("tax").default(0.0).notNull(),
    discount: doublePrecision("discount").default(0.0).notNull(),
    totalAmount: doublePrecision("total_amount").default(0.0).notNull(),
    notes: text("notes"),
    status: text("status").default("COMPLETED").notNull(),
    createdBy: text("created_by"),
    date: timestamp("date").defaultNow().notNull(),
    items: jsonb("items").default("[]").notNull(),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    isDeleted: boolean("is_deleted").default(false).notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export type PurchaseReceipt = typeof purchaseReceipts.$inferSelect;
export type NewPurchaseReceipt = typeof purchaseReceipts.$inferInsert;
