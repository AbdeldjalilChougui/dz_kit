import 'dz_geo.dart';

/// Which administrative division a lookup follows.
enum DzDivision {
  /// 58 wilayas: law 84-09 as amended by law 19-12 (2019) and ordinance
  /// 21-03 (2021). Use this for systems that still store the 58 codes.
  law2019,

  /// 69 wilayas: law 26-06 of 4 April 2026, with names fixed by presidential
  /// decree 26-206 of 25 May 2026. The division in force.
  law2026,
}

/// An Algerian wilaya (province).
class Wilaya {
  /// Creates a wilaya record. The package ships the full list; use
  /// [DzGeo.wilayas] instead of building your own.
  const Wilaya({
    required this.code,
    required this.nameAr,
    required this.nameFr,
    required this.nameEn,
    required this.latitude,
    required this.longitude,
    this.motherCode,
    this.wikidataId,
  });

  /// Official number, 1 to 69.
  final int code;

  /// Arabic name.
  final String nameAr;

  /// French (official Latin) name.
  final String nameFr;

  /// English name.
  final String nameEn;

  /// Latitude of the centre point: the chef-lieu (seat) commune.
  final double latitude;

  /// Longitude of the centre point: the chef-lieu (seat) commune.
  final double longitude;

  /// For the wilayas created by law 26-06 (59 to 69), the code of the
  /// wilaya they were split from. Null otherwise.
  final int? motherCode;

  /// Wikidata item id, or null if Wikidata has no item for it yet.
  final String? wikidataId;

  /// The code zero-padded to two digits, as on licence plates: `05`.
  String get codeString => code.toString().padLeft(2, '0');

  /// The communes of this wilaya under the 2026 division.
  List<Commune> get communes => DzGeo.communesOf(code);

  @override
  String toString() => 'Wilaya($codeString $nameFr)';
}

/// An Algerian commune (baladiya).
class Commune {
  /// Creates a commune record. The package ships the full list; use
  /// [DzGeo.communes] instead of building your own.
  const Commune({
    required this.wikidataId,
    required this.nameAr,
    required this.nameFr,
    required this.wilayaCode,
    required this.wilayaCode2019,
    this.dairaAr,
    this.dairaFr,
    this.latitude,
    this.longitude,
  });

  /// Wikidata item id, a stable identifier for the commune.
  final String wikidataId;

  /// Arabic name.
  final String nameAr;

  /// French (Latin) name.
  final String nameFr;

  /// Wilaya code under the 69-wilaya division (law 26-06).
  final int wilayaCode;

  /// Wilaya code under the 58-wilaya division (before law 26-06).
  final int wilayaCode2019;

  /// Arabic name of the daïra, or null if the source has none.
  final String? dairaAr;

  /// French name of the daïra, or null if the source has none.
  final String? dairaFr;

  /// Latitude of the commune, or null if the source has none.
  final double? latitude;

  /// Longitude of the commune, or null if the source has none.
  final double? longitude;

  /// The wilaya code under [division].
  int wilayaCodeFor(DzDivision division) =>
      division == DzDivision.law2026 ? wilayaCode : wilayaCode2019;

  /// The wilaya of this commune under the 2026 division.
  Wilaya get wilaya => DzGeo.wilaya(wilayaCode)!;

  @override
  String toString() => 'Commune($nameFr, wilaya $wilayaCode)';
}
