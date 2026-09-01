/// Groups an integer with commas: 1048576 -> "1,048,576".
///
/// Hand-rolled rather than pulling in `intl` for one call site. The stat tiles
/// print seven-figure pool counts, which are unreadable ungrouped.
String formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return buffer.toString();
}
