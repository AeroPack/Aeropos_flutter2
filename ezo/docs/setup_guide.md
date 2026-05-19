Thought: The user is asking me to explore the codebase more thoroughly to find other potential issues that could cause problems later, similar to the memory/storage issues I've already addressed. This is a read-only exploration task. Let me use task agents to explore different aspects of the codebase in parallel.
Let me think about what kinds of issues to look for:
1. Performance issues (besides what we already fixed)
2. Memory leaks or improper disposal patterns
3. Thread safety / async issues
4. Error handling gaps
5. Security concerns
6. Architecture anti-patterns
7. Unused/dead code
8. Potential crashes
9. Database query issues
10. State management problems
Let me launch several exploration agents in parallel to cover different areas.
│ Explore Task — Explore state management issues
└ 112 toolcalls · 6m 8s
│ Explore Task — Explore database and sync issues
└ 61 toolcalls · 5m 21s
│ Explore Task — Explore widget and rendering issues
└ 89 toolcalls · 5m 49s
ctrl+x down view subagents
Thought: The three exploration agents found a LOT of issues. Let me compile them into a prioritized, actionable plan. The user asked me to "find similar more things in the codebase that can cause issues later", so I should present the findings in an organized way.
Let me combine the findings from all three agents, deduplicate where needed, and prioritize them.
Key categories of issues found:
HIGH SEVERITY — Immediate risk:
1. 3x TextEditingController leaks (no dispose)
2. 3x setState after await without mounted check
3. CartNotifier unbounded cache (product units never evicted)
4. Stock deduction without transaction (race condition)
5. Sync engine push failures silently swallowed (partial data loss)
6. 9x Image.network() without caching
7. 2x Column(.map()) in scrollable views (unbounded height)
MEDIUM SEVERITY — Should fix:
8. Duplicate HeldOrdersNotifier classes
9. Several StateNotifiers without dispose()
10. MediaQuery.of(context) in nested builds (26 locations)
11. GoRouter navigation without duplicate-route guards
12. Large build methods (>100 lines, 30+ locations)
13. Fire-and-forget sync calls in POS initState
14. InventoryService read-then-write without transaction
15. clearAllData() without transaction (partial cleanup on crash)
16. Downloading temp files never cleaned up
17. SSE client unbounded reconnection
18. Non-standard UUID generation in return_service
19. Deprecated sync_service still in binary
LOW SEVERITY — Watch items:
20. dart:io imports without web guards
21. keyboard handling gaps
22. Image.file() without error handling
23. Token verification logged to console
24. print() statements in production code (many, pre-existing)
25. Various silent catch blocks
Let me present this in a clear format.
Excellent findings from the exploration. Here's a consolidated, prioritized list of issues beyond what we already fixed:
Additional Issues Found — Prioritized
🔴 HIGH SEVERITY (Fix ASAP)
#	Issue	Location(s)	Why It Matters
1	3x TextEditingController leaks — no dispose() at all	add_customer_ledger.dart, add_supplier_ledger.dart, invoice_settings_screen.dart	Guaranteed memory leak every time screen opens
2	3x setState after await without mounted check	settings_screen.dart:53, editor_screen.dart:449, employee_list_screen.dart:486	Crashes with "setState called after dispose" on async gap
3	Stock deduction race condition — read-then-write without transaction	inventory_service.dart:9-28	Two POS terminals can sell same stock — loses sales
4	Sync engine push failures silently dropped — failed batch never retried	sync_engine.dart:353-368	Partial data loss — some outbox entries vanish
5	CartNotifier _productUnitsCache — no eviction, no autoDispose	cart_state.dart:187-204,460-462	Grows unboundedly over long POS sessions
6	9x Image.network() without caching	Templates, profiles, company picker	Every rebuild re-downloads — bandwidth + jank
7	2x Column(children: .map()) instead of lazy ListView.builder	grocery_wholesale_a4_template.dart:179, restaurant_pro_a4_template.dart:171	All invoice items built eagerly — OOM risk on large invoices
🟡 MEDIUM SEVERITY (Should Fix)
#	Issue	Location(s)
8	Duplicate HeldOrdersNotifier — identical class in two files	sales/screens/pos_screen.dart, pos/pos_screen.dart
9	Multiple StateNotifiers without dispose() — AuthController, ProfileController, ReturnSettingsNotifier, PosLayoutNotifier	4 files
10	Deprecated SyncService still ships in binary — multiple silent catch blocks	core/services/sync_service.dart
11	Non-standard UUID generation — timestamp-based, can collide	return_service.dart:13-14
12	clearAllData() without transaction — partial cleanup on crash	app_database.dart:968-1070
13	Image temp files never cleaned up — accumulate on disk	product_view_model.dart:267-278
14	SSE client unbounded reconnection — retries forever	sse_client.dart:99-119
15	Fire-and-forget sync in POS initState — errors swallowed	pos_screen.dart:97
16	26x MediaQuery.of(context) in nested builds — causes full subtree rebuilds	13+ files
17	12+ context.go() without duplicate-route guard — unnecessary navigation events	app_shell.dart
18	Empty catch block in company_switcher.dart — completely invisible errors	company_switcher.dart:15
19	30+ build methods >100 lines — worst: master_header.dart (404 lines), add_product_screen.dart (416 lines)	30+ files
🟢 LOW SEVERITY (Watch / Incremental)
#	Issue	Notes
20	7 files import dart:io without web guard	Not yet crashing, but will fail if web target is built
21	Admin/delete dialogs fire onConfirm without await	double-click risk
22	x-auth-token header instead of Authorization: Bearer	intentional but fragile
23	Various silent catch blocks in repositories (return null on any error)	hides real DB issues
24	print() in production code across ~40 locations	pre-existing, clutter only
Recommended Order
Immediate (release-blocking):
1. 
Fix the 3 mounted-check crashes (#2)
2. 
Wrap stock deduction in a database transaction (#3)
3. 
Add dispose() to 3 screens with leaked controllers (#1)
4. 
Apply autoDispose + eviction to CartNotifier cache (#5)
This sprint (next batch):
5. Fix sync engine push-failure handling (#4)
6. Replace Image.network() with CachedNetworkImage (#6)
7. Convert Column(.map()) to ListView.builder (#7)
Next sprint:
8. Consolidate duplicate HeldOrdersNotifier (#8)
9. Add disposal to remaining StateNotifiers (#9)
10. Remove deprecated SyncService from binary (#10)
The full list touches ~50 unique files. Would you like me to create detailed implementation plans for specific items from this list?
▣  Plan · DeepSeek V4 Flash Free · 6m 57s
Thought: I need to create an anchored summary from the conversation history. Let me review the entire conversation to extract the key information.
The conversation started with the user asking about where Flutter stores data (RAM vs disk). Then they asked about performance implications of watch() queries on low-RAM devices. Then they asked for a plan to fix the issues, and then told me to proceed with implementation. Finally, they asked me to find more similar issues in the codebase.
I now have the results from the 3 exploration agents that found other issues. Let me create a comprehensive summary.
Let me organize this carefully:
1. Goal: The task is to optimize Flutter app memory and performance, and identify other potential issues
2. The user's refinements to the original plan were incorporated
3. Implementation was done for Steps 1-5 and 7
4. The exploration found additional issues across state management, database/sync, and widget/rendering
Let me write the summary.
Goal
- 
Optimize Flutter app memory, data storage, and query patterns to prevent performance degradation on low-RAM devices, then audit codebase for additional issues.
Constraints & Preferences
- 
.watch() (reactive streams) reserved for small live datasets only; paginated lists use .get() (one-time reads)
- 
POS search must use SQL-level filtering (not client-side .where() on full Dart lists) with 300ms debounce
- 
Dashboard should not watch full invoice joins for KPIs; use aggregation queries or top-N reads
- 
autoDispose added to all Riverpod providers except critical auth/cart singletons
- 
SQL indexes added before scaling filtered queries to avoid trading RAM problems for CPU problems
Progress
Done
- 
Step 1 — InventoryDashboard memory leak: 3 uncancelled .listen() subscriptions fixed, products switched to one-time .get(), subscriptions cancelled in dispose()
- 
Step 2 — POS search SQL + debounce: posProductListProvider and posCustomerListProvider converted to SQL filtering via getFilteredProducts()/getFilteredCustomers(), 300ms Timer debounce, .autoDispose added. categoryStreamProvider also got .autoDispose.
- 
Step 3 — Dashboard aggregation: removed salesListStreamProvider (full invoice watch) from dashboard, replaced with _RecentTransactions StatefulWidget calling db.getTopInvoices(limit:5). salesStatsProvider and salesListStreamProvider got .autoDispose.
- 
Step 4 — getPagedProducts(), getPagedCustomers(), getTopInvoices() added to AppDatabase for paginated reads.
- 
Step 5 — Schema version bumped to 44, 9 SQL indexes added (products name/sku/category/tenant, customers name/phone, invoices date/tenant/customer) in both onCreate and onUpgrade.
- 
Step 7 — .autoDispose added to invoiceProvider, productListProvider, customerListProvider, invoiceHistoryProvider, detailedInvoiceItemsProvider, salesHistoryProvider, activeTemplateProvider.
- 
Exploration pass — Three sub-agents audited state management, database/sync, and widget/rendering issues. Full list of findings returned.
In Progress
- 
(none)
Blocked
- 
(none)
Key Decisions
- 
.watch() with .limit()/.offset() avoided for paginated lists — paginated watch can cause flickering/duplicate rows when ordering shifts. One-time .get() is safer for POS systems.
- 
autoDispose applied to all non-critical providers — does not fully solve memory under StatefulShellRoute (branches stay alive), but helps for screens navigated outside the shell.
- 
getSalesAggregates() removed from AppDatabase due to Drift type resolution issues with .isAfter()/.isBefore() on GeneratedColumn. Dashboard continues using existing salesStatsProvider.
Next Steps
- 
Fix 3 missing dispose() overrides in add_customer_ledger.dart, add_supplier_ledger.dart, invoice_settings_screen.dart (TextEditingControllers leaked)
- 
Fix 3 setState after await without mounted check in settings_screen.dart:53, editor_screen.dart:449, employee_list_screen.dart:486
- 
Fix fire-and-forget sync calls in pos_screen.dart (both locations) — errors silently swallowed, no retry
- 
Add images to cache for 9+ Image.network() calls (currently uncached, reload on every build)
- 
Add index on customers(tenant_id) and other missing multi-tenant indexes
- 
Fix withOpacity() calls (~20 deprecated usages) in various screen files
- 
Address sync engine batch retry gap in sync_engine.dart — failed batch silently skipped, no retry
- 
Add Step 6 instrumentation (Flutter DevTools baseline RAM/frame/rebuild metrics)
Critical Context
- 
dart analyze passes with zero errors on all 9 modified files (only pre-existing avoid_print info-level warnings remain)
- 
Drift expression methods (lower(), contains(), isAfter(), isBefore()) are unavailable on GeneratedColumn when accessed outside the AppDatabase class — filtered query methods must be housed inside AppDatabase
- 
CartNotifier has an unbounded _productUnitsCache (Map<int, List<ProductUnit>>) with no eviction strategy
- 
CartNotifier is NOT autoDispose (intentionally — cart must persist), but its cache grows without bound
- 
Sync engine can fire concurrent syncs if user navigates quickly — _sync() debounce on pull() only, not push()
Relevant Files
- 
lib/features/pos/state/cart_state.dart: POS providers converted to SQL filtering + debounce + autoDispose
- 
lib/features/pos/state/pos_category_state.dart: categoryStreamProvider autoDispose
- 
lib/features/dashboard/dashboard_screen.dart: removed full invoice watch, added _RecentTransactions widget
- 
lib/features/sales/state/sales_state.dart: autoDispose on both providers
- 
lib/features/invoice/state/invoice_state.dart: autoDispose on all 5 providers
- 
lib/features/invoice/state/invoice_history_state.dart: autoDispose on salesHistoryProvider
- 
lib/features/stock_mgmt/inventory_dashboard_screen.dart: memory leak fixed (3 subscriptions disposed)
- 
lib/core/database/app_database.dart: schema v44, 9 indexes, new filtered/paginated query methods, getTopInvoices()
- 
lib/features/invoice/invoice_template_editor/template_repository.dart: activeTemplateProvider autoDispose
- 
lib/core/services/sync_engine.dart: batch retry gap — failed push batch silently dropped
- 
lib/features/ledger/customer_ledger/add_customer_ledger.dart: 3 leaked TextEditingControllers
- 
lib/features/ledger/supplier_ledger/add_supplier_ledger.dart: 3 leaked TextEditingControllers
- 
lib/features/inventory/reports/invoice_settings_screen.dart: 1 leaked TextEditingController
- 
lib/features/settings/screens/settings_screen.dart: setState after await without mounted check (line 53)
- 
lib/features/invoice/invoice_template_editor/editor_screen.dart: setState after await without mounted check (line 449)
- 
lib/features/employees/employee_list_screen.dart: setState after await without mounted check (line 486)
- 
lib/features/pos/pos_screen.dart: fire-and-forget sync pull, errors silently swallowed (line 97)
- 
lib/features/sales/screens/pos_screen.dart: same fire-and-forget issue (line 105)
▣  Compaction · DeepSeek V4 Flash Free · 34.6s
Thought: The user is asking me to continue with next steps from the consolidated findings. I'm in plan mode (read-only), so I can only read, search, and plan - not edit files.
Let me look at the prioritized list. The user seems to want me to proceed with implementation. But since I'm in plan mode, I should focus on creating detailed implementation plans for the items they'd like to tackle.
Let me ask the user which items they want to focus on first, since there are many issues across multiple severity levels.
Actually, re-reading the conversation history - the user said "Continue if you have next steps, or stop and ask for clarification if you are unsure how to proceed." and the system reminder says I'm in plan mode (read-only).
I should not make any edits. I should present a plan for what to do next. Let me ask the user which items from the prioritized list they want to tackle first, and then create detailed implementation plans for those items.
Given the number of issues, I should ask the user to confirm which batch they want to start with.
We have a prioritized list of ~24 issues beyond what was already fixed. The Immediate (release-blocking) items are:
1. 
Fix 3 mounted-check crashes (settings_screen.dart:53, editor_screen.dart:449, employee_list_screen.dart:486)
2. 
Wrap stock deduction in a transaction (inventory_service.dart:9-28)
3. 
Add dispose() to 3 screens with leaked TextEditingControllers (add_customer_ledger.dart, add_supplier_ledger.dart, invoice_settings_screen.dart)
4. 
Apply autoDispose + eviction to CartNotifier._productUnitsCache (cart_state.dart)
Which batch do you want me to create detailed implementation plans for? Start with the Immediate group, or pick specific items?