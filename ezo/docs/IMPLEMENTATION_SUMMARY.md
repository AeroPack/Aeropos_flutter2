All done. Here's a summary of everything implemented:
What Changed
selection_screen.dart — Complete rewrite of filters + pagination:
- 
Format tabs (Thermal/A5/A4) now actually filter templates via filteredTemplates getter
- 
Industry chips are dynamic — derived from registered template industries
- 
Real pagination — 8 items/page, dynamic page buttons, prev/next wired, accurate counts
- 
Empty state shown when no filters match
- 
currentPage resets to 1 when any filter changes
14 templates across all format×industry combos:
Format	RETAIL	GROCERY	GARMENT	ELECTRONICS	RESTAURANT
THERMAL (58/72/80mm)	Quick Serve	Fresh Mart	StyleCraft	TechBill	DinePlus
A5	—	Grocery Saver	Fashionista	—	Bistro
A4	Design Systems + Retail Basic	Grocery Wholesale	Garment Collection	Electronics Detailed	Restaurant Pro
New files created:
- 
helpers/thermal_utils.dart — shared 58/72/80mm → points conversion
- 
templates/quick_serve_thermal_template.dart
- 
templates/dine_plus_thermal_template.dart
- 
templates/style_craft_thermal_template.dart
- 
templates/tech_bill_thermal_template.dart
- 
templates/bistro_half_page_template.dart (A5)
- 
templates/fashionista_a5_template.dart (A5)
- 
templates/grocery_saver_a5_template.dart (A5)
- 
templates/restaurant_pro_a4_template.dart (A4)
- 
templates/garment_collection_a4_template.dart (A4)
- 
templates/grocery_wholesale_a4_template.dart (A4)
- 
docs/InvoiceTemplateArchitecure.md
Files modified:
- 
fresh_mart_grocery_template.dart — updated to use thermalWidthInPoints() (now supports 72mm)
- 
template_registry.dart — registers all 14 templates
- 
editor_screen.dart — added 72mm button
Zero analysis issues — dart analyze passes clean.










Backend (TypeScript)
File	Change
backend/src/db/schema/purchase_receipts.ts	New Drizzle schema — includes items JSONB column for child line-items
backend/src/db/schema/customer_transactions.ts	New Drizzle schema
backend/src/db/schema/supplier_transactions.ts	New Drizzle schema
backend/src/db/schema/index.ts	Added 3 exports
backend/migrations/create-schema.sql	Added purchase_receipts, customer_transactions, supplier_transactions tables
backend/migrations/011_add_missing_sync_tables.sql	New migration
backend/src/validators/sync.validator.ts	Added 4 tables to VALID_TABLES, SOFT_DELETE_TABLES; added purchase_receipt_items to TABLES_WITHOUT_UPDATED_AT
backend/src/utils/uuidResolver.ts	Added UUID refs: supplier_uuid→supplier_id, receipt_uuid→receipt_id, customer_uuid→customer_id, product_uuid→product_id, unit_uuid→unit_id
backend/src/services/entityApplier.ts	Same UUID refs as uuidResolver
backend/src/db/seed.ts	Added 011_add_missing_sync_tables.sql to migration list
Flutter (Dart)
File	Change
ezo/lib/core/repositories/purchase_receipt_repository_impl.dart	Added logOperation() for all CRUD paths (insert, soft-delete, update, create-with-items, update-with-items); DB writes + log ops wrapped in db.transaction()
ezo/lib/core/repositories/customer_transaction_repository_impl.dart	Added logOperation() for add/update/delete
ezo/lib/core/repositories/supplier_transaction_repository_impl.dart	Added logOperation() for add/update/delete
ezo/lib/core/services/sync_engine.dart	Added purchase_receipts/customer_transactions/supplier_transactions cases to _deleteEntity and _upsertEntity; added _upsertPurchaseReceipt (parses items JSONB array), _upsertCustomerTransaction, _upsertSupplierTransaction handlers; fixed isLessThan → isSmallerThan(Constant(...))

















Analysis: Select POS Template Page + Layouts
1. Selection Screen (/invoice-templates) — Issues
A. Template Preview Images Are All Placeholders

selection_screen.dart:341 — Any template with previewImagePath == 'screen.png' shows a blank grey box. Most templates likely use this path. No real screenshots exist yet.
B. Hover Overlay is Always Visible (Dark Cover Never Hides)

