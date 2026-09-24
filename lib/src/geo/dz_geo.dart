import '../text/search_fold.dart';
import 'data/communes.g.dart';
import 'data/wilayas.g.dart';
import 'models.dart';

/// Algerian administrative geography: wilayas and communes.
abstract final class DzGeo {
  /// Version of the bundled dataset. Bumped whenever the data changes.
  static const String dataVersion = '2026.1';

  /// Date the Wikidata snapshot behind the dataset was taken.
  static const String snapshotDate = wikidataSnapshotDate;

  /// The division the dataset models as current: 69 wilayas (law 26-06).
  ///
  /// Law 26-06 gives the mother wilayas until 31 December 2026 to hand over
  /// their powers, so some systems still use the 58 codes. Pass
  /// [DzDivision.law2019] to the lookups for those.
  static const DzDivision currentDivision = DzDivision.law2026;

  static final Map<int, Wilaya> _byCode = {
    for (final w in wilayaData) w.code: w,
  };
  static final Map<String, Commune> _byId = {
    for (final c in communeData) c.wikidataId: c,
  };

  /// All wilayas under [division], ordered by code.
  static List<Wilaya> wilayas({DzDivision division = DzDivision.law2026}) =>
      division == DzDivision.law2026
          ? wilayaData
          : wilayaData.where((w) => w.code <= 58).toList(growable: false);

  /// The wilaya with [code] (1 to 69), or null.
  static Wilaya? wilaya(int code) => _byCode[code];

  /// The wilaya with a code written as text: `5`, `05` or `DZ-05`.
  static Wilaya? wilayaByCode(String code) {
    final m = RegExp(r'^\s*(?:DZ-)?0*([0-9]{1,2})\s*$', caseSensitive: false)
        .firstMatch(code);
    return m == null ? null : _byCode[int.parse(m.group(1)!)];
  }

  /// All 1541 communes.
  static List<Commune> get communes => communeData;

  /// The commune with Wikidata id [wikidataId], or null.
  static Commune? commune(String wikidataId) => _byId[wikidataId];

  /// The communes of wilaya [wilayaCode] under [division], in alphabetical
  /// order of their French names.
  static List<Commune> communesOf(
    int wilayaCode, {
    DzDivision division = DzDivision.law2026,
  }) =>
      communeData
          .where((c) => c.wilayaCodeFor(division) == wilayaCode)
          .toList(growable: false);

  /// Wilayas whose Arabic, French or English name matches [query],
  /// ignoring accents, case, spaces and punctuation; or whose code equals
  /// [query] if it is a number.
  ///
  /// Exact matches come first, then prefix matches, then substring matches.
  static List<Wilaya> searchWilayas(
    String query, {
    DzDivision division = DzDivision.law2026,
  }) {
    final q = foldForSearch(query);
    if (q.isEmpty) return const [];
    final code = int.tryParse(q);
    if (code != null) {
      final w = _byCode[code];
      final inDivision =
          w != null && (division == DzDivision.law2026 || w.code <= 58);
      return inDivision ? [w] : const [];
    }
    return _rank(
      wilayas(division: division),
      q,
      (w) => [w.nameFr, w.nameAr, w.nameEn],
    );
  }

  /// Communes whose Arabic or French name matches [query], ranked like
  /// [searchWilayas]. Restrict to one wilaya with [wilayaCode], read under
  /// [division].
  static List<Commune> searchCommunes(
    String query, {
    int? wilayaCode,
    DzDivision division = DzDivision.law2026,
  }) {
    final q = foldForSearch(query);
    if (q.isEmpty) return const [];
    final pool = wilayaCode == null
        ? communeData
        : communeData.where((c) => c.wilayaCodeFor(division) == wilayaCode);
    return _rank(pool, q, (c) => [c.nameFr, c.nameAr]);
  }

  static List<T> _rank<T>(
    Iterable<T> items,
    String q,
    List<String> Function(T) names,
  ) {
    final scored = <(int, int, T)>[];
    var index = 0;
    for (final item in items) {
      var best = 3;
      for (final name in names(item)) {
        final f = _folded.putIfAbsent(name, () => foldForSearch(name));
        final s = f == q
            ? 0
            : f.startsWith(q)
                ? 1
                : f.contains(q)
                    ? 2
                    : 3;
        if (s < best) best = s;
      }
      if (best < 3) scored.add((best, index, item));
      index++;
    }
    scored.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    return [for (final s in scored) s.$3];
  }

  static final Map<String, String> _folded = {};
}
