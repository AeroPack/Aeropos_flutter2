import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/features/pos/services/return_service.dart';
import 'package:aeropos/features/pos/providers/return_service_provider.dart';

class ReturnDialog extends ConsumerStatefulWidget {
  final InvoiceEntity invoice;
  final List<InvoiceItemEntity> items;
  final Map<int, String> productNames;

  const ReturnDialog({
    super.key,
    required this.invoice,
    required this.items,
    required this.productNames,
  });

  @override
  ConsumerState<ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends ConsumerState<ReturnDialog> {
  // Keeps track of how many of each item the user wants to return.
  // Using the item's ID or index as the key.
  final Map<int, int> _returnQuantities = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Initialize all return quantities to 0
    for (int i = 0; i < widget.items.length; i++) {
      _returnQuantities[i] = 0;
    }
  }

  // Calculate the total refund amount based on current stepper values
  double get _totalRefund {
    double total = 0.0;
    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final returnQty = _returnQuantities[i] ?? 0;
      total += item.unitPrice * returnQty;
    }
    return total;
  }

  bool get _hasItemsToReturn {
    return _returnQuantities.values.any((qty) => qty > 0);
  }

  Future<void> _processReturn() async {
    final returnItems = <ReturnItemRequest>[];
    for (int i = 0; i < widget.items.length; i++) {
      final qty = _returnQuantities[i] ?? 0;
      if (qty == 0) continue;
      final item = widget.items[i];
      returnItems.add(
        ReturnItemRequest(
          productId: item.productId,
          invoiceItemId: item.id,
          quantity: qty.toDouble(),
          unitPrice: item.unitPrice,
        ),
      );
    }

    if (returnItems.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final service = ref.read(returnServiceProvider);
      await service.processReturn(
        invoiceId: widget.invoice.id,
        userId: 1,
        tenantId: widget.invoice.tenantId,
        returnItems: returnItems,
        refundMethod: 'wallet',
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
    // sizeOf prevents keyboard-related layout shifts
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    
    // Cap the modal width on large screens, but give it breathing room on mobile
    final dialogWidth = isMobile ? screenWidth * 0.95 : 600.0;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24, 
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: 800, // Prevents modal from overflowing vertically
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            
            // Flexible scrollable area for items
            Flexible(
              child: _buildItemList(),
            ),
            
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            _buildFooter(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.assignment_return_outlined,
              color: Color(0xFF0B1C30),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Process Return',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B1C30),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invoice #${widget.invoice.invoiceNumber}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF545F73),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFF717786)),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8F9FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    if (widget.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'No items found in this invoice.',
            style: TextStyle(color: Color(0xFF717786)),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: widget.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        
        final String itemName = widget.productNames[item.id] ?? 'Unknown Product';
        final double price = item.unitPrice;
        final int totalPurchased = item.quantity;
        final int alreadyReturned = item.returnedQuantity.toInt();
        
        final maxReturnable = totalPurchased - alreadyReturned;
        final currentReturnQty = _returnQuantities[index] ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B1C30),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs ${price.toStringAsFixed(2)} / unit',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF545F73),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: maxReturnable == 0 
                            ? const Color(0xFFFFEBEE) 
                            : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        maxReturnable == 0 
                            ? 'Fully Returned' 
                            : 'Available to return: $maxReturnable',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: maxReturnable == 0 
                              ? const Color(0xFFD32F2F) 
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Quantity Stepper
              if (maxReturnable > 0)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _stepperButton(
                        icon: Icons.remove,
                        onTap: currentReturnQty > 0
                            ? () {
                                setState(() {
                                  _returnQuantities[index] = currentReturnQty - 1;
                                });
                              }
                            : null,
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          currentReturnQty.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0B1C30),
                          ),
                        ),
                      ),
                      _stepperButton(
                        icon: Icons.add,
                        onTap: currentReturnQty < maxReturnable
                            ? () {
                                setState(() {
                                  _returnQuantities[index] = currentReturnQty + 1;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: isEnabled ? const Color(0xFF0058BC) : const Color(0xFFC1C6D7),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    final content = [
      // Total Calculation
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL REFUND',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF717786),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rs ${_totalRefund.toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B1C30),
            ),
          ),
        ],
      ),
      if (isMobile) const SizedBox(height: 20),
      
      // Actions
      Row(
        mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Expanded(
            flex: isMobile ? 1 : 0,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                foregroundColor: const Color(0xFF545F73),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: isMobile ? 1 : 0,
            child: ElevatedButton(
              onPressed: (_hasItemsToReturn && !_isProcessing)
                  ? _processReturn
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                backgroundColor: const Color(0xFF0058BC),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFFA0AEC0),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirm Return',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: content,
            ),
    );
  }
}