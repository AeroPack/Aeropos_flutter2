String buildUpiUri({
  required String upiId,
  required double amount,
  required String invoiceNo,
}) {
  return 'upi://pay?pa=$upiId&am=${amount.toStringAsFixed(2)}&tn=$invoiceNo&cu=INR';
}
