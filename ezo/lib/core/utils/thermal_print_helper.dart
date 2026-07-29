import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../preferences/printer_preferences.dart';
import '../services/thermal_printer_service.dart';

/// Attempts to print [pdfBytes] on the configured Bluetooth thermal printer.
///
/// Returns true if the print was sent successfully. Returns false (showing a
/// snackbar that routes to printer settings, or a connection-failure
/// message) if no printer is configured or connected - callers should fall
/// back to [Printing.layoutPdf] in that case.
Future<bool> tryThermalPrint(BuildContext context, Uint8List pdfBytes) async {
  final prefs = PrinterPreferences();
  if (!await prefs.isConfigured()) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No thermal printer configured'),
        action: SnackBarAction(
          label: 'Set up',
          onPressed: () => context.push('/settings/printer'),
        ),
      ),
    );
    return false;
  }

  final service = ThermalPrinterService.instance;
  if (!await service.isConnected) {
    final printer = await prefs.getPrinter();
    if (printer.address != null) {
      try {
        await service.connect(printer.address!);
      } catch (_) {
        // Handled by the isConnected check below.
      }
    }
  }
  if (!await service.isConnected) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thermal printer is not connected')),
    );
    return false;
  }

  try {
    final engine = await prefs.getEngine();
    final paperWidthMm = await prefs.getPaperWidthMm();
    final labelSize = await prefs.getLabelSize();
    await service.printLabelPdf(
      pdfBytes,
      engine: engine,
      paperWidthMm: paperWidthMm,
      labelSize: labelSize,
    );
    await prefs.updateLastPrinted();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Labels sent to printer')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    }
    return false;
  }
}
