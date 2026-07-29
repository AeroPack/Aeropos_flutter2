import 'dart:convert';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:smart_printer_flutter/smart_printer_flutter.dart';

import '../preferences/printer_preferences.dart';

/// ESC/POS raster dots-per-mm at 203dpi, the common resolution for cheap
/// Bluetooth thermal printers (58mm -> 384 dots, 80mm -> 576 dots).
const _escPosDotsPerMm = 384 / 58;

const _tsplLabelSizeValues = {
  TsplLabelSize.mm78x60: LabelSize.mm78x60,
  TsplLabelSize.mm78x100: LabelSize.mm78x100,
  TsplLabelSize.mm78x120: LabelSize.mm78x120,
  TsplLabelSize.mm80x80: LabelSize.mm80x80,
  TsplLabelSize.mm100x100: LabelSize.mm100x100,
  TsplLabelSize.mm100x150: LabelSize.mm100x150,
  TsplLabelSize.mm102x127: LabelSize.mm102x127,
  TsplLabelSize.mm58Cont: LabelSize.mm58Cont,
  TsplLabelSize.mm80Cont: LabelSize.mm80Cont,
};

/// Wraps [SmartPrinterFlutter] (classic Bluetooth thermal/label printer).
///
/// Singleton: the underlying plugin already holds a single native
/// connection, so a second instance would just duplicate stream listeners.
class ThermalPrinterService {
  ThermalPrinterService._internal();
  static final ThermalPrinterService instance = ThermalPrinterService._internal();

  final _plugin = SmartPrinterFlutter();

  Future<void> startScan() => _plugin.startScan();
  Future<void> stopScan() => _plugin.stopScan();
  Stream<bool> get isScanningStream => _plugin.isScanningStream;
  Stream<List<Peripheral>> get peripheralsStream => _plugin.peripheralsStream;
  Stream<PrinterStatus> get statusStream => _plugin.statusStream;

  /// [address] is the classic Bluetooth MAC address from [Peripheral.uuid].
  Future<void> connect(String address) => _plugin.connectBluetooth(address);
  Future<void> disconnect() => _plugin.disconnect();
  Future<bool> get isConnected => _plugin.isConnected;
  Future<Peripheral?> getConnectedDevice() => _plugin.getConnectedDevice();

  /// Prints a PDF (as produced by the existing barcode label generator)
  /// on the connected thermal printer.
  ///
  /// ESC/POS: rasterizes each page to a bitmap and sends it as an image.
  /// TSPL: hands the PDF bytes directly to the printer's native PDF
  /// renderer, scaled to [labelSize] - the physical label stock must match
  /// [labelSize] or the print will be mis-scaled.
  Future<void> printLabelPdf(
    Uint8List pdfBytes, {
    required PrinterEngine engine,
    int paperWidthMm = 58,
    TsplLabelSize labelSize = TsplLabelSize.mm58Cont,
  }) async {
    if (engine == PrinterEngine.tspl) {
      await _plugin.tsplPrintPDFBase64(
        base64Encode(pdfBytes),
        _tsplLabelSizeValues[labelSize]!,
      );
      return;
    }

    final widthDots = (paperWidthMm * _escPosDotsPerMm).round();
    await for (final page in Printing.raster(pdfBytes, dpi: 203)) {
      final png = await page.toPng();
      await _plugin.posPrintImage(base64Encode(png), widthDots.toDouble());
    }
  }
}
