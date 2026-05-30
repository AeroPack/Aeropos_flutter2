import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class QuickAddProductDialog extends StatefulWidget {
  final String barcode;

  const QuickAddProductDialog({
    super.key,
    required this.barcode,
  });

  @override
  State<QuickAddProductDialog> createState() => _QuickAddProductDialogState();
}

class _QuickAddProductDialogState extends State<QuickAddProductDialog> {
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '1');
  final _nameController = TextEditingController();
  bool _isLoadingName = false;

  @override
  void initState() {
    super.initState();
    _fetchProductNameFromOpenFoodFacts();
  }

  Future<void> _fetchProductNameFromOpenFoodFacts() async {
    setState(() => _isLoadingName = true);
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {'User-Agent': 'AeroPOS_App/1.0'},
      ));

      final response = await dio.get(
        'https://world.openfoodfacts.org/api/v0/product/${widget.barcode}.json',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 1 && data['product'] != null) {
          final productData = data['product'];
          final name = productData['product_name'] ??
              productData['brands'] ??
              '';
          if (name.isNotEmpty && mounted) {
            setState(() => _nameController.text = name);
          }
        }
      }
    } catch (_) {
      // Silent — user can type the name manually
    } finally {
      if (mounted) setState(() => _isLoadingName = false);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _stockController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick Add Product'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: ${widget.barcode}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Product Name',
                border: const OutlineInputBorder(),
                suffixIcon: _isLoadingName
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                helperText: _isLoadingName ? 'Looking up product…' : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Selling Price',
                prefixText: 'Rs ',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Initial Stock',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_priceController.text.isEmpty ||
                _nameController.text.isEmpty) {
              return;
            }
            Navigator.pop(context, {
              'name': _nameController.text,
              'price': double.tryParse(_priceController.text) ?? 0.0,
              'stock': int.tryParse(_stockController.text) ?? 1,
            });
          },
          child: const Text('Save & Bill'),
        ),
      ],
    );
  }
}
