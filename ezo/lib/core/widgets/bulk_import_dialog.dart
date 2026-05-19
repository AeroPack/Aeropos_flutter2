import 'package:flutter/material.dart';

Future<void> showBulkImportDialog(BuildContext context) async {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Bulk Import'),
        content: const Text(
          'Bulk import functionality will be implemented here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Add bulk import logic here
              Navigator.of(context).pop();
            },
            child: const Text('Import'),
          ),
        ],
      );
    },
  );
}
