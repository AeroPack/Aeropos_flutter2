import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

DatabaseConnection connect() {
  return DatabaseConnection.delayed(
    Future(() async {
      print('[DB-WEB] Starting WasmDatabase.open()...');
      
      try {
        final result = await WasmDatabase.open(
          databaseName: 'ezo_pos_product_master',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.js'),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('[DB-WEB] TIMEOUT → worker or WASM not loading');
            throw Exception('WASM/worker failed to initialize');
          },
        );
        
        print('[DB-WEB] SUCCESS');
        print('[DB-WEB] chosenImplementation=${result.chosenImplementation}');
        return result.resolvedExecutor;
      } catch (e, st) {
        print('[DB-WEB] ERROR: $e');
        print('[DB-WEB] Stack: $st');
        rethrow;
      }
    }),
  );
}