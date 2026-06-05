import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../di/service_locator.dart';
import 'pos_calculator.dart';
import 'company_switcher.dart';
import '../../features/profile/presentation/providers/profile_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MasterHeader extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback? onSidebarToggle;
  final bool showSidebarToggle;
  final bool isDesktop;
  final List<Widget>? actions;
  final List<Widget>? customActions;
  final bool hidePosButton;
  final Widget? title;
  final Widget? leading;
  final double? leadingWidth;
  final String? searchQuery;
  final ValueChanged<String>? onSearch;

  const MasterHeader({
    super.key,
    this.onSidebarToggle,
    this.showSidebarToggle = true,
    this.isDesktop = true,
    this.actions,
    this.customActions,
    this.hidePosButton = false,
    this.title,
    this.leading,
    this.leadingWidth,
    this.searchQuery,
    this.onSearch,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isLargeDesktop = width > 1200;
    final isMediumDesktop = width > 1000;
    final isSmallDesktop = width > 900;
    final isTablet = width > 600;
    final isActuallyDesktop = isSmallDesktop;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      shape: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      leadingWidth:
          leadingWidth ??
          (isActuallyDesktop ? (isLargeDesktop ? 250 : 200) : null),
      leading:
          leading ??
          (isActuallyDesktop
              ? InkWell(
                  onTap: () => context.go('/dashboard'),
                  mouseCursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront,
                          color: Color(0xFF0F172A),
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Aero",
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "POS",
                          style: TextStyle(
                            color: Color.fromARGB(255, 0, 191, 255),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null),
      title:
          title ??
          Row(
            children: [
              if (isActuallyDesktop && showSidebarToggle) ...[
                IconButton(
                  onPressed: onSidebarToggle,
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.compare_arrows,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: RawAutocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _featurePages.keys.where((String option) {
                      return option.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },
                  onSelected: (String selection) {
                    final route = _featurePages[selection];
                    if (route != null) {
                      context.go(route);
                    }
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 350,
                          constraints: const BoxConstraints(maxHeight: 400),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              final icon = _getPageIcon(option);
                              return ListTile(
                                leading: Icon(
                                  icon,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                                title: Text(
                                  option,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                onTap: () => onSelected(option),
                                hoverColor: Colors.blue.withValues(alpha: 0.05),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  fieldViewBuilder:
                      (context, textController, focusNode, onFieldSubmitted) {
                        // Update search query state if internal controller changes
                        textController.addListener(() {
                          if (onSearch != null) {
                            onSearch!(textController.text);
                          }
                        });

                        // Sync with external searchQuery if provided
                        if (searchQuery != null &&
                            textController.text != searchQuery) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            textController.text = searchQuery!;
                          });
                        }

                        return Container(
                          height: 40,
                          constraints: BoxConstraints(
                            maxWidth: isLargeDesktop
                                ? 400
                                : (isMediumDesktop ? 300 : 250),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: TextField(
                            controller: textController,
                            focusNode: focusNode,
                            onSubmitted: (value) => onFieldSubmitted(),
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText:
                                  "Search featured pages or search in context...",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.only(
                                top: 5,
                                bottom: 0,
                                left: 10,
                                right: 10,
                              ),
                              suffixIcon: isTablet
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
                                      ),
                                      // child: Container(
                                      //   width: 40,
                                      //   alignment: Alignment.center,
                                      //   decoration: BoxDecoration(
                                      //     color: Colors.grey.shade200,
                                      //     borderRadius: BorderRadius.circular(
                                      //       4,
                                      //     ),
                                      //   ),
                                      //   child: Icon(
                                      //     Icons.center_focus_strong,
                                      //     size: 18,
                                      //     color: Colors.grey.shade600,
                                      //   ),
                                      // ),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                ),
              ),
            ],
          ),
      actions:
          actions ??
          [
            ...?customActions,
            if (isSmallDesktop) ...[
              const CompanySwitcher(),
              const SizedBox(width: 8),
            ],
            if (isMediumDesktop) ...[
              if (!hidePosButton)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/pos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.monitor, size: 18),
                    label: const Text("POS"),
                  ),
                ),
            ],
            if (isTablet)
              IconButton(
                onPressed: () => _toggleFullscreen(context),
                icon: const Icon(Icons.fullscreen, color: Colors.grey),
                tooltip: 'Toggle Fullscreen',
              ),
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.1),
                  builder: (ctx) => Dialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    alignment: Alignment.topRight,
                    insetPadding: const EdgeInsets.only(top: 70, right: 16),
                    child: PosCalculator(onClose: () => Navigator.pop(ctx)),
                  ),
                );
              },
              icon: const Icon(Icons.calculate_outlined, color: Colors.grey),
              tooltip: 'Calculator',
            ),
            IconButton(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings_outlined, color: Colors.grey),
              tooltip: 'Settings',
            ),

            Padding(
              padding: const EdgeInsets.only(right: 16, left: 8),
              child: PopupMenuButton<String>(
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                icon: Consumer(
                  builder: (context, ref, child) {
                    final profileState = ref.watch(profileControllerProvider);
                    final userImage = profileState.profile?['userImage'];
                    final hasValidImage =
                        userImage != null &&
                        userImage.toString().isNotEmpty &&
                        userImage.toString().startsWith('http');
                    return CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: hasValidImage
                          ? CachedNetworkImageProvider(userImage.toString())
                          : null,
                      child: !hasValidImage
                          ? const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.grey,
                            )
                          : null,
                    );
                  },
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'profile':
                      context.go('/profile');
                      break;
                    case 'company':
                      context.go('/company-profile');
                      break;
                    case 'manage_companies':
                      context.go('/profile/companies');
                      break;
                    case 'settings':
                      context.go('/settings');
                      break;
                    case 'logout':
                      _handleLogout(context, ref);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.person_outline, size: 20),
                      title: Text(
                        'User Profile',
                        style: TextStyle(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'company',
                    child: ListTile(
                      leading: Icon(Icons.business_outlined, size: 20),
                      title: Text(
                        'Company Profile',
                        style: TextStyle(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'manage_companies',
                    child: ListTile(
                      leading: Icon(Icons.business_rounded, size: 20),
                      title: Text(
                        'Manage Companies',
                        style: TextStyle(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined, size: 20),
                      title: Text('Settings', style: TextStyle(fontSize: 14)),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, size: 20, color: Colors.red),
                      title: Text(
                        'Logout',
                        style: TextStyle(fontSize: 14, color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
    );
  }

  IconData _getPageIcon(String option) {
    switch (option) {
      case 'Dashboard':
        return Icons.dashboard_outlined;
      case 'Products / Inventory':
        return Icons.inventory_2_outlined;
      case 'Category List':
        return Icons.category_outlined;
      case 'Unit List':
        return Icons.straighten_outlined;
      case 'Brand List':
        return Icons.branding_watermark_outlined;
      case 'Customers':
        return Icons.people_outline;
      case 'Suppliers':
        return Icons.local_shipping_outlined;
      case 'Sales History':
        return Icons.history_outlined;
      case 'POS Billing':
        return Icons.point_of_sale_outlined;
      case 'User Profile':
        return Icons.person_outline;
      case 'Company Profile':
        return Icons.business_outlined;
      case 'Employee List':
        return Icons.badge_outlined;
      case 'Role Settings':
        return Icons.admin_panel_settings_outlined;
      case 'Invoice Templates':
        return Icons.description_outlined;
      default:
        return Icons.pageview_outlined;
    }
  }

  static const Map<String, String> _featurePages = {
    'Dashboard': '/dashboard',
    'Products / Inventory': '/inventory',
    'Category List': '/category-list',
    'Unit List': '/unit-list',
    'Brand List': '/brand-list',
    'Customers': '/customers',
    'Suppliers': '/supplier-ledger',
    'Sales History': '/sales-history',
    'POS Billing': '/pos',
    'User Profile': '/profile',
    'Company Profile': '/company-profile',
    'Employee List': '/employees',
    'Role Settings': '/settings/roles',
    'Invoice Templates': '/invoice-templates',
  };

  static bool _isFullscreen = false;

  void _toggleFullscreen(BuildContext context) {
    _isFullscreen = !_isFullscreen;
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final pending = await ServiceLocator.instance.syncEngine.pendingCount();
    if (pending > 0) {
      if (!context.mounted) return;
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsynced changes'),
          content: Text(
            '$pending change(s) have not been synced to the server yet. '
            'Logging out now may cause data loss.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Logout anyway',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
      if (shouldLogout != true) return;
    }
    await ref.read(authControllerProvider.notifier).logout();
  }
}
