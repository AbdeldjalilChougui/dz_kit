/// Folds [input] into a key for accent-, case- and punctuation-insensitive
/// search in Latin and Arabic script.
///
/// - Latin letters are lower-cased and stripped of accents
///   (`Sétif` becomes `setif`, `Œ` becomes `oe`).
/// - Arabic diacritics (harakat, shadda, sukun, superscript alef) and the
///   tatweel are removed; hamza-carrying alefs become a bare alef, `ى` becomes
///   `ي`, `ة` becomes `ه`, `ؤ` becomes `و` and `ئ` becomes `ي`.
/// - Arabic-Indic and Persian digits become ASCII digits.
/// - Everything that is not a letter or a digit (spaces, apostrophes,
///   hyphens, dots) is dropped.
///
/// Two strings that should match in a search box fold to strings where one
/// contains the other.
String foldForSearch(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    final mapped = _foldRune(rune);
    if (mapped != null) out.write(mapped);
  }
  return out.toString();
}

String? _foldRune(int r) {
  // ASCII fast path.
  if (r >= 0x30 && r <= 0x39) return String.fromCharCode(r);
  if (r >= 0x61 && r <= 0x7A) return String.fromCharCode(r);
  if (r >= 0x41 && r <= 0x5A) return String.fromCharCode(r + 0x20);
  if (r < 0x80) return null;

  final latin = _latin[r];
  if (latin != null) return latin;

  // Arabic-Indic digits U+0660..U+0669 and extended (Persian) U+06F0..U+06F9.
  if (r >= 0x0660 && r <= 0x0669) return String.fromCharCode(0x30 + r - 0x0660);
  if (r >= 0x06F0 && r <= 0x06F9) return String.fromCharCode(0x30 + r - 0x06F0);

  // Arabic diacritics and tatweel.
  if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640) return null;
  if (r >= 0x0610 && r <= 0x061A) return null;

  switch (r) {
    case 0x0622: // آ
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0671: // ٱ
      return 'ا';
    case 0x0649: // ى
    case 0x0626: // ئ
    case 0x06CC: // Persian yeh
      return 'ي';
    case 0x0629: // ة
      return 'ه';
    case 0x0624: // ؤ
      return 'و';
    case 0x06A9: // Persian keheh
      return 'ك';
  }

  // Keep other Arabic letters.
  if (r >= 0x0621 && r <= 0x064A) return String.fromCharCode(r);
  if (r >= 0x0671 && r <= 0x06D3) return String.fromCharCode(r);

  // Other letters in the Latin-1 and Latin Extended-A blocks that have no
  // mapping, and all punctuation or symbols, are dropped.
  return null;
}

const Map<int, String> _latin = {
  0xC0: 'a', 0xC1: 'a', 0xC2: 'a', 0xC3: 'a', 0xC4: 'a', 0xC5: 'a', //
  0xC6: 'ae', 0xC7: 'c', 0xC8: 'e', 0xC9: 'e', 0xCA: 'e', 0xCB: 'e',
  0xCC: 'i', 0xCD: 'i', 0xCE: 'i', 0xCF: 'i', 0xD1: 'n', 0xD2: 'o',
  0xD3: 'o', 0xD4: 'o', 0xD5: 'o', 0xD6: 'o', 0xD8: 'o', 0xD9: 'u',
  0xDA: 'u', 0xDB: 'u', 0xDC: 'u', 0xDD: 'y', 0xDF: 'ss',
  0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE4: 'a', 0xE5: 'a',
  0xE6: 'ae', 0xE7: 'c', 0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e',
  0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i', 0xF1: 'n', 0xF2: 'o',
  0xF3: 'o', 0xF4: 'o', 0xF5: 'o', 0xF6: 'o', 0xF8: 'o', 0xF9: 'u',
  0xFA: 'u', 0xFB: 'u', 0xFC: 'u', 0xFD: 'y', 0xFF: 'y',
  0x0100: 'a', 0x0101: 'a', 0x0102: 'a', 0x0103: 'a', 0x0104: 'a',
  0x0105: 'a', 0x0106: 'c', 0x0107: 'c', 0x010C: 'c', 0x010D: 'c',
  0x0112: 'e', 0x0113: 'e', 0x0116: 'e', 0x0117: 'e', 0x0118: 'e',
  0x0119: 'e', 0x011A: 'e', 0x011B: 'e', 0x011E: 'g', 0x011F: 'g',
  0x012A: 'i', 0x012B: 'i', 0x0130: 'i', 0x0131: 'i', 0x0141: 'l',
  0x0142: 'l', 0x0143: 'n', 0x0144: 'n', 0x0147: 'n', 0x0148: 'n',
  0x014C: 'o', 0x014D: 'o', 0x0150: 'o', 0x0151: 'o', 0x0152: 'oe',
  0x0153: 'oe', 0x0158: 'r', 0x0159: 'r', 0x015A: 's', 0x015B: 's',
  0x015E: 's', 0x015F: 's', 0x0160: 's', 0x0161: 's', 0x0162: 't',
  0x0163: 't', 0x0164: 't', 0x0165: 't', 0x016A: 'u', 0x016B: 'u',
  0x016E: 'u', 0x016F: 'u', 0x0170: 'u', 0x0171: 'u', 0x0178: 'y',
  0x0179: 'z', 0x017A: 'z', 0x017B: 'z', 0x017C: 'z', 0x017D: 'z',
  0x017E: 'z',
};
