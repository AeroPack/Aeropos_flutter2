import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/viewModel/customer_transaction_view_model.dart';
import 'package:aeropos/core/viewModel/customer_view_model.dart';
import 'package:aeropos/core/models/customer_transaction.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/widgets/customer_form_dialog.dart';
import 'package:intl/intl.dart';

class AddCustomerLedgerScreen extends StatefulWidget {
  final CustomerEntity? customer;

  const AddCustomerLedgerScreen({super.key, this.customer});

  @override
  State<AddCustomerLedgerScreen> createState() =>
      _AddCustomerLedgerScreenState();
}

class _AddCustomerLedgerScreenState extends State<AddCustomerLedgerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  final _dateController = TextEditingController();

  late CustomerTransactionViewModel _viewModel;
  late CustomerViewModel _customerViewModel;
  int? _selectedCustomerId;
  CustomerEntity? _selectedCustomer;
  TransactionType _selectedType = TransactionType.debit;

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.instance.customerTransactionViewModel;
    _customerViewModel = ServiceLocator.instance.customerViewModel;
    _viewModel.loadCustomers();
    _selectedCustomerId = widget.customer?.id;
    if (_selectedCustomerId != null) {
      _selectedCustomer = _viewModel.customers.firstWhere(
        (c) => c.id == _selectedCustomerId,
        orElse: () => _viewModel.customers.first,
      );
    }
    _dateController.text = DateTime.now().toString().split(' ')[0];
  }

  void _onCustomerChanged(int? customerId) {
    if (customerId != null) {
      final customer = _viewModel.customers.firstWhere(
        (c) => c.id == customerId,
      );
      setState(() {
        _selectedCustomerId = customerId;
        _selectedCustomer = customer;
      });
    } else {
      setState(() {
        _selectedCustomerId = null;
        _selectedCustomer = null;
      });
    }
  }

  Future<void> _openAddCustomerDialog() async {
    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(
        onSubmit:
            ({
              required String name,
              String? phone,
              String? email,
              String? gstin,
              String? address,
              required double creditLimit,
            }) async {
              final newCustomer = await _customerViewModel.addCustomer(
                name: name,
                phone: phone,
                email: email,
                gstin: gstin,
                address: address,
                creditLimit: creditLimit,
              );
              await _viewModel.loadCustomers();
              if (mounted) {
                setState(() {
                  _selectedCustomerId = newCustomer.id;
                  _selectedCustomer = newCustomer;
                });
              }
            },
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedCustomer != null) {
      final amount = double.parse(_amountController.text);
      final newBalance = _selectedType == TransactionType.credit
          ? _selectedCustomer!.currentBalance - amount
          : _selectedCustomer!.currentBalance + amount;

      final updatedCustomer = _selectedCustomer!.copyWith(
        currentBalance: newBalance,
        updatedAt: DateTime.now(),
      );
      await ServiceLocator.instance.database.updateCustomer(updatedCustomer);

      await _viewModel.addTransaction(
        customerId: _selectedCustomerId!.toString(),
        amount: amount,
        type: _selectedType,
        remarks: _remarksController.text.isNotEmpty
            ? _remarksController.text
            : null,
      );

      await _viewModel.loadCustomers();
      if (mounted) {
        final updated = _viewModel.customers.firstWhere(
          (c) => c.id == _selectedCustomerId,
        );
        setState(() {
          _selectedCustomer = updated;
        });
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Add Transaction',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputCard(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E4E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _labeledField("Customer Name", _buildCustomerDropdown()),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _labeledField(
                  "Date",
                  _buildTextField(
                    _dateController,
                    "Select Date",
                    suffix: Icons.calendar_today_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _labeledField(
                  "Amount",
                  _buildTextField(_amountController, "Enter Amount"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _labeledField(
                  "Remarks",
                  _buildTextField(_remarksController, "Remarks if any"),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(top: 25.0),
                  child: _buildTransactionToggle(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _labeledField(
                  "Customer Name",
                  _readOnlyField(_selectedCustomer?.name ?? "-"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField(
                  "Mobile",
                  _readOnlyField(_selectedCustomer?.phone ?? "-"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField(
                  "Current Balance",
                  _readOnlyField(
                    _selectedCustomer != null
                        ? "Rs${NumberFormat('#,###.00').format(_selectedCustomer!.currentBalance)}"
                        : "-",
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField(
                  "Address",
                  _readOnlyField(_selectedCustomer?.address ?? "-"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _labeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Color(0xFF444444),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildCustomerDropdown() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _selectedCustomerId,
            decoration: _inputDecoration("Select Customer"),
            items: _viewModel.customers
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: widget.customer != null
                ? null
                : (v) => _onCustomerChanged(v),
            validator: (v) => v == null ? 'Select customer' : null,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _openAddCustomerDialog,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF001F3F),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _readOnlyField(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF333333), fontSize: 14),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    IconData? suffix,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(hint).copyWith(
        suffixIcon: suffix != null
            ? Icon(suffix, size: 18, color: Colors.grey)
            : null,
      ),
    );
  }

  Widget _buildTransactionToggle() {
    return Row(
      children: [
        _toggleBtn(
          "Credit",
          Colors.green,
          _selectedType == TransactionType.credit,
          "(Receive)",
        ),
        const SizedBox(width: 4),
        _toggleBtn(
          "Debit",
          Colors.blue,
          _selectedType == TransactionType.debit,
          "(Give)",
        ),
        const SizedBox(width: 12),
        Text("Selected: ", style: TextStyle(color: Colors.grey.shade700)),
        Text(
          _selectedType.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _toggleBtn(String label, Color color, bool isSelected, String suffix) {
    return InkWell(
      onTap: () => setState(
        () => _selectedType = label == "Credit"
            ? TransactionType.credit
            : TransactionType.debit,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          border: Border.all(color: color),
          borderRadius: label == "Credit"
              ? const BorderRadius.horizontal(left: Radius.circular(4))
              : const BorderRadius.horizontal(right: Radius.circular(4)),
        ),
        child: Text(
          label + (isSelected ? "" : suffix),
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: () => context.pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade600,
            foregroundColor: Colors.white,
            minimumSize: const Size(100, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Text("Cancel"),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D6EFD),
            foregroundColor: Colors.white,
            minimumSize: const Size(100, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Text("Submit"),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
