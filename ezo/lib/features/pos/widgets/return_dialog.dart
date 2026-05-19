import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/layout/pos_design_system.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/features/pos/services/return_service.dart';
import 'package:aeropos/features/pos/providers/return_service_provider.dart';

class ReturnDialog extends ConsumerStatefulWidget {
  final InvoiceEntity invoice;
  final List<InvoiceItemEntity> items;

  const ReturnDialog({super.key, required this.invoice, required this.items});

  @override
  ConsumerState<ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends ConsumerState<ReturnDialog> {
  final Map<int, double> _selectedQuantities = {};
  final Map<int, String> _conditions = {};
  String _refundMethod = 'wallet';
  bool _isProcessing = false;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      final remaining = item.quantity.toDouble() - item.returnedQuantity;
      if (remaining > 0) {
        _selectedQuantities[item.id] = 0;
        _conditions[item.id] = 'good';
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _totalRefund {
    double total = 0;
    for (final entry in _selectedQuantities.entries) {
      if (entry.value > 0) {
        final item = widget.items.firstWhere((i) => i.id == entry.key);
        total += entry.value * item.unitPrice.toDouble();
      }
    }
    return total;
  }

  Future<void> _processReturn() async {
    final returnItems = <ReturnItemRequest>[];

    for (final entry in _selectedQuantities.entries) {
      if (entry.value > 0) {
        final item = widget.items.firstWhere((i) => i.id == entry.key);
        returnItems.add(
          ReturnItemRequest(
            productId: item.productId,
            invoiceItemId: item.id,
            quantity: entry.value,
            unitPrice: item.unitPrice.toDouble(),
            condition: _conditions[item.id] ?? 'good',
            restock: (_conditions[item.id] ?? 'good') == 'good',
          ),
        );
      }
    }

    if (returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to return')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final service = ref.read(returnServiceProvider);
      await service.processReturn(
        invoiceId: widget.invoice.id,
        userId: 1,
        tenantId: widget.invoice.tenantId,
        returnItems: returnItems,
        refundMethod: _refundMethod,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return processed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Process Return',
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
            const Text(
              'Select items to return:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...widget.items
                .where((item) {
                  final remaining =
                      item.quantity.toDouble() - item.returnedQuantity;
                  return remaining > 0;
                })
                .map((item) {
                  final remaining =
                      item.quantity.toDouble() - item.returnedQuantity;
                  return _buildItemRow(item, remaining);
                }),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Refund Method: '),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('Wallet'),
                  selected: _refundMethod == 'wallet',
                  onSelected: (selected) {
                    if (selected) setState(() => _refundMethod = 'wallet');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cash'),
                  selected: _refundMethod == 'cash',
                  onSelected: (selected) {
                    if (selected) setState(() => _refundMethod = 'cash');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PosColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Refund:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₹${_totalRefund.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _processReturn,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Process Return'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(InvoiceItemEntity item, double remaining) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Item #${item.id}')),
          Expanded(flex: 2, child: Text('₹${item.unitPrice}')),
          Expanded(flex: 2, child: Text('Max: $remaining')),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (val) {
                      final qty = double.tryParse(val) ?? 0;
                      if (qty <= remaining) {
                        setState(() => _selectedQuantities[item.id] = qty);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _conditions[item.id] ?? 'good',
                  items: const [
                    DropdownMenuItem(value: 'good', child: Text('Good')),
                    DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _conditions[item.id] = val);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
