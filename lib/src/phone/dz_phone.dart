/// Operator a number range was allocated to by ARPCE.
///
/// Mobile number portability has a legal framework in Algeria (executive
/// decree 21-199), so a subscriber may have moved since. This is the
/// operator of the original allocation, not a live lookup.
enum DzOperator {
  /// Algérie Télécom Mobile (Mobilis), mobile prefix 06.
  mobilis,

  /// Optimum Télécom Algérie (Djezzy), mobile prefix 07.
  djezzy,

  /// Wataniya Télécom Algérie (Ooredoo), mobile prefix 05.
  ooredoo,

  /// Algérie Télécom, geographic (landline) prefixes 02, 03 and 04.
  algerieTelecom,
}

/// Kind of number in the Algerian national numbering plan.
enum DzNumberType {
  /// Mobile: 0 + 5/6/7 + 8 digits.
  mobile,

  /// Geographic landline: 0 + 2/3/4 + 7 digits.
  landline,

  /// Non-geographic VoIP number: 098...
  voip,

  /// VSAT number: 096...
  vsat,

  /// Freephone and value-added services: 080...
  specialService,
}

/// An Algerian telephone number, reduced to its national significant number
/// (NSN): the digits after `+213` or after the leading trunk `0`.
///
/// Two [DzPhoneNumber]s are equal when their full NSNs are equal.
class DzPhoneNumber {
  const DzPhoneNumber._(this.nsn, this.type);

  /// Parses an Algerian number written in any common way:
  /// `0555123456`, `0555 12 34 56`, `00213555123456`, `+213 5 55 12 34 56`,
  /// `+213 (0) 555...`, `213555123456`, or a bare 9-digit mobile number.
  /// Spaces, dashes, dots and parentheses are ignored and Arabic-Indic
  /// digits are accepted.
  ///
  /// Returns null if the input is not a well-formed Algerian number. The
  /// result may still be in a block ARPCE has not allocated; see
  /// [isAllocated].
  static DzPhoneNumber? tryParse(String input) {
    final nsn = _extractNsn(input);
    if (nsn == null) return null;
    final type = _classify(nsn);
    return type == null ? null : DzPhoneNumber._(nsn, type);
  }

  /// The national significant number, without `+213` or the trunk `0`.
  final String nsn;

  /// The kind of number.
  final DzNumberType type;

  /// The number in E.164 format, for example `+213555123456`.
  String get e164 => '+213$nsn';

  /// The number as dialled inside Algeria, for example `0555123456`.
  String get national => '0$nsn';

  /// The operator the number's block is allocated to, or null for VoIP,
  /// VSAT and service numbers, which several operators share.
  DzOperator? get operator {
    switch (type) {
      case DzNumberType.mobile:
        switch (nsn[0]) {
          case '5':
            return DzOperator.ooredoo;
          case '6':
            return DzOperator.mobilis;
          default:
            return DzOperator.djezzy;
        }
      case DzNumberType.landline:
        return DzOperator.algerieTelecom;
      case DzNumberType.voip:
      case DzNumberType.vsat:
      case DzNumberType.specialService:
        return null;
    }
  }

  /// Whether the number falls in a block that ARPCE lists as allocated in
  /// the national numbering plan.
  bool get isAllocated {
    switch (type) {
      case DzNumberType.landline:
        return true;
      case DzNumberType.mobile:
      case DzNumberType.voip:
      case DzNumberType.vsat:
      case DzNumberType.specialService:
        return _allocatedPrefixes.any(nsn.startsWith);
    }
  }

  /// The national number grouped for display: `0555 12 34 56` for 10-digit
  /// numbers and `021 23 45 67` for landlines.
  String formatNational() => '0${_groupNsn()}';

  /// The international number grouped for display: `+213 555 12 34 56`.
  String formatInternational() => '+213 ${_groupNsn()}';

  String _groupNsn() {
    final head = nsn.length == 9 ? nsn.substring(0, 3) : nsn.substring(0, 2);
    final rest = nsn.substring(head.length);
    return '$head ${rest.substring(0, 2)} ${rest.substring(2, 4)} '
        '${rest.substring(4)}';
  }

  /// Whether [other] is the same number (same full NSN).
  bool sameAs(DzPhoneNumber other) => other.nsn == nsn;

  @override
  bool operator ==(Object other) => other is DzPhoneNumber && other.nsn == nsn;

