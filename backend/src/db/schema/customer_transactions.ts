import { pgTable, text, uuid, timestamp, serial, boolean, doublePrecision, integer } from "drizzle-orm/pg-core";
import { companies } from "./companies";
import { customers } from "./customers";

export const customerTransactions = pgTable("customer_transactions", {
    id: serial("id").primaryKey(),
    uuid: uuid("uuid").defaultRandom().notNull().unique(),
    customerId: integer("customer_id")
        .notNull()
        .references(() => customers.id),
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

export type CustomerTransaction = typeof customerTransactions.$inferSelect;
export type NewCustomerTransaction = typeof customerTransactions.$inferInsert;
