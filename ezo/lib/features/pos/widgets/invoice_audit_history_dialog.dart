import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/models/invoice_audit_log.dart';
import 'package:aeropos/features/pos/providers/return_service_provider.dart';

class InvoiceAuditHistoryDialog extends ConsumerWidget {
  final int invoiceId;

  const InvoiceAuditHistoryDialog({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(returnServiceProvider);

    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invoice History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<InvoiceAuditLog>>(
                future: service.getAuditHistory(invoiceId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final logs = snapshot.data ?? [];

                  if (logs.isEmpty) {
                    return const Center(child: Text('No history found'));
                  }

                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _buildLogItem(context, log);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, InvoiceAuditLog log) {
    IconData icon;
    Color color;
    String actionText;

    switch (log.actionType) {
      case 'RETURN':
        icon = Icons.assignment_return;
        color = Colors.orange;
        actionText = 'Return processed';
        break;
      case 'EXCHANGE':
        icon = Icons.swap_horiz;
        color = Colors.blue;
        actionText = 'Exchange processed';
        break;
      case 'DELETE':
        icon = Icons.delete_forever;
        color = Colors.red;
        actionText = 'Invoice deleted';
        break;
      default:
        icon = Icons.edit;
        color = Colors.grey;
        actionText = log.actionType;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Text(
              actionText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'v${log.versionNumber}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'By: User #${log.performedBy}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Date: ${log.performedAt.toString().substring(0, 19)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (log.reason != null)
              Text(
                'Reason: ${log.reason}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (log.changes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Changes: ${log.changes}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
