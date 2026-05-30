import 'package:aeropos/core/database/app_database.dart';

sealed class BarcodeResult {}

final class BarcodeMatched extends BarcodeResult {
  final ProductEntity product;
  final ProductUnitEntity unit;
  BarcodeMatched({required this.product, required this.unit});
}

final class BarcodeNotFound extends BarcodeResult {
  final String rawCode;
  BarcodeNotFound(this.rawCode);
}

final class BarcodeMultiVariant extends BarcodeResult {
  final String rawCode;
  final List<({ProductEntity product, ProductUnitEntity unit})> matches;
  BarcodeMultiVariant(this.rawCode, this.matches);
}

final class BarcodePriceEmbedded extends BarcodeResult {
  final String productLinkCode;
  final double embeddedPrice;
  BarcodePriceEmbedded({required this.productLinkCode, required this.embeddedPrice});
}

final class BarcodeWeightEmbedded extends BarcodeResult {
  final String productLinkCode;
  final double weightKg;
  BarcodeWeightEmbedded({required this.productLinkCode, required this.weightKg});
}


