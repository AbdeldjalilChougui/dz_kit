/// Output style for [Dzd.format].
enum DzdStyle {
  /// French style, as printed on Algerian invoices: `1 234,56 DA`.
  fr,

  /// Arabic style with Latin digits, as used in Algeria: `1 234,56 دج`.
  ar,
}

/// An amount of Algerian dinars, stored as integer centimes.
///
/// There is no floating point anywhere in the arithmetic, so sums never
/// drift. Use [Dzd.fromDinars] only at the boundary where a `double` comes in
/// (a legacy API, a JSON field) and keep [Dzd] everywhere else.
class Dzd implements Comparable<Dzd> {
  /// Creates an amount from integer [centimes] (1 DA = 100 centimes).
  const Dzd(this.centimes);

  /// Creates an amount from a number of dinars.
  ///
  /// The value is rounded to the nearest centime, half away from zero, using
  /// the shortest decimal representation of [dinars]. So `0.995` becomes
  /// 100 centimes (`1,00`) even though the nearest binary double is slightly
  /// below 0.995.
  ///
  /// Throws an [ArgumentError] for NaN, infinity, or values above
  /// 10^13 dinars.
  factory Dzd.fromDinars(num dinars) {
    if (dinars is int) return Dzd(dinars * 100);
    if (dinars.isNaN || dinars.isInfinite) {
      throw ArgumentError.value(dinars, 'dinars', 'must be finite');
    }
    final negative = dinars < 0;
    final c = _decimalToCentimes(dinars.abs().toString());
    if (c == null) {
      throw ArgumentError.value(dinars, 'dinars', 'out of range');
    }
    return Dzd(negative ? -c : c);
  }

  /// The zero amount.
  static const Dzd zero = Dzd(0);

  /// The amount in integer centimes.
  final int centimes;

  /// Whole dinars, truncated toward zero (`-123,45` gives `-123`).
  int get dinars => centimes ~/ 100;

  /// The centimes part, always between 0 and 99 (`-123,45` gives `45`).
  int get centimesPart => centimes.abs() % 100;

  /// Whether the amount is below zero.
  bool get isNegative => centimes < 0;

  /// Whether the amount is exactly zero.
  bool get isZero => centimes == 0;

  /// Sum of two amounts.
  Dzd operator +(Dzd other) => Dzd(centimes + other.centimes);

  /// Difference of two amounts.
  Dzd operator -(Dzd other) => Dzd(centimes - other.centimes);

  /// The negated amount.
  Dzd operator -() => Dzd(-centimes);

  /// The amount multiplied by an integer [quantity].
  Dzd operator *(int quantity) => Dzd(centimes * quantity);

  @override
  int compareTo(Dzd other) => centimes.compareTo(other.centimes);

  @override
  bool operator ==(Object other) => other is Dzd && other.centimes == centimes;

  @override
  int get hashCode => centimes.hashCode;

  /// Formats the amount for display.
  ///
  /// Digit groups are separated by U+202F (narrow no-break space) and the
  /// currency symbol by U+00A0 (no-break space). Both are bidi class CS, so
  /// right-to-left layouts keep `1 234,56` as a single run instead of
  /// reordering the groups the way an ASCII space would.
  ///
  /// - [style] picks the `DA` ([DzdStyle.fr]) or `دج` ([DzdStyle.ar]) suffix.
  /// - [symbol] set to false drops the suffix.
  /// - [omitZeroCentimes] prints `1 500 DA` instead of `1 500,00 DA`.
  ///
  /// In Arabic style a negative number is wrapped in U+2066/U+2069
  /// (left-to-right isolate) so the minus sign stays to the left of the
  /// digits.
  String format({
    DzdStyle style = DzdStyle.fr,
    bool symbol = true,
    bool omitZeroCentimes = false,
  }) {
    final abs = centimes.abs();
    final whole = _group((abs ~/ 100).toString());
    final cents = abs % 100;
    var number = (omitZeroCentimes && cents == 0)
        ? whole
        : '$whole,${cents.toString().padLeft(2, '0')}';
    if (centimes < 0) {
      number = style == DzdStyle.ar ? '\u2066-$number\u2069' : '-$number';
    }
    if (!symbol) return number;
    return '$number\u00A0${style == DzdStyle.ar ? 'دج' : 'DA'}';
  }

  /// Parses user input into an amount, or returns null if it is not a valid
  /// amount.
  ///
  /// Accepted:
  /// - an optional sign (`-`, `+`, `−`);
  /// - digit groups of three separated by spaces, U+00A0, U+202F, U+2009,
  ///   `٬`, or consistently by `.` or `,`;
  /// - a decimal comma, point or `٫` followed by one or two digits;
  /// - Arabic-Indic digits;
  /// - a `DA`, `DZD`, `دج` or `د.ج` marker before or after the number.
  ///
  /// Rejected (null): more than two decimals, malformed groups, and a lone
  /// `.` or `,` followed by exactly three digits (`12.345`), which could be
  /// either a thousands separator or three decimals.
  static Dzd? tryParse(String input) => _parse(input);

  @override
  String toString() => format();
}

String _group(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('\u202F');
    out.write(digits[i]);
  }
  return out.toString();
}

const int _maxDinarDigits = 13;

