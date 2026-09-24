import 'package:dz_kit/dz_kit.dart';
import 'package:test/test.dart';

void main() {
  group('foldForSearch', () {
    test('drops Latin accents and case', () {
      expect(foldForSearch('Sétif'), 'setif');
      expect(foldForSearch('BÉJAÏA'), 'bejaia');
      expect(foldForSearch('Aïn Témouchent'), 'aintemouchent');
      expect(foldForSearch('Bou Saâda'), 'bousaada');
      expect(foldForSearch('Œuvre Ça'), 'oeuvreca');
    });

    test('drops spaces, apostrophes and hyphens', () {
      expect(foldForSearch("M'Sila"), 'msila');
      expect(foldForSearch('M’Sila'), 'msila');
      expect(foldForSearch('Bordj Bou-Arréridj'), 'bordjbouarreridj');
    });

    test('removes Arabic diacritics and tatweel', () {
      expect(foldForSearch('سَطِيف'), 'سطيف');
      expect(foldForSearch('سـطـيـف'), 'سطيف');
    });

    test('unifies Arabic letter variants', () {
      expect(foldForSearch('أدرار'), foldForSearch('ادرار'));
      expect(foldForSearch('إليزي'), foldForSearch('اليزي'));
      expect(foldForSearch('آفلو'), foldForSearch('افلو'));
      expect(foldForSearch('بسكرة'), foldForSearch('بسكره'));
      expect(foldForSearch('مصطفى'), foldForSearch('مصطفي'));
    });

    test('maps Arabic-Indic digits to ASCII', () {
      expect(foldForSearch('١٩'), '19');
      expect(foldForSearch('۱۹'), '19');
    });
  });
}
