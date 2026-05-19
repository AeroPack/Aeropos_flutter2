import 'package:flutter/material.dart';

class InvoiceStatusBadge extends StatelessWidget {
  final String status;
  final bool showLabel;

  const InvoiceStatusBadge({
    super.key,
    required this.status,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'active':
        backgroundColor = Colors.green.withValues(alpha: 0.15);
        textColor = Colors.green[800]!;
        label = 'Active';
        icon = Icons.check_circle;
        break;
      case 'partially_returned':
        backgroundColor = Colors.orange.withValues(alpha: 0.15);
        textColor = Colors.orange[800]!;
        label = 'Partial';
        icon = Icons.warning;
        break;
      case 'fully_returned':
        backgroundColor = Colors.red.withValues(alpha: 0.15);
        textColor = Colors.red[800]!;
        label = 'Returned';
        icon = Icons.assignment_return;
        break;
      case 'deleted':
        backgroundColor = Colors.grey.withValues(alpha: 0.15);
        textColor = Colors.grey[700]!;
        label = 'Deleted';
        icon = Icons.delete_forever;
        break;
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.15);
        textColor = Colors.grey[700]!;
        label = status;
        icon = Icons.help_outline;
    }

    if (showLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Icon(icon, size: 18, color: textColor);
  }
}

class ReturnHistoryBadge extends StatelessWidget {
  final int returnCount;

  const ReturnHistoryBadge({super.key, required this.returnCount});

  @override
  Widget build(BuildContext context) {
    if (returnCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Returned $returnCount×',
        style: TextStyle(
          color: Colors.orange[800],
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class PartialReturnIndicator extends StatelessWidget {
  final int returnedCount;
  final int totalCount;

  const PartialReturnIndicator({
    super.key,
    required this.returnedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = totalCount > 0
        ? (returnedCount / totalCount * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$returnedCount / $totalCount items',
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 50,
          child: LinearProgressIndicator(
            value: returnedCount / totalCount,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(
              percentage == 100 ? Colors.red : Colors.orange,
            ),
          ),
        ),
      ],
    );
  }
}
