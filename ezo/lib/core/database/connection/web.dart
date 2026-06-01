import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

DatabaseConnection connect() {
  return DatabaseConnection.delayed(
    Future(() async {
      debugPrint('[DB-WEB] Starting WasmDatabase.open()...');
      
      try {
        final result = await WasmDatabase.open(
          databaseName: 'ezo_pos_product_master',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.js'),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('[DB-WEB] TIMEOUT → worker or WASM not loading');
            throw Exception('WASM/worker failed to initialize');
          },
        );
        
        debugPrint('[DB-WEB] SUCCESS');
        debugPrint('[DB-WEB] chosenImplementation=${result.chosenImplementation}');
        return result.resolvedExecutor;
      } catch (e, st) {
        debugPrint('[DB-WEB] ERROR: $e');
        debugPrint('[DB-WEB] Stack: $st');
        rethrow;
      }
    }),
  );
}