selection_screen.dart:360-423 — The dark overlay with "Preview" and "Select template" buttons is Positioned.fill with permanent 0.6 opacity. On mobile, this covers the entire card thumbnail all the time. It should only appear on hover/tap.
C. "Select Template" Goes to Editor, Not Direct Activation

selection_screen.dart:398 — widget.onEdit(template.id) takes the user to the editor screen. There's no one-click "Use this template" that saves it without going into the editor. For a shop owner who just wants to pick a template, this is a friction point.
D. Active Template Indicator is Hidden Under the Dark Overlay

selection_screen.dart:313-328 — isCurrentlyActive only changes the border color (blue vs grey), but the dark overlay completely covers the card, so the border is invisible. No "ACTIVE" badge is shown on the selected template.
E. Industry Filter Comparison is Case-Sensitive and Fragile

selection_screen.dart:51 — t.industry == activeIndustry.toUpperCase(). If any template stores industry in mixed case, the filter silently breaks.
F. Preview Modal Has No "Select This Template" CTA

selection_screen.dart:630-772 — The image preview modal only has a "Close" button. After previewing a template, the user has to close and then click "Select template" on the card. A "Use This Template" button should be inside the modal.
G. Preview Modal Shows Generic Title, Not Template Name

selection_screen.dart:729 — Always says "Template Preview" / "Industry specialized layout" regardless of which template is being previewed.
2. RetailLayout — Production Issues
A. Invoice Reference Number is Ephemeral and Rebuilds Every Frame

retail_layout.dart:266 and retail_layout.dart:808 — DateTime.now().millisecondsSinceEpoch.toString().substring(5) generates a new ref every rebuild. It's not a real persistent invoice number.
B. All Header Icons Are No-Ops

retail_layout.dart:234-238 — Refresh, Print, Settings buttons all have onPressed: () {}. Nav items "Orders", "Customers", "Reports" have no navigation.
C. Missing Discount Line in Totals

retail_layout.dart:280-296 — The totals sidebar shows Subtotal → Tax → Charges → Total, but no overall discount line. Cart does support setOverallDiscount but it's not surfaced in the UI.
D. InvoiceData Missing Critical GST Fields

models.dart:47-101 — The InvoiceData model has a single taxRate for the entire invoice. For Indian GST compliance, invoices need:
CGST / SGST / IGST breakdown (separate amounts)
Per-item HSN/SAC codes
Per-item tax rates (items can be 0%, 5%, 12%, 18%, 28%)
Customer GSTIN (for B2B transactions)
E. No "Amount in Words" Field

Standard Indian invoices require the total amount written in words (e.g., "Rupees One Thousand Two Hundred Only"). Missing from InvoiceData model and all templates.
F. No Bank Details / UPI QR Code

Missing from InvoiceData. Essential for bank transfer payments (which is a payment option in the modal at retail_layout.dart:800-804).
3. CompactLayout — Production Issues
A. Notes Are Silently Lost

compact_layout.dart:48 / compact_layout.dart:1319-1342 — _notesController text is never read or passed to cart state or invoice. Users who type order notes lose them on checkout.
B. Favorites Are In-Memory Only

compact_layout.dart:54 — _favoriteProductIds is a Set<int> in widget state. Lost on every app restart or layout switch.
C. Split/Print/Hold/Recall Buttons Show No Disabled State

compact_layout.dart:1357-1375 — When onSplitBill, onPrintReceipt, onOrderHold, onRecallOrder are null, _compactQuickAction silently does nothing. No visual indication they are unimplemented.
D. Payment Method Not Passed from TotalsDisplay Checkout

