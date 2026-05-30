import { pgTable, text, uuid, timestamp, serial, integer, doublePrecision } from "drizzle-orm/pg-core";
import { companies } from "./companies";
import { customers } from "./customers";

export const walletTransactions = pgTable("wallet_transactions", {
    id: serial("id").primaryKey(),
    uuid: uuid("uuid").defaultRandom().notNull().unique(),
    customerId: integer("customer_id").notNull().references(() => customers.id),
    amount: doublePrecision("amount").notNull(),
    type: text("type").notNull(), // 'credit' | 'debit'
    referenceType: text("reference_type").notNull(), // 'RETURN' | 'SALE'
    referenceId: integer("reference_id"),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
});

export type WalletTransaction = typeof walletTransactions.$inferSelect;
export type NewWalletTransaction = typeof walletTransactions.$inferInsert;
