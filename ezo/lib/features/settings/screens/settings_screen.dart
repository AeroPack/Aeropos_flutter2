import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aeropos/l10n/app_localizations.dart';
import 'package:aeropos/core/layout/pos_design_system.dart';
import 'package:aeropos/core/widgets/role_guard.dart';
import 'package:aeropos/core/constants/permissions.dart';
import 'package:aeropos/features/pos/providers/pos_layout_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PosLayoutType? _pendingLayout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLayout = ref.watch(posLayoutProvider);
    final selectedLayout = _pendingLayout ?? currentLayout;
    final hasUnsavedChanges =
        _pendingLayout != null && _pendingLayout != currentLayout;

    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: Colors.white,
        foregroundColor: PosColors.textMain,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          // ── POS Layout Selection ──
          _PosLayoutSection(
            currentLayout: currentLayout,
            selectedLayout: selectedLayout,
            hasUnsavedChanges: hasUnsavedChanges,
            onLayoutTap: (layout) {
              setState(() => _pendingLayout = layout);
            },
            onSave: () async {
              if (_pendingLayout != null) {
                final messenger = ScaffoldMessenger.of(context);
                await ref
                    .read(posLayoutProvider.notifier)
                    .setLayout(_pendingLayout!);
                if (!mounted) return;
                setState(() => _pendingLayout = null);
                messenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'POS layout changed to ${_pendingLayout?.displayName ?? selectedLayout.displayName}',
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF16A34A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
              }
            },
          ),

          const SizedBox(height: 16),

          // ── Role & Permissions ──
          RoleGuard(
            permission: AppPermissions.manageEmployees,
            child: _buildSettingsItem(
              context,
              title: l10n.rolePermissions,
              subtitle: l10n.rolePermissionsSubtitle,
              icon: Icons.verified_user_outlined,
              onTap: () => context.go('/settings/roles'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: PosColors.border),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsetsDirectional.all(8),
          decoration: BoxDecoration(
            color: PosColors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: PosColors.blue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: PosColors.textLight),
        onTap: onTap,
      ),
    );
  }
}

// ── POS Layout Selection Section ──

class _PosLayoutSection extends StatelessWidget {
  final PosLayoutType currentLayout;
  final PosLayoutType selectedLayout;
  final bool hasUnsavedChanges;
  final ValueChanged<PosLayoutType> onLayoutTap;
  final VoidCallback onSave;

  const _PosLayoutSection({
    required this.currentLayout,
    required this.selectedLayout,
    required this.hasUnsavedChanges,
    required this.onLayoutTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PosColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: PosColors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POS Layout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PosColors.textMain,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Choose your preferred point-of-sale screen layout',
                        style: TextStyle(
                          fontSize: 13,
                          color: PosColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 24, indent: 20, endIndent: 20),

          // Layout grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: PosLayoutType.values.length,
                  itemBuilder: (context, index) {
                    final layout = PosLayoutType.values[index];
                    final isSelected = layout == selectedLayout;
                    final isActive = layout == currentLayout;

                    return _LayoutCard(
                      layout: layout,
                      isSelected: isSelected,
                      isActive: isActive,
                      onTap: () => onLayoutTap(layout),
                    );
                  },
                );
              },
            ),
          ),

          // Save button
          if (hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    'Set ${selectedLayout.displayName} as POS Layout',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PosColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Individual Layout Card ──

class _LayoutCard extends StatelessWidget {
  final PosLayoutType layout;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;

  const _LayoutCard({
    required this.layout,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? PosColors.blue : const Color(0xFFE2E8F0);

    final bgColor = isSelected
        ? PosColors.blue.withValues(alpha: 0.06)
        : Colors.white;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon + check row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    layout.icon,
                    size: 26,
                    color: isSelected ? PosColors.blue : PosColors.textMuted,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: PosColors.blue,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Name
              Text(
                layout.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? PosColors.blue : PosColors.textMain,
                ),
              ),
              const SizedBox(height: 2),

              // Description
              Text(
                layout.description,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? PosColors.blue.withValues(alpha: 0.7)
                      : PosColors.textMuted,
                ),
              ),

              // Active badge
              if (isActive && !isSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
