/// Single place for all money formatting in the app.
/// 10100 -> "10,100.00"   |   fmtRs(10100) -> "Rs. 10,100.00"
String fmtMoney(num value) {
  final bool negative = value < 0;
  final String fixed = value.abs().toStringAsFixed(2);
  final String withCommas = fixed.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+\.)'),
    (m) => '${m[1]},',
  );
  return negative ? '-$withCommas' : withCommas;
}

/// Same as [fmtMoney] but with the "Rs. " prefix.
String fmtRs(num value) => 'Rs. ${fmtMoney(value)}';