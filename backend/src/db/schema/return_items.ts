import { pgTable, text, uuid, timestamp, serial, boolean, integer, doublePrecision } from "drizzle-orm/pg-core";
import { companies } from "./companies";
import { returns } from "./returns";
import { products } from "./products";

export const returnItems = pgTable("return_items", {
    id: serial("id").primaryKey(),
    uuid: uuid("uuid").defaultRandom().notNull().unique(),
    returnId: integer("return_id").notNull().references(() => returns.id),
    productId: integer("product_id").notNull().references(() => products.id),
    quantity: doublePrecision("quantity").notNull(),
    unitPrice: doublePrecision("unit_price").notNull(),
    condition: text("condition").default("good").notNull(),
    restock: boolean("restock").default(true).notNull(),
    originalInvoiceItemId: integer("original_invoice_item_id"),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
});

export type ReturnItem = typeof returnItems.$inferSelect;
export type NewReturnItem = typeof returnItems.$inferInsert;
