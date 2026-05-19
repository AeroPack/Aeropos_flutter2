import 'package:flutter/material.dart';

class SalesReceiptScreen extends StatelessWidget {
  const SalesReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Receipt')),
      body: const Center(child: Text('Sales Receipt - Coming Soon')),
    );
  }
}

class ViewSalesReceiptScreen extends StatelessWidget {
  final dynamic customer;
  const ViewSalesReceiptScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Sales Receipt')),
      body: const Center(child: Text('View Sales Receipt - Coming Soon')),
    );
  }
}

class AddSalesReceiptScreen extends StatelessWidget {
  final dynamic customer;
  const AddSalesReceiptScreen({super.key, this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Sales Receipt')),
      body: const Center(child: Text('Add Sales Receipt - Coming Soon')),
    );
  }
}
