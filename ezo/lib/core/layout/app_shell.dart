import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../constants/permissions.dart';
import '../widgets/master_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class SidebarItem {
  final String label;
  final IconData icon;
  final int branchIndex;
  final String? requiredPermission;
  final String? routePush;

  const SidebarItem({
    required this.label,
    required this.icon,
    required this.branchIndex,
    this.requiredPermission,
    this.routePush,
  });
}

class SidebarGroup {
  final String label;
  final IconData icon;

  /// If null, this group is a collapsible header.
  /// If set, tapping navigates directly (standalone item).
  final int? branchIndex;

  /// If set, tapping pushes this route instead of goBranch.
  final String? routePush;

  final List<SidebarItem> children;

  const SidebarGroup({
    required this.label,
    required this.icon,
    this.branchIndex,
    this.routePush,
    this.children = const [],
  });

  bool get isStandalone => children.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// AppShell
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _isRailExtended = true;

  // All groups start collapsed; click to expand
  final Set<String> _expandedGroups = {};

  static const List<SidebarGroup> _sidebarGroups = [
    // ── Standalone ──────────────────────────────────────────────────────────
    SidebarGroup(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      branchIndex: 0,
    ),

    // ── Item Master ─────────────────────────────────────────────────────────
    SidebarGroup(
      label: 'Item Master',
      icon: Icons.inventory_2_outlined,
      children: [
        SidebarItem(
          label: 'Product List',
          icon: Icons.list_alt_outlined,
          branchIndex: 1,
          requiredPermission: AppPermissions.manageProducts,
        ),
        SidebarItem(
          label: 'Category List',
          icon: Icons.category_outlined,
          branchIndex: 3,
        ),
        SidebarItem(label: 'Unit List', icon: Icons.straighten, branchIndex: 4),
        SidebarItem(
          label: 'Brand List',
          icon: Icons.branding_watermark_outlined,
          branchIndex: 5,
        ),
      ],
    ),

    // ── People ───────────────────────────────────────────────────────────────
    SidebarGroup(
      label: 'People',
      icon: Icons.groups_outlined,
      children: [
        SidebarItem(
          label: 'Customers',
          icon: Icons.person_outline,
          branchIndex: 6,
        ),
        SidebarItem(
          label: 'Suppliers',
          icon: Icons.local_shipping_outlined,
          branchIndex: 7,
        ),
        SidebarItem(
          label: 'Employees',
          icon: Icons.badge_outlined,
          branchIndex: 13,
          requiredPermission: AppPermissions.manageEmployees,
        ),
      ],
    ),
    // ── Sales ────────────────────────────────────────────────────────────────
    SidebarGroup(
      label: 'Sales',
      icon: Icons.receipt_long_outlined,
      children: [
        SidebarItem(
          label: 'Sales History',
          icon: Icons.history_edu_outlined,
          branchIndex: 8,
        ),
        SidebarItem(
          label: 'Reports',
          icon: Icons.bar_chart,
          branchIndex: 9,
          requiredPermission: AppPermissions.viewReports,
        ),
        SidebarItem(
          label: 'POS Billing',
          icon: Icons.monitor_outlined,
          branchIndex: -1,
          routePush: '/pos',
          requiredPermission: AppPermissions.accessPos,
        ),
      ],
    ),

    // ── Stock Management ────────────────────────────────────────────────────
    SidebarGroup(
      label: 'Stock Management',
      icon: Icons.inventory_outlined,
      children: [
        SidebarItem(
          label: 'Inventory Dashboard',
          icon: Icons.dashboard_outlined,
          branchIndex: 14,
        ),
        SidebarItem(
          label: 'Purchase Receipt',
          icon: Icons.shopping_cart_outlined,
          branchIndex: 15,
        ),
      ],
    ),

    // ── Ledger ───────────────────────────────────────────────────────────────
    SidebarGroup(
      label: 'Ledger',
      icon: Icons.account_balance_outlined,
      children: [
        SidebarItem(
          label: 'Customer Ledger',
          icon: Icons.people_outline,
          branchIndex: 16,
        ),
        SidebarItem(
          label: 'Supplier Ledger',
          icon: Icons.local_shipping_outlined,
          branchIndex: 17,
        ),
      ],
    ),

    // ── Settings ─────────────────────────────────────────────────────────────
    SidebarGroup(
      label: 'Settings',
      icon: Icons.settings_outlined,
      children: [
        SidebarItem(
          label: 'Invoice Template',
          icon: Icons.description_outlined,
          branchIndex: -1,
          routePush: '/invoice-templates',
        ),
        SidebarItem(
          label: 'Barcode Generation',
          icon: Icons.qr_code_scanner,
          branchIndex: 18,
        ),
      ],
    ),
  ];

