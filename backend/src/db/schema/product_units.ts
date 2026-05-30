import { pgTable, text, uuid, timestamp, serial, boolean, integer, doublePrecision } from "drizzle-orm/pg-core";
import { products } from "./products";
import { units } from "./units";
import { companies } from "./companies";

export const productUnits = pgTable("product_units", {
    id: serial("id").primaryKey(),
    uuid: uuid("uuid").defaultRandom().notNull().unique(),
    productId: integer("product_id").notNull().references(() => products.id),
    unitId: integer("unit_id").notNull().references(() => units.id),
    conversionFactor: doublePrecision("conversion_factor").default(1.0).notNull(),
    sellingPrice: doublePrecision("selling_price"),
    barcode: text("barcode"),
    isDefault: boolean("is_default").default(false).notNull(),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    isDeleted: boolean("is_deleted").default(false).notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export type ProductUnit = typeof productUnits.$inferSelect;
export type NewProductUnit = typeof productUnits.$inferInsert;
