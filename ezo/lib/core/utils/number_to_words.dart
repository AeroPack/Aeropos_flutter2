String convertToIndianRupees(double amount) {
  if (amount < 0) return 'Minus ${_convertToIndianRupees(-amount)}';
  return _convertToIndianRupees(amount);
}

String _convertToIndianRupees(double amount) {
  final wholeNum = amount.floor();
  final paise = ((amount - wholeNum) * 100).round();

  if (wholeNum == 0 && paise == 0) return 'Zero Rupees';

  final wholeStr = wholeNum > 0
      ? '${_numberToIndianWords(wholeNum)} Rupee${wholeNum == 1 ? '' : 's'}'
      : '';
  final paiseStr = paise > 0
      ? '${_numberToWords(paise)} Paise'
      : '';

  if (wholeStr.isNotEmpty && paiseStr.isNotEmpty) {
    return '$wholeStr And $paiseStr Only';
  }
  return '${wholeStr.isNotEmpty ? wholeStr : ''}${paiseStr.isNotEmpty ? paiseStr : ''} Only';
}

String _numberToIndianWords(int n) {
  if (n == 0) return 'Zero';

  final units = <String>['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
  final teens = <String>['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  final tens = <String>['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  String convertBelow1000(int x) {
    if (x == 0) return '';
    if (x < 10) return units[x];
    if (x < 20) return teens[x - 10];
    if (x < 100) {
      final t = x ~/ 10;
      final u = x % 10;
      return '${tens[t]}${u > 0 ? ' ${units[u]}' : ''}';
    }
    final h = x ~/ 100;
    final r = x % 100;
    return '${units[h]} Hundred${r > 0 ? ' ${convertBelow1000(r)}' : ''}';
  }

  // Indian numbering: thousands, lakhs, crores
  final crore = n ~/ 10000000;
  final lakh = (n % 10000000) ~/ 100000;
  final thousand = (n % 100000) ~/ 1000;
  final hundred = n % 1000;

  final parts = <String>[];
  if (crore > 0) parts.add('${convertBelow1000(crore)} Crore');
  if (lakh > 0) parts.add('${convertBelow1000(lakh)} Lakh');
  if (thousand > 0) parts.add('${convertBelow1000(thousand)} Thousand');
  if (hundred > 0) parts.add(convertBelow1000(hundred));

  return parts.join(' ');
}

// Simple helper for paise (below 100, no Indian numbering needed)
String _numberToWords(int n) {
  final units = <String>['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
  final teens = <String>['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  final tens = <String>['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  if (n < 10) return units[n];
  if (n < 20) return teens[n - 10];
  final t = n ~/ 10;
  final u = n % 10;
  return '${tens[t]}${u > 0 ? ' ${units[u]}' : ''}';
}
