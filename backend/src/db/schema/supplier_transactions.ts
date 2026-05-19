import { pgTable, text, uuid, timestamp, serial, boolean, doublePrecision, integer } from "drizzle-orm/pg-core";
import { companies } from "./companies";
import { suppliers } from "./suppliers";

export const supplierTransactions = pgTable("supplier_transactions", {
    id: serial("id").primaryKey(),
    uuid: uuid("uuid").defaultRandom().notNull().unique(),
    supplierId: integer("supplier_id")
        .notNull()
        .references(() => suppliers.id),
    amount: doublePrecision("amount").notNull(),
    type: text("type").notNull(),
    remarks: text("remarks"),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    isDeleted: boolean("is_deleted").default(false).notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export type SupplierTransaction = typeof supplierTransactions.$inferSelect;
export type NewSupplierTransaction = typeof supplierTransactions.$inferInsert;
