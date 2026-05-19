import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../di/service_locator.dart';
import '../models/company.dart';

/// Provider that fetches companies list for the current user
final companiesProvider = FutureProvider<List<Company>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.status != AuthStatus.authenticated) return [];

  try {
    final authRepo = ServiceLocator.instance.authRepository;
    return await authRepo.getMyCompanies();
  } catch (e) {
    return [];
  }
});

class CompanySwitcher extends ConsumerWidget {
  const CompanySwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(companiesProvider);

    return companiesAsync.when(
      data: (companies) {
        // Don't show switcher if only 1 company
        if (companies.length <= 1) return const SizedBox.shrink();

        final currentCompany = companies.firstWhere(
          (c) => c.isCurrent == true,
          orElse: () => companies.first,
        );

        return PopupMenuButton<Company>(
          tooltip: 'Switch Company',
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      currentCompany.businessName.isNotEmpty
                          ? currentCompany.businessName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    currentCompany.businessName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          itemBuilder: (context) => companies.map((company) {
            final isCurrent = company.isCurrent == true;
            return PopupMenuItem<Company>(
              value: company,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15)
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        company.businessName.isNotEmpty
                            ? company.businessName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.businessName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                        ),
                        if (company.role != null)
                          Text(
                            company.role!,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            );
          }).toList(),
          onSelected: (company) {
            if (company.isCurrent == true) return;
            _showSwitchConfirmation(context, ref, company);
          },
        );
      },
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  void _showSwitchConfirmation(
    BuildContext context,
    WidgetRef ref,
    Company company,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Company'),
        content: Text(
          'Switch to "${company.businessName}"? All local data will be refreshed for the new company.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(authControllerProvider.notifier)
                  .switchCompany(company.id);
            },
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }
}