  void _onBranchSelected(int branchIndex) {
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
    );
  }

  void _onGroupTap(SidebarGroup group) {
    if (group.routePush != null) {
      context.go(group.routePush!);
      return;
    }
    if (group.isStandalone && group.branchIndex != null) {
      _onBranchSelected(group.branchIndex!);
      return;
    }
    // Toggle expand/collapse
    setState(() {
      if (_expandedGroups.contains(group.label)) {
        _expandedGroups.remove(group.label);
      } else {
        _expandedGroups.add(group.label);
      }
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isItemVisible(SidebarItem item, dynamic user) {
    if (item.requiredPermission == null) return true;
    return user?.hasPermission(item.requiredPermission!) ?? false;
  }

  bool _isGroupVisible(SidebarGroup group, dynamic user) {
    if (group.label == 'Settings') {
      final hasAccess = user?.hasPermission(AppPermissions.manageSettings) ?? true;
      if (!hasAccess) return false;
    }
    if (group.isStandalone) return true;
    // Group visible if at least one child is visible
    return group.children.any((item) => _isItemVisible(item, user));
  }

  bool _isItemActive(SidebarItem item) =>
      item.branchIndex == widget.navigationShell.currentIndex;

  bool _isGroupActive(SidebarGroup group) {
    if (group.isStandalone) {
      return group.branchIndex == widget.navigationShell.currentIndex;
    }
    return group.children.any(_isItemActive);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    final width = MediaQuery.of(context).size.width;
    final isSmallDesktop = width > 900;
    final isDesktop = isSmallDesktop;

    final visibleGroups = _sidebarGroups
        .where((g) => _isGroupVisible(g, user))
        .toList();

    // ── Master Header ────────────────────────────────────────────────────────
    final appBar = MasterHeader(
      onSidebarToggle: () => setState(() => _isRailExtended = !_isRailExtended),
      showSidebarToggle: isDesktop,
      isDesktop: isDesktop,
    );

    // ── Desktop layout ─────────────────────────────────────────────────────────
    if (isDesktop) {
      // Sidebar width based on expanded/collapsed state
      final sidebarWidth = _isRailExtended ? 240.0 : 72.0;

      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            // ── Sidebar ──────────────────────────────────────────────────────
            Container(
              width: sidebarWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final group in visibleGroups)
                    _buildSidebarGroup(group, user, _isRailExtended),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: Colors.grey),
            Expanded(
              child: Container(
                color: const Color(0xFFF5F7FA),
                child: widget.navigationShell,
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile/Tablet layout ───────────────────────────────────────────────────
    // Bottom bar: Dashboard, Sales History, Settings
    final bottomItems = <_BottomItem>[
      _BottomItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        branchIndex: 0,
      ),
      _BottomItem(
        label: 'History',
        icon: Icons.history_edu_outlined,
        branchIndex: 8,
      ),
      _BottomItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        branchIndex: 10,
      ),
    ];

    int bottomBarIndex = bottomItems.indexWhere(
      (item) => item.branchIndex == widget.navigationShell.currentIndex,
    );
    if (bottomBarIndex == -1) bottomBarIndex = 0;

    return Scaffold(
      appBar: appBar,
      drawer: _buildMobileDrawer(visibleGroups, user),
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomBarIndex,
        onDestinationSelected: (i) {
          _onBranchSelected(bottomItems[i].branchIndex);
        },
        destinations: bottomItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Desktop sidebar group builder ──────────────────────────────────────────

  Widget _buildSidebarGroup(SidebarGroup group, dynamic user, bool extended) {
    final isActive = _isGroupActive(group);
    final isExpanded = _expandedGroups.contains(group.label);
    final visibleChildren = group.children
        .where((item) => _isItemVisible(item, user))
        .toList();

    // ── Standalone item (no children) ─────────────────────────────────────────
    if (group.isStandalone) {
      return _SidebarTile(
        icon: group.icon,
        label: group.label,
        isSelected: isActive,
        extended: extended,
        onTap: () => _onGroupTap(group),
      );
    }

    // ── Group header + children (with AnimatedSize for smooth open/close) ─────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Group header
        _SidebarTile(
          icon: group.icon,
          label: group.label,
          isSelected: isActive,
          extended: extended,
          trailing: extended
              ? AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: isActive ? Colors.blue : Colors.grey.shade500,
                  ),
                )
              : null,
          onTap: () {
            if (!extended) {
              final firstBranch = visibleChildren.cast<SidebarItem?>().firstWhere(
                (c) => c!.branchIndex >= 0,
                orElse: () => null,
              );
              if (firstBranch != null) {
                _onBranchSelected(firstBranch.branchIndex);
              }
            } else {
              _onGroupTap(group);
            }
          },
        ),

        // Children — wrapped in ClipRect + AnimatedSize for smooth animation
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: extended && isExpanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: visibleChildren
                        .map(
                          (item) => _SidebarChildTile(
                            icon: item.icon,
                            label: item.label,
                            isSelected: _isItemActive(item),
                            onTap: () {
                              if (item.routePush != null) {
                                context.go(item.routePush!);
                              } else {
                                _onBranchSelected(item.branchIndex);
                              }
                            },
                          ),
                        )
                        .toList(),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  // ── Mobile drawer ──────────────────────────────────────────────────────────

  Widget _buildMobileDrawer(List<SidebarGroup> groups, dynamic user) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/dashboard');
                },
                child: const Text(
                  "AeroPOS",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final group in groups)
                  if (group.isStandalone)
                    ListTile(
                      leading: Icon(group.icon),
                      title: Text(group.label),
                      selected: _isGroupActive(group),
                      selectedColor: Colors.blue,
                      onTap: () {
                        Navigator.of(context).pop();
                        _onGroupTap(group);
                      },
                    )
                  else
                    ExpansionTile(
                      leading: Icon(
                        group.icon,
                        color: _isGroupActive(group) ? Colors.blue : null,
                      ),
                      title: Text(
                        group.label,
                        style: TextStyle(
                          color: _isGroupActive(group) ? Colors.blue : null,
                          fontWeight: _isGroupActive(group)
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      initiallyExpanded: _isGroupActive(group),
                      children: group.children
                          .where((item) => _isItemVisible(item, user))
                          .map(
                            (item) => ListTile(
                              contentPadding: const EdgeInsets.only(
                                left: 56,
                                right: 16,
                              ),
                              leading: Icon(item.icon, size: 20),
                              title: Text(
                                item.label,
                                style: const TextStyle(fontSize: 14),
                              ),
                              selected: _isItemActive(item),
                              selectedColor: Colors.blue,
                              onTap: () {
                                Navigator.of(context).pop();
                                if (item.routePush != null) {
                                  context.go(item.routePush!);
                                } else {
                                  _onBranchSelected(item.branchIndex);
                                }
                              },
                            ),
                          )
                          .toList(),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar Tile Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool extended;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.extended,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.blue : Colors.grey.shade700;
    final bg = isSelected
        ? Colors.blue.withValues(alpha: 0.1)
        : Colors.transparent;

    if (!extended) {
      return Tooltip(
        message: label,
        preferBelow: false,
        child: Material(
          color: bg,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Center(child: Icon(icon, color: color, size: 22)),
            ),
          ),
        ),
      );
    }

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // ignore: use_null_aware_elements
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarChildTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarChildTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Colors.blue.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(
            left: 44,
            right: 16,
            top: 10,
            bottom: 10,
          ),
          decoration: isSelected
              ? const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.blue, width: 3),
                  ),
                )
              : null,
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? Colors.blue : Colors.grey.shade500,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.blue : Colors.grey.shade700,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar helper
// ─────────────────────────────────────────────────────────────────────────────

class _BottomItem {
  final String label;
  final IconData icon;
  final int branchIndex;

  const _BottomItem({
    required this.label,
    required this.icon,
    required this.branchIndex,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync Progress Dialog (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
