import 'package:dz_kit/dz_kit.dart';
import 'package:test/test.dart';

void main() {
  group('dataset', () {
    test('exposes its version and division', () {
      expect(DzGeo.dataVersion, '2026.1');
      expect(DzGeo.currentDivision, DzDivision.law2026);
    });

    test('has 69 wilayas under law 26-06 and 58 under the 2019 division', () {
      expect(DzGeo.wilayas().length, 69);
      expect(DzGeo.wilayas(division: DzDivision.law2026).length, 69);
      expect(DzGeo.wilayas(division: DzDivision.law2019).length, 58);
      expect(
          DzGeo.wilayas().map((w) => w.code), List.generate(69, (i) => i + 1));
    });

    test('has 1541 communes', () {
      expect(DzGeo.communes.length, 1541);
      expect(DzGeo.communes.map((c) => c.wikidataId).toSet().length, 1541);
    });

    test('every commune has both names and a wilaya in both divisions', () {
      for (final c in DzGeo.communes) {
        expect(c.nameFr.trim(), isNotEmpty, reason: c.wikidataId);
        expect(c.nameAr.trim(), isNotEmpty, reason: c.wikidataId);
        expect(c.wilayaCode, inInclusiveRange(1, 69));
        expect(c.wilayaCode2019, inInclusiveRange(1, 58));
        if (c.wilayaCode <= 58) expect(c.wilayaCode2019, c.wilayaCode);
      }
    });

    test('every wilaya has names and coordinates inside Algeria', () {
      for (final w in DzGeo.wilayas()) {
        expect(w.nameFr, isNotEmpty);
        expect(w.nameAr, isNotEmpty);
        expect(w.nameEn, isNotEmpty);
        expect(w.latitude, inInclusiveRange(18.9, 37.2), reason: w.nameFr);
        expect(w.longitude, inInclusiveRange(-8.7, 12.0), reason: w.nameFr);
        expect(DzGeo.communesOf(w.code), isNotEmpty, reason: w.nameFr);
      }
    });
  });

  group('lookups', () {
    test('wilaya by code', () {
      final setif = DzGeo.wilaya(19)!;
      expect(setif.nameFr, 'Sétif');
      expect(setif.nameAr, 'سطيف');
      expect(setif.nameEn, 'Sétif');
      expect(setif.codeString, '19');
      expect(setif.motherCode, isNull);

      final alger = DzGeo.wilaya(16)!;
      expect(alger.nameFr, 'Alger');
      expect(alger.nameEn, 'Algiers');
      expect(alger.nameAr, 'الجزائر');

      expect(DzGeo.wilaya(0), isNull);
      expect(DzGeo.wilaya(70), isNull);
    });

    test('wilaya by string code', () {
      expect(DzGeo.wilayaByCode('05')!.nameFr, 'Batna');
      expect(DzGeo.wilayaByCode('5')!.nameFr, 'Batna');
      expect(DzGeo.wilayaByCode('DZ-05')!.nameFr, 'Batna');
      expect(DzGeo.wilayaByCode('x'), isNull);
      expect(DzGeo.wilayaByCode('99'), isNull);
    });

    test('new wilayas carry the names of decree 26-206 and their mother', () {
      final expected = {
        59: ('Aflou', 'أفلو', 3),
        60: ('Barika', 'بريكة', 5),
        61: ('El Kantara', 'القنطرة', 7),
        62: ('Bir El Ater', 'بئر العاتر', 12),
        63: ('El Aricha', 'العريشة', 13),
        64: ('Ksar Chellala', 'قصر الشلالة', 14),
        65: ('Aïn Ouessara', 'عين وسارة', 17),
        66: ('Messaad', 'مسعد', 17),
        67: ('Ksar El Boukhari', 'قصر البخاري', 26),
        68: ('Bou Saâda', 'بوسعادة', 28),
        69: ('El Abiodh Sidi Cheikh', 'الأبيض سيدي الشيخ', 32),
      };
      expected.forEach((code, v) {
        final w = DzGeo.wilaya(code)!;
        expect(w.nameFr, v.$1);
        expect(w.nameAr, v.$2);
        expect(w.motherCode, v.$3);
      });
    });

    test('commune counts follow law 26-06', () {
      final counts = {
        3: 12, 5: 53, 7: 22, 12: 24, 13: 49, 14: 36, 17: 18, 26: 43, 28: 24, //
        32: 15, 59: 12, 60: 8, 61: 5, 62: 4, 63: 4, 64: 6, 65: 10, 66: 8,
        67: 21, 68: 23, 69: 7,
      };
      counts.forEach((code, n) {
        expect(DzGeo.communesOf(code).length, n, reason: 'wilaya $code');
      });
    });

    test('communes of a mother wilaya under the 2019 division', () {
      expect(DzGeo.communesOf(3, division: DzDivision.law2019).length, 24);
      expect(DzGeo.communesOf(17, division: DzDivision.law2019).length, 36);
      expect(DzGeo.communesOf(59, division: DzDivision.law2019), isEmpty);
    });

    test('communes carry their daïra when known', () {
      final barika =
          DzGeo.communesOf(60).firstWhere((c) => c.nameFr == 'Barika');
      expect(barika.wilayaCode2019, 5);
      expect(barika.dairaFr, 'Barika');
      expect(barika.dairaAr, 'بريكة');
      final withDaira = DzGeo.communes.where((c) => c.dairaFr != null).length;
      expect(withDaira, greaterThan(1500));
    });

    test('commune by Wikidata id', () {
      final c = DzGeo.commune(DzGeo.communes.first.wikidataId);
      expect(c, same(DzGeo.communes.first));
      expect(DzGeo.commune('Q0'), isNull);
    });

    test('wilaya communes getter', () {
      expect(DzGeo.wilaya(63)!.communes.map((c) => c.wilayaCode).toSet(), {63});
    });
  });

  group('search', () {
    test('ignores accents and case in Latin and Arabic', () {
      for (final q in ['setif', 'Sétif', 'SETIF', 'سطيف', 'سَطِيف', 'Setif ']) {
        expect(DzGeo.searchWilayas(q).first.code, 19, reason: q);
      }
    });

    test('matches apostrophes, hyphens and English names', () {
      expect(DzGeo.searchWilayas('msila').first.code, 28);
      expect(DzGeo.searchWilayas("M'Sila").first.code, 28);
      expect(DzGeo.searchWilayas('algiers').first.code, 16);
      expect(DzGeo.searchWilayas('bordj bou arreridj').first.code, 34);
    });

    test('matches by code', () {
      expect(DzGeo.searchWilayas('19').first.code, 19);
      expect(DzGeo.searchWilayas('05').first.code, 5);
    });

    test('ranks exact before prefix before substring', () {
      final r = DzGeo.searchWilayas('el');
      expect(r, isNotEmpty);
      final oran = DzGeo.searchWilayas('oran');
      expect(oran.first.code, 31);
    });

    test('empty query returns nothing', () {
      expect(DzGeo.searchWilayas(''), isEmpty);
      expect(DzGeo.searchWilayas('  '), isEmpty);
      expect(DzGeo.searchCommunes(''), isEmpty);
    });

    test('finds communes and can restrict to a wilaya', () {
      final r = DzGeo.searchCommunes('bou saada');
      expect(r.first.wilayaCode, 68);
      expect(DzGeo.searchCommunes('بوسعادة').first.wilayaCode, 68);
      final inBatna = DzGeo.searchCommunes('menaa', wilayaCode: 5);
      expect(inBatna, isNotEmpty);
      expect(inBatna.every((c) => c.wilayaCode == 5), isTrue);
      final inBatna2019 = DzGeo.searchCommunes('barika',
          wilayaCode: 5, division: DzDivision.law2019);
      expect(inBatna2019.first.nameFr, 'Barika');
      expect(DzGeo.searchCommunes('barika', wilayaCode: 5), isEmpty);
    });
  });
}
