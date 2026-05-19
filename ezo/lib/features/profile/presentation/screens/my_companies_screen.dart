import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../core/models/company.dart';
import '../widgets/create_company_dialog.dart';

class MyCompaniesScreen extends ConsumerStatefulWidget {
  const MyCompaniesScreen({super.key});

  @override
  ConsumerState<MyCompaniesScreen> createState() => _MyCompaniesScreenState();
}

class _MyCompaniesScreenState extends ConsumerState<MyCompaniesScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh companies list on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).refreshCompanies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final companies = authState.companies ?? [];
    final isLoading = authState.status == AuthStatus.loading;
    final currentCompanyId = authState.company?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          "My Companies",
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        actions: [
          if (authState.user?.isAdmin ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: () => _showCreateCompanyDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add Company"),
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: isLoading && companies.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : companies.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: () => ref.read(authControllerProvider.notifier).refreshCompanies(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: companies.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final company = companies[index];
                      final isCurrent = company.id == currentCompanyId;

                      return _CompanyManagementCard(
                        company: company,
                        isCurrent: isCurrent,
                        onSwitch: isCurrent
                            ? null
                            : () => _handleSwitch(context, ref, company),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "No companies found",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            "You aren't associated with any other companies.",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showCreateCompanyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateCompanyDialog(),
    );
  }

  Future<void> _handleSwitch(BuildContext context, WidgetRef ref, Company company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Switch Company"),
        content: Text("Switch to ${company.businessName}? Your current session will be closed and data will re-sync."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            child: const Text("Switch"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).switchCompany(company.id);
    }
  }
}

class _CompanyManagementCard extends StatelessWidget {
  final Company company;
  final bool isCurrent;
  final VoidCallback? onSwitch;

  const _CompanyManagementCard({
    required this.company,
    required this.isCurrent,
    this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5) : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Company Logo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: company.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: company.logoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const SizedBox(),
                        errorWidget: (_, _, _) => _buildInitial(context),
                      ),
                    )
                  : _buildInitial(context),
            ),
            const SizedBox(width: 20),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        company.businessName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Current",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    company.businessAddress ?? "No address set",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildBadge(
                        context,
                        company.role?.toUpperCase() ?? "EMPLOYEE",
                        Colors.blue,
                      ),
                      if (company.isOwner ?? false) ...[
                        const SizedBox(width: 8),
                        _buildBadge(context, "OWNER", Colors.orange),
                      ],
                    ],
                  ),
                ],
              ),
              
            ),

            // Action
            if (!isCurrent)
              ElevatedButton(
                onPressed: onSwitch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Switch"),
              )
            else
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInitial(BuildContext context) {
    return Center(
      child: Text(
        company.businessName.isNotEmpty ? company.businessName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