compact_layout.dart:479 — PosTotalsDisplay.onCheckout: () => widget.onCheckout(shouldSave: true) — doesn't pass _selectedPaymentMethod. Payment selection chips are cosmetic only for this code path.
E. Dead Code (// ignore: unused_element)

compact_layout.dart:895 and compact_layout.dart:1058 — _buildCustomerSearchPanel() and _compactCustomerOption() are never called. Customer search panel is unused in the final layout.
4. Missing Data for Professional Shop Invoices
These fields are expected on any Indian retail billing/invoice but are absent from InvoiceData:

Missing Field	Impact
clientPhone / clientEmail	Can't show customer contact on invoice
clientGstin	B2B invoices legally require buyer's GSTIN
Sequential invoice number	Legally required; currently ephemeral
Invoice date (as explicit field)	Not stored; implied by system time
Due date / payment terms	Missing
Per-item HSN/SAC code	GST compliance requirement
Per-item tax rate (CGST/SGST/IGST)	GST compliance requirement
totalDiscount (invoice-level)	Not surfaced in UI or model
Round-off amount	Standard in Indian invoices
Amount in words	Standard in Indian invoices
Authorized signatory / seal	Standard compliance
Terms and conditions	Standard professional invoice
Summary Priority
Must-fix before production:

Real preview images for all templates
InvoiceData — add per-item HSN, CGST/SGST/IGST breakdown, client phone, sequential invoice number
Notes passing from CompactLayout to cart/invoice
Payment method passed through both checkout paths in CompactLayout
Active template badge visible on selection screen
High priority:
6. Selection screen overlay only on hover
7. "Use this template" in preview modal
8. Favorites persisted to DB
9. Retail layout header buttons wired up
10. Discount line in totals

























selection_screen.dart — done

_previewTemplate: InvoiceTemplate? replaces previewImage throughout
Preview modal now shows template name + format info instead of generic "Template Preview"
"Use This Template" CTA button in modal calls _activateTemplate
Hover overlay with Preview / Use Template / Customize buttons
ACTIVE badge visible without hover; industry filter is case-insensitive
retail_layout.dart — done

_invoiceRef set once in initState (no regeneration per rebuild)
Modal's _invoiceRef likewise set in _RetailInvoiceModalState.initState
Nav items Orders / Customers / Reports wired to context.go('/sales-history'), '/customers', '/reports'
Settings IconButton wired to widget.onOpenInvoiceSettings
DISCOUNT line added to both sidebar totals and modal totals section
compact_layout.dart — done

Both PosTotalsDisplay.onCheckout calls now pass paymentMethod: _selectedPaymentMethod
_compactQuickAction renders greyed-out icon + label when onTap == null
Notes TextField wires onChanged to widget.cartNotifier.setNotes

































Plan: POS Template & Layout Fixes
Phase 1 — Selection Screen (selection_screen.dart)
1A. Fix preview image fallback (line 341)
- 
The 'screen.png' sentinel is never actually used by any template — all 14 templates have real previewImagePath values (local assets or Unsplash URLs). However, FreshMartGroceryTemplate and others reference local assets like assets/images/templates/fresh_mart_preview.png which may not exist.
- 
Fix: Add a fallback: if Image.asset/Image.network's errorBuilder fires, show a styled placeholder with the template name and a camera icon instead of a blank grey box. Remove the 'screen.png' special case.
1B. Hover overlay toggle (lines 360-423)
- 
Change Positioned.fill overlay to appear only when the card is hovered (desktop via MouseRegion) or tapped to reveal (mobile via GestureDetector on the card).
- 
Add a _revealedCardId state variable. On desktop MouseRegion(onEnter/onExit), on mobile GestureDetector(onTap) on the card thumbnail.
- 
When not revealed, the card shows the clean preview image with badges on top.
- 
The overlay should have a subtle close mechanism on mobile (tap outside or a close X).
1C. Add "Use this template" direct activation (lines 397-418)
- 
Add a second button: "Use this template" that calls saveTemplateSelection(tenantId, templateId) to directly set the active template in the DB (via template_repository.dart:saveTemplateSelection).
- 
Rename current button to "Edit in editor".
- 
Creates a direct activation path, skipping the editor.
1D. Active template badge (lines 311-328)
- 
Add a visible "ACTIVE" badge overlaid at top-right of the card for isCurrentlyActive.
- 
Move active indicator from border-only to a prominent badge (e.g., green pill with white text).
- 
The badge should render above the dark overlay so it's always visible.
1E. Case-insensitive industry filter (line 51)
- 
Change t.industry == activeIndustry.toUpperCase() to t.industry.toUpperCase() == activeIndustry.toUpperCase().
- 
Also normalize chip labels: display t.industry capitalized (e.g., "Grocery") while keeping comparison case-insensitive.
1F. "Use This Template" in preview modal (lines 630-772)
- 
Add an ElevatedButton("Use This Template") next to the Close button in the modal footer (line 746 area).
- 
This button calls saveTemplateSelection() directly (like 1C).
1G. Dynamic modal title (lines 728-742)
- 
Replace hardcoded 'Template Preview' / 'Industry specialized layout' with template.name and "${template.industry} | ${template.styleName}".
- 
Need to pass or retrieve the current template in the preview state.
Phase 2 — InvoiceData Model (models.dart)
Add to InvoiceData (lines 47-101):
New Field	Type	Default	Purpose
invoiceNumber	String	'INV-001'	Sequential invoice number
invoiceDate	DateTime	DateTime.now()	Explicit invoice date
dueDate	DateTime?	null	Due date / payment terms
clientPhone	String	''	Customer phone
clientEmail	String	''	Customer email
clientGstin	String	''	Customer GSTIN (B2B)
totalDiscount	double	0.0	Invoice-level discount amount
totalDiscountLabel	String	'Discount'	Display label
roundOff	double	0.0	Round-off amount
amountInWords	String	''	Auto-generated amount in words
bankName	String	''	Bank name
bankAccountNo	String	''	Bank account number
bankIfsc	String	''	IFSC code
upiId	String	''	UPI ID
termsAndConditions	String	''	Terms & conditions text
authorizedSignatory	String	''	Signatory name
Extend InvoiceItem (lines 29-45):
New Field	Type	Default	Purpose
hsnCode	String	''	HSN/SAC code (GST)
cgstRate	double	0.0	CGST rate %
sgstRate	double	0.0	SGST rate %
igstRate	double	0.0	IGST rate % (inter-state)
discount	double	0.0	Per-item discount
taxableValue	double	computed	Pre-tax amount
Add computed getters to InvoiceData:
- 
cgstTotal / sgstTotal / igstTotal — summed from items
- 
grandTotal — total + roundOff
- 
generateAmountInWords() helper method
Phase 3 — Retail Layout (retail_layout.dart)
3A. Persistent invoice numbering
- 
Replace ephemeral DateTime.now().millisecondsSinceEpoch with a DB counter (e.g., add invoiceNumberCounter to tenant settings or a standalone table).
- 
On new sale, increment and format as INV-2026-00001.
3B. Wire header buttons (lines 234-236)
- 
Refresh: Call ServiceLocator.instance.syncEngine.pull().
- 
Print: Trigger the invoice modal directly with print action.
- 
Settings: Call widget.onOpenInvoiceSettings().
- 
Nav items (Orders, Customers, Reports): Wire to respective screens via context.go() or callbacks.
3C. Add discount line (lines 281-286)
- 
Insert if (widget.cartState.totalDiscount > 0) _totalLine("DISCOUNT", ...) between subtotal and tax.
- 
Same for the invoice modal totals section.
Phase 4 — Compact Layout (compact_layout.dart)
4A. Pass notes through checkout (line 48, 1318-1342)
- 
Add notes parameter to the checkout callback: widget.onCheckout(shouldSave: true, notes: _notesController.text).
- 
In PosScreen._handleCheckout, accept notes and pass to Sale(notes: notes) and invoiceData.notes = notes.
4B. Persist favorites (line 54)
- 
Replace Set<int> with a DB-backed approach: add a favorite_products table (product_id, tenant_id) or use a simple JSON field in tenant settings.
- 
Load on init, save on toggle.
4C. Disabled state for quick actions (lines 1382-1423)
- 
When onTap is null, reduce opacity to 0.4, add Icon(Icons.block) overlay or grey out.
- 
Add tooltip text like "Coming soon" when null.
4D. Pass payment method from PosTotalsDisplay (lines 267-272, 478-482)
- 
Change the PosTotalsDisplay.onCheckout callbacks to pass _selectedPaymentMethod:
onCheckout: () => widget.onCheckout(shouldSave: true, paymentMethod: _selectedPaymentMethod)
4E. Remove dead code (lines 895, 1058)
- 
Remove _buildCustomerSearchPanel() (lines 896-1057) and _compactCustomerOption() (lines 1058+).
Phase 5 — Template Updates & Support
5A. Update getHydratedInvoiceData (template_repository.dart:132-185)
- 
Read and populate new fields: bank details, UPI ID, terms, authorized signatory from a new invoice_settings column or a new tenant_bank_details table.
- 
Read customer data: phone, email, gstin from CustomerEntity (add gstin column to customers_table.dart).
5B. Add gstin to CustomerEntity (customers_table.dart)
- 
Add String? gstin column to the customers table.
- 
Update the CustomerFormDialog to include a GSTIN field.
5C. Create amount-in-words utility
- 
Create ezo/lib/core/utils/number_to_words.dart with a convertToIndianRupees(double amount) function.
- 
Use it in InvoiceData computed getter or at checkout time.
Phase 6 — Shopping Cart / State
6A. Add notes to CartState (cart_state.dart)
- 
Add String notes field, with a setter in CartNotifier.
6B. Sequential invoice counter
- 
Add an invoice_counter table or a field in tenants / invoice_settings.
- 
Atomically increment on each sale creation.
- 
Format as INV-YYYY-NNNNN.
Recommended order of execution: Phase 1 → Phase 2 → Phase 6 → Phase 3 → Phase 4 → Phase 5 (Phase 5 depends on Phase 2 model changes).







































Understood. Here's the refined execution plan based on your status:
Final Execution Plan
Phase 2 — InvoiceData + InvoiceItem model fields (HIGHEST PRIORITY)
File: ezo/lib/features/invoice/invoice_template_editor/models.dart
Add to InvoiceData:
- 
invoiceNumber, invoiceDate, dueDate
- 
clientPhone, clientEmail, clientGstin
- 
totalDiscount, totalDiscountLabel, roundOff, amountInWords
- 
bankName, bankAccountNo, bankIfsc, upiId
- 
termsAndConditions, authorizedSignatory
Add to InvoiceItem:
- 
hsnCode, cgstRate, sgstRate, igstRate, discount
Add computed getters: cgstTotal, sgstTotal, igstTotal, grandTotal
Also update the InvoiceData constructor call sites that will break (check all getDefaultData() in 14 templates + getHydratedInvoiceData in template_repository.dart + pos_screen.dart:_handleCheckout).
Phase 4E — Delete dead code (easy win)
File: ezo/lib/features/pos/layouts/compact_layout.dart
- 
Remove _buildCustomerSearchPanel() (~lines 896-1057)
- 
Remove _compactCustomerOption() (~lines 1058+)
- 
Remove the // ignore: unused_element annotations
- 
Remove the customerSearchProvider and posCustomerListProvider refs if they become unused
Phase 6B — Invoice counter
File: New migration / table
- 
Add invoiceCounter column to tenants table (or new tenant_sequence table)
- 
Create a service method: getNextInvoiceNumber(tenantId) that atomically increments
- 
Format: INV-{year}-{padded counter} (e.g., INV-2026-00042)
Phase 5A/5B/5C — Support infrastructure
5A — getHydratedInvoiceData (template_repository.dart)
- 
Populate new fields: bank details from tenant/settings, UPI ID, terms, authorized signatory
- 
Read customer phone/email from CustomerEntity and set on InvoiceData
5B — Customer GSTIN (customers_table.dart)
- 
Add String? gstin column to CustomerEntity
- 
Update CustomerFormDialog to accept/edit GSTIN
- 
Update in pos_screen.dart:_handleCheckout: set invoiceData.clientGstin = selectedCustomer.gstin
5C — Amount in words utility
- 
Create ezo/lib/core/utils/number_to_words.dart
- 
Implement convertToIndianRupees(double amount) for Indian numbering system (lakh/crore)
- 
Wire into checkout flow or compute lazily in InvoiceData
Phase 3A/3B — Retail layout remaining
3A — Persistent invoice counter
- 
Replace DateTime.now().millisecondsSinceEpoch in retail_layout.dart:266 and retail_layout.dart:808 with the DB counter from 6B
- 
Also update pos_screen.dart:108 where Sale.invoiceNumber is set
3B — Wire Refresh + Print buttons (retail_layout.dart:234-235)
- 
Refresh: ServiceLocator.instance.syncEngine.pull()
- 
Print: Trigger the checkout/invoice modal
Phase 1A — Polish (low priority)
- 
Replace errorBuilder in selection_screen.dart:348 with styled camera-icon placeholder
- 
Remove dead 'screen.png' sentinel (line 341)
Would you like me to begin implementing Phase 2?