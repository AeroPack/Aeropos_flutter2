import { pgTable, text, uuid, timestamp, serial, boolean, integer, doublePrecision } from "drizzle-orm/pg-core";
import { companies } from "./companies";
import { invoices } from "./invoices";

export const returns = pgTable("returns", {
    id: serial("id").primaryKey(),
    uuid: uuid("uuid").defaultRandom().notNull().unique(),
    originalInvoiceId: integer("original_invoice_id").notNull().references(() => invoices.id),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    createdBy: integer("created_by").notNull(),
    refundAmount: doublePrecision("refund_amount").default(0.0).notNull(),
    refundMethod: text("refund_method").default("wallet").notNull(),
    notes: text("notes"),
    newSaleId: integer("new_sale_id"),
    restock: boolean("restock").default(true).notNull(),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    isDeleted: boolean("is_deleted").default(false).notNull(),
    updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export type Return = typeof returns.$inferSelect;
export type NewReturn = typeof returns.$inferInsert;
