import { pgTable, text, timestamp, serial, boolean, integer } from "drizzle-orm/pg-core";
import { companies } from "./companies";

export const reservedSkus = pgTable("reserved_skus", {
    id: serial("id").primaryKey(),
    sku: text("sku").notNull().unique(),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    isUsed: boolean("is_used").default(false).notNull(),
    reservedAt: timestamp("reserved_at").defaultNow().notNull(),
    usedAt: timestamp("used_at"),
});

export type ReservedSku = typeof reservedSkus.$inferSelect;
export type NewReservedSku = typeof reservedSkus.$inferInsert;
