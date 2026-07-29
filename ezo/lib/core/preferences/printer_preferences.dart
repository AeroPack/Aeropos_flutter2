import 'package:shared_preferences/shared_preferences.dart';

enum PrinterEngine { escPos, tspl }

/// Label size presets supported by the TSPL print path. Values match the
/// physical die-cut/continuous label stock the printer is loaded with -
/// picking the wrong one prints a mis-scaled label, so this must be
/// calibrated against the user's real label roll.
enum TsplLabelSize {
  mm78x60,
  mm78x100,
  mm78x120,
  mm80x80,
  mm100x100,
  mm100x150,
  mm102x127,
  mm58Cont,
  mm80Cont,
}

extension TsplLabelSizeLabel on TsplLabelSize {
  String get displayName {
    switch (this) {
      case TsplLabelSize.mm78x60:
        return '78 x 60 mm';
      case TsplLabelSize.mm78x100:
        return '78 x 100 mm';
      case TsplLabelSize.mm78x120:
        return '78 x 120 mm';
      case TsplLabelSize.mm80x80:
        return '80 x 80 mm';
      case TsplLabelSize.mm100x100:
        return '100 x 100 mm';
      case TsplLabelSize.mm100x150:
        return '100 x 150 mm';
      case TsplLabelSize.mm102x127:
        return '102 x 127 mm';
      case TsplLabelSize.mm58Cont:
        return '58 mm (continuous)';
      case TsplLabelSize.mm80Cont:
        return '80 mm (continuous)';
    }
  }
}

/// Per-device Bluetooth thermal/label printer configuration.
class PrinterPreferences {
  static const _keyDeviceName = 'printer_device_name';
  static const _keyDeviceAddress = 'printer_device_address';
  static const _keyEngine = 'printer_engine';
  static const _keyPaperWidthMm = 'printer_paper_width_mm';
  static const _keyLabelSize = 'printer_label_size';
  static const _keyLastPrinted = 'printer_last_printed';

  Future<void> savePrinter({
    required String name,
    required String address,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceName, name);
    await prefs.setString(_keyDeviceAddress, address);
  }

  Future<({String? name, String? address})> getPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      name: prefs.getString(_keyDeviceName),
      address: prefs.getString(_keyDeviceAddress),
    );
  }

  Future<bool> isConfigured() async {
    final printer = await getPrinter();
    return printer.address != null && printer.address!.isNotEmpty;
  }

  Future<void> clearPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceName);
    await prefs.remove(_keyDeviceAddress);
    await prefs.remove(_keyLastPrinted);
  }

  Future<void> setEngine(PrinterEngine engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEngine, engine.name);
  }

  Future<PrinterEngine> getEngine() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyEngine);
    return PrinterEngine.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PrinterEngine.escPos,
    );
  }

  /// ESC/POS raster width in mm (58 or 80). Only used by the ESC/POS engine.
  Future<void> setPaperWidthMm(int widthMm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPaperWidthMm, widthMm);
  }

  Future<int> getPaperWidthMm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPaperWidthMm) ?? 58;
  }

  /// Only used by the TSPL engine.
  Future<void> setLabelSize(TsplLabelSize size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLabelSize, size.name);
  }

  Future<TsplLabelSize> getLabelSize() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyLabelSize);
    return TsplLabelSize.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TsplLabelSize.mm58Cont,
    );
  }

  Future<void> updateLastPrinted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastPrinted, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastPrinted() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyLastPrinted);
    return value == null ? null : DateTime.tryParse(value);
  }
}
