import { pgTable, text, uuid, timestamp, serial, integer, doublePrecision } from "drizzle-orm/pg-core";
import { companies } from "./companies";
import { products } from "./products";

export const inventoryMovements = pgTable("inventory_movements", {
    id: serial("id").primaryKey(),
    uuid: uuid("uuid").defaultRandom().notNull().unique(),
    productId: integer("product_id").notNull().references(() => products.id),
    quantity: doublePrecision("quantity").notNull(),
    type: text("type").notNull(), // 'SALE' | 'RETURN' | 'ADJUSTMENT'
    referenceId: integer("reference_id"),
    performedBy: integer("performed_by"),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
});

export type InventoryMovement = typeof inventoryMovements.$inferSelect;
export type NewInventoryMovement = typeof inventoryMovements.$inferInsert;
