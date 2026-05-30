import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gs1_barcode_parser/gs1_barcode_parser.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/features/pos/state/barcode_state.dart';

class BarcodeService {
  static const _minCodeLength = 4;
  static const _priceEmbedPrefixes = ['02', '20'];
  static const _weightEmbedPrefixes = ['21', '23', '24', '25', '28', '29'];

  Future<BarcodeResult> resolve(String rawCode) async {
    final code = rawCode.trim();
    if (code.length < _minCodeLength) return BarcodeNotFound(code);

    if (_isPriceEmbedded(code)) return _decodePriceEmbedded(code);
    if (_isWeightEmbedded(code)) return _decodeWeightEmbedded(code);
    if (_isGs1(code)) return _resolveGs1(code);

    final db = ServiceLocator.instance.database;
    final matches = await db.getProductsByBarcode(code);
    if (matches.length > 1) return BarcodeMultiVariant(code, matches);
    if (matches.length == 1) {
      final match = matches.first;
      return BarcodeMatched(product: match.product, unit: match.unit);
    }

    // --- TOTAL MISS ---
    return BarcodeNotFound(code);
  }

  bool _isPriceEmbedded(String code) =>
      code.length == 13 && _priceEmbedPrefixes.any(code.startsWith);

  BarcodeResult _decodePriceEmbedded(String code) {
    final productLinkCode = code.substring(2, 7);
    final price = int.tryParse(code.substring(7, 12));
    if (price == null) return BarcodeNotFound(code);
    return BarcodePriceEmbedded(
      productLinkCode: productLinkCode,
      embeddedPrice: price / 100.0,
    );
  }

  bool _isWeightEmbedded(String code) =>
      code.length == 13 && _weightEmbedPrefixes.any(code.startsWith);

  BarcodeResult _decodeWeightEmbedded(String code) {
    final productLinkCode = code.substring(2, 7);
    final weightRaw = int.tryParse(code.substring(7, 12));
    if (weightRaw == null) return BarcodeNotFound(code);
    return BarcodeWeightEmbedded(
      productLinkCode: productLinkCode,
      weightKg: weightRaw / 1000.0,
    );
  }

  bool _isGs1(String code) => code.startsWith('(') || code.contains('\x1d');

  Future<BarcodeResult> _resolveGs1(String code) async {
    try {
      final parsed = GS1BarcodeParser.defaultParser().parse(code);
      final gtin = parsed.getAIRawData('01') ?? parsed.getAIRawData('00');
      if (gtin == null) return BarcodeNotFound(code);
      final db = ServiceLocator.instance.database;
      final matches = await db.getProductsByBarcode(gtin);
      if (matches.isEmpty) return BarcodeNotFound(gtin);
      if (matches.length > 1) return BarcodeMultiVariant(code, matches);
      final match = matches.first;
      return BarcodeMatched(product: match.product, unit: match.unit);
    } catch (_) {
      return BarcodeNotFound(code);
    }
  }
}

final barcodeServiceProvider = Provider<BarcodeService>((ref) => BarcodeService());