  @override
  int get hashCode => nsn.hashCode;

  /// The E.164 form.
  @override
  String toString() => e164;
}

/// Shortcuts for working with Algerian phone numbers as strings.
abstract final class DzPhone {
  /// The E.164 form (`+213...`) of [input], or null if it is not a
  /// well-formed Algerian number. See [DzPhoneNumber.tryParse] for the
  /// accepted formats.
  static String? normalize(String input) => DzPhoneNumber.tryParse(input)?.e164;

  /// Whether [input] is a well-formed Algerian number in a block allocated
  /// by ARPCE.
  static bool isValid(String input) =>
      DzPhoneNumber.tryParse(input)?.isAllocated ?? false;

  /// The operator of [input]'s block, or null. See [DzPhoneNumber.operator].
  static DzOperator? operatorOf(String input) =>
      DzPhoneNumber.tryParse(input)?.operator;

  /// Whether [a] and [b] are the same Algerian number, comparing the full
  /// national significant number. Invalid input never matches.
  static bool same(String a, String b) {
    final x = DzPhoneNumber.tryParse(a);
    final y = DzPhoneNumber.tryParse(b);
    return x != null && y != null && x.nsn == y.nsn;
  }
}

/// Allocated NSN prefixes for non-geographic ranges, from the ARPCE
/// national numbering plan (https://www.arpce.dz/fr/service/num).
const List<String> _allocatedPrefixes = [
  // Wataniya Télécom Algérie (Ooredoo): 054[0129], 055, 056[012].
  '540', '541', '542', '549', '55', '560', '561', '562',
  // Algérie Télécom Mobile (Mobilis): 065[5-9], 066, 067[0-6], 069[6-9].
  '655', '656', '657', '658', '659', '66', '670', '671', '672', '673', '674',
  '675', '676', '696', '697', '698', '699',
  // Optimum Télécom Algérie (Djezzy): 077, 078[0-4], 079.
  '77', '780', '781', '782', '783', '784', '79',
  // Freephone and value-added services: 080[0-6]1, 0808 0, 0809 1.
  '8001', '8011', '8021', '8031', '8041', '8051', '8061', '8080', '8091',
  // VSAT 0961, VoIP 0982.
  '961', '982',
];

String? _extractNsn(String input) {
  final buf = StringBuffer();
  var sawPlus = false;
  for (final r in input.runes) {
    if (r >= 0x30 && r <= 0x39) {
      buf.writeCharCode(r);
    } else if (r >= 0x0660 && r <= 0x0669) {
      buf.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      buf.writeCharCode(0x30 + r - 0x06F0);
    } else if (r == 0x2B) {
      // '+' is only allowed before any digit, once.
      if (sawPlus || buf.isNotEmpty) return null;
      sawPlus = true;
    } else if (r == 0x20 ||
        r == 0x2D ||
        r == 0x2E ||
        r == 0x28 ||
        r == 0x29 ||
        r == 0xA0 ||
        r == 0x202F ||
        r == 0x2009) {
      continue;
    } else {
      return null;
    }
  }
  var d = buf.toString();
  if (d.isEmpty) return null;

  if (sawPlus) {
    if (!d.startsWith('213')) return null;
    d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
  } else if (d.startsWith('00')) {
    if (!d.startsWith('00213')) return null;
    d = d.substring(5);
    if (d.startsWith('0')) d = d.substring(1);
  } else if (d.startsWith('0')) {
    d = d.substring(1);
  } else if (d.startsWith('213') && (d.length == 11 || d.length == 12)) {
    d = d.substring(3);
  } else if (!(d.length == 9 && '567'.contains(d[0]))) {
    // Without a prefix, only a bare 9-digit mobile number is unambiguous.
    return null;
  }
  return d;
}

DzNumberType? _classify(String nsn) {
  if (nsn.isEmpty) return null;
  final first = nsn[0];
  if (nsn.length == 9) {
    if ('567'.contains(first)) return DzNumberType.mobile;
    if (nsn.startsWith('80')) return DzNumberType.specialService;
    if (nsn.startsWith('96')) return DzNumberType.vsat;
    if (nsn.startsWith('98')) return DzNumberType.voip;
    return null;
  }
  if (nsn.length == 8 && '234'.contains(first)) return DzNumberType.landline;
  return null;
}
