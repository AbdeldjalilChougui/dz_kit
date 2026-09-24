import 'digits.dart';

/// An Algérie Poste CCP (compte courant postal) account number with its
/// 2-digit key (clé).
///
/// The key is the sum of the account digits weighted 4, 5, 6, ... 13 from
/// the rightmost digit, modulo 100. For example CCP 200 has key 12
/// (0 × 4 + 0 × 5 + 2 × 6).
class CcpAccount {
  const CcpAccount._(this.number, this.key);

  /// Creates an account from its number and computes the key.
  ///
  /// Throws a [FormatException] unless [number] is 1 to 10 digits.
  factory CcpAccount.fromNumber(String number) {
    final n = _normalizeNumber(number);
    return CcpAccount._(n, _key(n));
  }

  /// Parses an account number followed by its key, such as `200 12`,
  /// `200/12`, `0000000200-12` or `200 clé 12`.
  ///
  /// Returns null if the input is malformed or the key does not match the
  /// number.
  static CcpAccount? tryParse(String input) {
    final m = RegExp(
      r'^\s*([0-9]{1,10})\s*(?:[/\-]|\s|cl[ée]|key)+\s*([0-9]{2})\s*$',
      caseSensitive: false,
    ).firstMatch(input);
    if (m == null) return null;
    final number = _normalizeNumber(m.group(1)!);
    final key = m.group(2)!;
    return _key(number) == key ? CcpAccount._(number, key) : null;
  }

  /// Computes the 2-digit key of a CCP account [number] (1 to 10 digits,
  /// leading zeros allowed).
  ///
  /// Throws a [FormatException] for anything else.
  static String computeKey(String number) => _key(_normalizeNumber(number));

  /// The account number without leading zeros.
  final String number;

  /// The 2-digit key.
  final String key;

  /// The account number zero-padded to 10 digits, as used in the RIP.
  String get paddedNumber => number.padLeft(10, '0');

  /// The 20-digit RIP (relevé d'identité postale) of this account.
  String get rip => '00799999$paddedNumber${_ripKey(paddedNumber)}';

  @override
  bool operator ==(Object other) =>
      other is CcpAccount && other.number == number && other.key == key;

  @override
  int get hashCode => Object.hash(number, key);

  /// The account as `number key`, for example `200 12`.
  @override
  String toString() => '$number $key';
}

/// The Algérie Poste RIP (relevé d'identité postale): 20 digits made of the
/// bank code `007`, the agency code `99999`, the 10-digit CCP account number
/// and a 2-digit key.
///
/// The key is `97 - ((N × 100) mod 97)` where N is the 15-digit number formed
/// by the agency code `99999` followed by the zero-padded account number. It
/// ranges from 01 to 97.
abstract final class Rip {
  /// The bank code of Algérie Poste.
  static const String bankCode = '007';

  /// The agency code used by every CCP account.
  static const String agencyCode = '99999';

  /// Computes the 2-digit RIP key of a CCP account [ccpNumber].
  ///
  /// Throws a [FormatException] unless [ccpNumber] is 1 to 10 digits.
  static String computeKey(String ccpNumber) =>
      _ripKey(_normalizeNumber(ccpNumber).padLeft(10, '0'));

  /// Builds the 20-digit RIP of a CCP account [ccpNumber].
  ///
  /// Throws a [FormatException] unless [ccpNumber] is 1 to 10 digits.
  static String fromCcp(String ccpNumber) =>
      CcpAccount.fromNumber(ccpNumber).rip;

  /// Whether [rip] is a well-formed Algérie Poste RIP with a correct key.
  /// Spaces, dashes and dots are ignored.
  static bool isValid(String rip) => _split(rip) != null;

  /// The CCP account (with its CCP key) contained in a valid [rip], or null.
  static CcpAccount? toCcp(String rip) {
    final account = _split(rip);
    return account == null ? null : CcpAccount.fromNumber(account);
  }

  /// Formats a valid [rip] as printed by Algérie Poste:
  /// `007 99999 0000000200 91`. Returns null if [rip] is not valid.
  static String? format(String rip) {
    final account = _split(rip);
    if (account == null) return null;
    return '$bankCode $agencyCode $account ${_ripKey(account)}';
  }

  static String? _split(String rip) {
    final d = digitsOnly(rip);
    if (d == null || d.length != 20) return null;
    if (!d.startsWith('$bankCode$agencyCode')) return null;
    final account = d.substring(8, 18);
    return _ripKey(account) == d.substring(18) ? account : null;
  }
}

String _normalizeNumber(String number) {
  final d = number.trim();
  if (!RegExp(r'^[0-9]{1,10}$').hasMatch(d)) {
    throw FormatException('A CCP number is 1 to 10 digits', number);
  }
  final stripped = d.replaceFirst(RegExp('^0+'), '');
  return stripped.isEmpty ? '0' : stripped;
}

String _key(String number) {
  final padded = number.padLeft(10, '0');
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    // Weight 4 for the rightmost digit, 13 for the leftmost.
    sum += (padded.codeUnitAt(9 - i) - 0x30) * (4 + i);
  }
  return (sum % 100).toString().padLeft(2, '0');
}

String _ripKey(String paddedNumber) {
  final r = modDecimal('${Rip.agencyCode}${paddedNumber}00', 97);
  return (97 - r).toString().padLeft(2, '0');
}
