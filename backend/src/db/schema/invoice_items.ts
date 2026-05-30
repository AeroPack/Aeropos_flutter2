import { pgTable, text, uuid, timestamp, serial, boolean, doublePrecision, integer } from "drizzle-orm/pg-core";
import { invoices } from "./invoices";
import { products } from "./products";
import { companies } from "./companies";

export const invoiceItems = pgTable("invoice_items", {
    id: serial("id").primaryKey(),
    uuid: uuid("uuid").defaultRandom().notNull().unique(),
    invoiceId: integer("invoice_id").references(() => invoices.id),
    productId: integer("product_id").references(() => products.id),
    quantity: integer("quantity").notNull(),
    bonus: integer("bonus").default(0).notNull(),
    unitPrice: doublePrecision("unit_price").notNull(),
    returnedQuantity: doublePrecision("returned_quantity").default(0.0).notNull(),
    discount: doublePrecision("discount").default(0.0).notNull(),
    totalPrice: doublePrecision("total_price").notNull(),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    isDeleted: boolean("is_deleted").default(false).notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export type InvoiceItem = typeof invoiceItems.$inferSelect;
export type NewInvoiceItem = typeof invoiceItems.$inferInsert;