/// Converts a non-negative decimal string (as produced by `double.toString`)
/// to centimes, rounding half up on the third decimal.
int? _decimalToCentimes(String s) {
  var mantissa = s;
  var exp = 0;
  final e = s.indexOf(RegExp('[eE]'));
  if (e >= 0) {
    mantissa = s.substring(0, e);
    exp = int.parse(s.substring(e + 1));
  }
  final dot = mantissa.indexOf('.');
  final digits = mantissa.replaceAll('.', '');
  final point = (dot < 0 ? mantissa.length : dot) + exp;
  String intPart;
  String frac;
  if (point <= 0) {
    intPart = '0';
    frac = '${'0' * -point}$digits';
  } else if (point >= digits.length) {
    intPart = '$digits${'0' * (point - digits.length)}';
    frac = '';
  } else {
    intPart = digits.substring(0, point);
    frac = digits.substring(point);
  }
  intPart = intPart.replaceFirst(RegExp('^0+(?=.)'), '');
  if (intPart.length > _maxDinarDigits) return null;
  final twoDecimals = int.parse(frac.padRight(2, '0').substring(0, 2));
  final roundUp = frac.length > 2 && frac.codeUnitAt(2) >= 0x35;
  return int.parse(intPart) * 100 + twoDecimals + (roundUp ? 1 : 0);
}

const _spaceGroups = {' ', '\u00A0', '\u202F', '\u2009', '\u066C'};
const _invisible = {'\u2066', '\u2067', '\u2068', '\u2069', '\u200E', '\u200F'};

Dzd? _parse(String input) {
  final buf = StringBuffer();
  for (final r in input.runes) {
    final ch = String.fromCharCode(r);
    if (_invisible.contains(ch)) continue;
    if (r >= 0x0660 && r <= 0x0669) {
      buf.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      buf.writeCharCode(0x30 + r - 0x06F0);
    } else {
      buf.write(ch);
    }
  }
  var s = buf.toString().trim();

  // Currency marker, before or after the number.
  final marker = RegExp(r'^(?:dzd|da|د\.ج|دج)\s*|\s*(?:dzd|da|د\.ج|دج)$',
      caseSensitive: false);
  s = s.replaceFirst(marker, '').trim();
  if (s.isEmpty) return null;

  var negative = false;
  final first = s[0];
  if (first == '-' || first == '+' || first == '\u2212') {
    negative = first != '+';
    s = s.substring(1);
  }
  if (s.isEmpty) return null;

  final hasArabicDecimal = s.contains('\u066B');
  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');

  // Decide which character, if any, is the decimal separator.
  int decimalIndex = -1;
  if (hasArabicDecimal) {
    if ('\u066B'.allMatches(s).length != 1 || lastDot >= 0 || lastComma >= 0) {
      return null;
    }
    decimalIndex = s.indexOf('\u066B');
  } else if (lastDot >= 0 && lastComma >= 0) {
    decimalIndex = lastDot > lastComma ? lastDot : lastComma;
    final decimalChar = s[decimalIndex];
    if (decimalChar.allMatches(s).length != 1) return null;
  } else if (lastDot >= 0 || lastComma >= 0) {
    final sep = lastDot >= 0 ? '.' : ',';
    final count = sep.allMatches(s).length;
    if (count == 1) {
      final after = s.length - s.indexOf(sep) - 1;
      // A lone separator followed by three digits (`12.345`) could be a
      // thousands separator or three decimals: refuse to guess.
      if (after != 1 && after != 2) return null;
      decimalIndex = s.indexOf(sep);
    }
  }

  final intText = decimalIndex >= 0 ? s.substring(0, decimalIndex) : s;
  final fracText = decimalIndex >= 0 ? s.substring(decimalIndex + 1) : '';
  if (decimalIndex >= 0 &&
      (fracText.isEmpty ||
          fracText.length > 2 ||
          !RegExp(r'^\d+$').hasMatch(fracText))) {
    return null;
  }

  // Integer part: digits, optionally grouped by threes.
  final groups = <String>[];
  String? groupKind;
  final current = StringBuffer();
  for (var i = 0; i < intText.length; i++) {
    final ch = intText[i];
    final code = ch.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) {
      current.write(ch);
      continue;
    }
    String kind;
    if (_spaceGroups.contains(ch)) {
      kind = 'space';
    } else if (ch == '.' || ch == ',') {
      kind = ch;
    } else {
      return null;
    }
    if (kind != 'space') {
      if (groupKind != null && groupKind != kind) return null;
      groupKind = kind;
    }
    groups.add(current.toString());
    current.clear();
  }
  groups.add(current.toString());

  if (groups.length > 1) {
    if (groups.first.isEmpty || groups.first.length > 3) return null;
    for (final g in groups.skip(1)) {
      if (g.length != 3) return null;
    }
  }
  final intDigits = groups.join();
  if (intDigits.isEmpty && fracText.isEmpty) return null;
  final trimmed = intDigits.replaceFirst(RegExp('^0+(?=.)'), '');
  if (trimmed.length > _maxDinarDigits) return null;

  final whole = intDigits.isEmpty ? 0 : int.parse(intDigits);
  final cents = fracText.isEmpty ? 0 : int.parse(fracText.padRight(2, '0'));
  final value = whole * 100 + cents;
  return Dzd(negative ? -value : value);
}
