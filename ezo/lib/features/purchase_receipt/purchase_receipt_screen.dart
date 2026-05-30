import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/layout/pos_design_system.dart';
import 'package:aeropos/core/widgets/generic_data_table.dart';
import 'package:aeropos/core/widgets/pos_toast.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/widgets/delete_confirmation_dialog.dart';
import 'package:aeropos/features/pos/services/barcode_service.dart';
import 'package:aeropos/features/pos/state/barcode_state.dart';
import 'package:intl/intl.dart';

class PurchaseReceiptPage extends StatefulWidget {
  const PurchaseReceiptPage({super.key});

  @override
  State<PurchaseReceiptPage> createState() => _PurchaseReceiptPageState();
}

class _PurchaseReceiptPageState extends State<PurchaseReceiptPage> {
  final _viewModel = ServiceLocator.instance.purchaseReceiptViewModel;
  final Map<int, String> _supplierNames = {};
  final _barcodeService = BarcodeService();

  @override
  void initState() {
    super.initState();
    _loadSupplierNames();
  }

  Future<void> _onBarcodeScanned(String rawCode) async {
    final result = await _barcodeService.resolve(rawCode);
    if (result case BarcodeMatched(:final product)) {
      if (mounted) {
        context.push('/purchase-receipt/add', extra: product);
      }
    } else if (mounted) {
      PosToast.showError(context, 'Barcode not found: $rawCode');
    }
  }

  Future<void> _loadSupplierNames() async {
    final receipts = await _viewModel.getAllReceipts();
    for (final receipt in receipts) {
      if (!_supplierNames.containsKey(receipt.supplierId)) {
        final supplier = await _viewModel.getSupplierById(receipt.supplierId);
        if (supplier != null) {
          _supplierNames[receipt.supplierId] = supplier.name;
        }
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      body: BarcodeKeyboardListener(
        bufferDuration: const Duration(milliseconds: 80),
        onBarcodeScanned: _onBarcodeScanned,
        child: StreamBuilder<List<PurchaseReceiptEntity>>(
        stream: _viewModel.allReceipts,
        builder: (context, snapshot) {
          final receipts = snapshot.data ?? [];
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: GenericDataTable<PurchaseReceiptEntity>(
              data: receipts,
              isLoading: isLoading,
              title: "Purchases",
              subtitle: "Manage Your Purchase Order",
              searchPredicate: (item, query) {
                final supplierName =
                    (_supplierNames[item.supplierId] ?? '').toLowerCase();
                final invoiceNumber =
                    item.invoiceNumber.toLowerCase();
                return supplierName.contains(query.toLowerCase()) ||
                    invoiceNumber.contains(query.toLowerCase());
              },
              actions: [
                _iconButton(Icons.picture_as_pdf, Colors.red),
                const SizedBox(width: 8),
                _iconButton(Icons.grid_on, Colors.green),
                const SizedBox(width: 8),
                _iconButton(Icons.refresh, Colors.blueGrey),
                const SizedBox(width: 8),
                _iconButton(Icons.keyboard_arrow_up, Colors.blueGrey),
                const SizedBox(width: 12),
                _buildAddButton(),
              ],
              emptyState: _buildEmptyState(),
              columns: const [
                DataColumnConfig(label: "S No.", flex: 1),
                DataColumnConfig(label: "Date", flex: 2),
                DataColumnConfig(label: "Invoice No.", flex: 2),
                DataColumnConfig(label: "Supplier Name", flex: 3),
                DataColumnConfig(label: "Items", flex: 1),
                DataColumnConfig(label: "Total Amount", flex: 2),
                DataColumnConfig(
                  label: "Action",
                  flex: 1,
                  alignment: Alignment.centerRight,
                ),
              ],
              rowBuilder: (receipt, index) {
                return _PurchaseReceiptTableRow(
                  serialNumber: index + 1,
                  receipt: receipt,
                  supplierName:
                      _supplierNames[receipt.supplierId] ?? 'Loading...',
                  onDelete: () => _showDeleteConfirmation(receipt),
                  onEdit: () => _navigateToEdit(receipt),
                );
              },
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: () => context.push('/purchase-receipt/add'),
      icon: const Icon(Icons.add_circle_outline, size: 18),
      label: const Text("Add Purchases"),
      style: ElevatedButton.styleFrom(
        backgroundColor: PosColors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: PosColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: PosColors.textLight,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No purchases found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PosColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first purchase to get started',
              style: TextStyle(color: PosColors.textLight),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/purchase-receipt/add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PosColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add Purchase"),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(PurchaseReceiptEntity receipt) {
    final supplierName = _supplierNames[receipt.supplierId] ?? 'Unknown';
    DeleteConfirmationDialog.show(
      context: context,
      itemName: supplierName,
      itemType: 'Purchase Receipt',
      onConfirm: () async {
        await _viewModel.deleteReceipt(receipt.id);
      },
    );
  }

  void _navigateToEdit(PurchaseReceiptEntity receipt) {
    context.push('/purchase-receipt/add', extra: receipt);
  }

  Widget _iconButton(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: PosColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _PurchaseReceiptTableRow extends StatelessWidget {
  final int serialNumber;
  final PurchaseReceiptEntity receipt;
  final String supplierName;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _PurchaseReceiptTableRow({
    required this.serialNumber,
    required this.receipt,
    required this.supplierName,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              "$serialNumber",
              style: const TextStyle(fontSize: 13, color: PosColors.textLight),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              dateFormat.format(receipt.date),
              style: const TextStyle(fontSize: 13, color: PosColors.textMain),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              receipt.invoiceNumber,
              style: const TextStyle(fontSize: 13, color: PosColors.textMain),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              supplierName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: PosColors.textMain,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: FutureBuilder<int>(
              future: _getItemCount(),
              builder: (ctx, snap) => Text(
                '${snap.data ?? 0}',
                style: const TextStyle(
                  fontSize: 13,
                  color: PosColors.textLight,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Rs${NumberFormat('#,###.00').format(receipt.totalAmount)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: PosColors.blue,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionIcon(Icons.edit_outlined, Colors.blue, onEdit),
                const SizedBox(width: 8),
                _actionIcon(Icons.delete_outline, Colors.red, onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _getItemCount() async {
    final viewModel = ServiceLocator.instance.purchaseReceiptViewModel;
    final items = await viewModel.getItemsByReceiptId(receipt.id);
    return items.length;
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: PosColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
