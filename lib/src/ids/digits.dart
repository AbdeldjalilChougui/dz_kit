/// Removes spaces, dashes, dots and slashes, and maps Arabic-Indic digits to
/// ASCII. Returns null if anything else remains or the result is empty.
String? digitsOnly(String input) {
  final out = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x30 && r <= 0x39) {
      out.writeCharCode(r);
    } else if (r >= 0x0660 && r <= 0x0669) {
      out.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      out.writeCharCode(0x30 + r - 0x06F0);
    } else if (r == 0x20 ||
        r == 0x2D ||
        r == 0x2E ||
        r == 0x2F ||
        r == 0xA0 ||
        r == 0x202F ||
        r == 0x2009) {
      continue;
    } else {
      return null;
    }
  }
  return out.isEmpty ? null : out.toString();
}

/// Remainder of the decimal number [digits] divided by [m], computed digit by
/// digit so it never overflows (also on the web, where ints are doubles).
int modDecimal(String digits, int m) {
  var r = 0;
  for (var i = 0; i < digits.length; i++) {
    r = (r * 10 + digits.codeUnitAt(i) - 0x30) % m;
  }
  return r;
}
