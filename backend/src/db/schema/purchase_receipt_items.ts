import { pgTable, timestamp, serial, boolean, integer, doublePrecision } from "drizzle-orm/pg-core";
import { companies } from "./companies";
import { purchaseReceipts } from "./purchase_receipts";
import { products } from "./products";
import { units } from "./units";

export const purchaseReceiptItems = pgTable("purchase_receipt_items", {
    id: serial("id").primaryKey(),
    receiptId: integer("receipt_id").notNull().references(() => purchaseReceipts.id),
    productId: integer("product_id").notNull().references(() => products.id),
    quantity: doublePrecision("quantity").notNull(),
    unitId: integer("unit_id").notNull().references(() => units.id),
    price: doublePrecision("price").notNull(),
    totalPrice: doublePrecision("total_price").notNull(),
    discountPerItem: doublePrecision("discount_per_item"),
    taxPerItem: doublePrecision("tax_per_item"),
    isDeleted: boolean("is_deleted").default(false).notNull(),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
});

export type PurchaseReceiptItem = typeof purchaseReceiptItems.$inferSelect;
export type NewPurchaseReceiptItem = typeof purchaseReceiptItems.$inferInsert;
