import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';

class DatabaseDebugScreen extends ConsumerWidget {
  const DatabaseDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database Debug')),
      body: FutureBuilder<Map<String, int>>(
        future: _getCounts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final counts = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Tenant ID (Current): ${ServiceLocator.instance.tenantService.tenantId}'),
              const Divider(),
              ...counts.entries.map((e) => ListTile(
                title: Text(e.key),
                trailing: Text(e.value.toString()),
              )),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await ServiceLocator.instance.database.clearAllData();
                  (context as Element).markNeedsBuild();
                },
                child: const Text('Clear All Data'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, int>> _getCounts() async {
    final db = ServiceLocator.instance.database;
    final invoices = await db.select(db.invoices).get();
    final items = await db.select(db.invoiceItems).get();
    final products = await db.select(db.products).get();
    final customers = await db.select(db.customers).get();

    return {
      'Invoices (Total)': invoices.length,
      'Invoice Items (Total)': items.length,
      'Products (Total)': products.length,
      'Customers (Total)': customers.length,
      'Invoices (Tenant 1)': invoices.where((i) => i.tenantId == 1).length,
      'Invoices (Tenant 2)': invoices.where((i) => i.tenantId == 2).length,
    };
  }
}
