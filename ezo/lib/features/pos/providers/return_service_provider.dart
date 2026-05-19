import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/features/pos/services/return_service.dart';

final returnServiceProvider = Provider<ReturnService>((ref) {
  return ReturnService();
});

String calculateInvoiceStatus(List items) {
  bool allFullyReturned = true;
  bool anyReturned = false;

  for (final item in items) {
    final soldQty = item.quantity.toDouble();
    final returnedQty = item.returnedQuantity;

    if (returnedQty == 0) {
      allFullyReturned = false;
    } else if (returnedQty < soldQty) {
      anyReturned = true;
      allFullyReturned = false;
    }
  }

  if (allFullyReturned) return 'fully_returned';
  if (anyReturned) return 'partially_returned';
  return 'active';
}
