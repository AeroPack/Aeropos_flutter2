import { pgTable, text, timestamp, serial, boolean, doublePrecision, integer } from "drizzle-orm/pg-core";
import { companies } from "./companies";

export const invoiceSettings = pgTable("invoice_settings", {
    id: serial("id").primaryKey(),
    businessName: text("business_name").notNull(),
    layout: text("layout").notNull(),
    footerMessage: text("footer_message").notNull(),
    accentColor: text("accent_color").notNull(),
    fontFamily: text("font_family").notNull(),
    fontSizeMultiplier: doublePrecision("font_size_multiplier").notNull(),
    logoPath: text("logo_path"),
    logoLocalPath: text("logo_local_path"),
    logoBytes: text("logo_bytes"),
    thermalWidth: integer("thermal_width").default(80).notNull(),
    showLogo: boolean("show_logo").default(true).notNull(),
    showTaxBreakdown: boolean("show_tax_breakdown").default(true).notNull(),
    showAddress: boolean("show_address").default(true).notNull(),
    showCustomerDetails: boolean("show_customer_details").default(true).notNull(),
    showFooter: boolean("show_footer").default(true).notNull(),
    showBankDetails: boolean("show_bank_details").default(false).notNull(),
    showUpiQr: boolean("show_upi_qr").default(false).notNull(),
    bankName: text("bank_name"),
    bankAccountNo: text("bank_account_no"),
    bankIfsc: text("bank_ifsc"),
    upiId: text("upi_id"),
    businessPhone: text("business_phone"),
    businessAddress: text("business_address"),
    businessGstin: text("business_gstin"),
    customConfig: text("custom_config"),
    taxLabel: text("tax_label"),
    taxRate: doublePrecision("tax_rate"),
    termsAndConditions: text("terms_and_conditions"),
    authorizedSignatory: text("authorized_signatory"),
    invoiceCounter: integer("invoice_counter").default(0).notNull(),
    invoicePrefix: text("invoice_prefix").default("INV").notNull(),
    companyId: integer("company_id")
        .notNull()
        .references(() => companies.id, { onDelete: "cascade" }),
    updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export type InvoiceSettings = typeof invoiceSettings.$inferSelect;
export type NewInvoiceSettings = typeof invoiceSettings.$inferInsert;
