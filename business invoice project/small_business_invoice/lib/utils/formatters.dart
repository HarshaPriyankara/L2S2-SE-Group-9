// Small helpers used by the Expenses screens (no extra packages needed).

/// 1234567.5 -> "Rs. 1,234,567.50"
String formatMoney(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts[0];
  final buffer = StringBuffer();

  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return 'Rs. ${buffer.toString()}.${parts[1]}';
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// DateTime(2026, 10, 14) -> "14 Oct 2026"
String formatDate(DateTime date) {
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}
