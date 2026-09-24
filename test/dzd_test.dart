import 'package:dz_kit/dz_kit.dart';
import 'package:test/test.dart';

const nnbsp = '\u202F';
const nbsp = '\u00A0';

void main() {
  group('Dzd construction', () {
    test('stores integer centimes', () {
      expect(const Dzd(12345).centimes, 12345);
      expect(const Dzd(12345).dinars, 123);
      expect(const Dzd(12345).centimesPart, 45);
      expect(const Dzd(-12345).dinars, -123);
      expect(const Dzd(-12345).centimesPart, 45);
    });

    test('fromDinars rounds half away from zero on the decimal value', () {
      expect(Dzd.fromDinars(0.995).centimes, 100);
      expect(Dzd.fromDinars(1.005).centimes, 101);
      expect(Dzd.fromDinars(2.675).centimes, 268);
      expect(Dzd.fromDinars(-0.995).centimes, -100);
      expect(Dzd.fromDinars(0.994).centimes, 99);
      expect(Dzd.fromDinars(1234).centimes, 123400);
      expect(Dzd.fromDinars(0.1 + 0.2).centimes, 30);
      expect(Dzd.fromDinars(1e-7).centimes, 0);
      expect(Dzd.fromDinars(1.5e10).centimes, 1500000000000);
    });

    test('fromDinars rejects NaN and infinity', () {
      expect(() => Dzd.fromDinars(double.nan), throwsArgumentError);
      expect(() => Dzd.fromDinars(double.infinity), throwsArgumentError);
    });

    test('arithmetic stays in integer centimes', () {
      expect(const Dzd(150) + const Dzd(275), const Dzd(425));
      expect(const Dzd(150) - const Dzd(275), const Dzd(-125));
      expect(-const Dzd(150), const Dzd(-150));
      expect(const Dzd(333) * 3, const Dzd(999));
      expect(const Dzd(100).compareTo(const Dzd(99)), greaterThan(0));
      expect(const Dzd(0).isZero, isTrue);
      expect(const Dzd(-1).isNegative, isTrue);
    });
  });

  group('Dzd.format', () {
    test('French style groups with a narrow no-break space', () {
      expect(
          const Dzd(123456789).format(), '1${nnbsp}234${nnbsp}567,89${nbsp}DA');
      expect(const Dzd(100).format(), '1,00${nbsp}DA');
      expect(const Dzd(5).format(), '0,05${nbsp}DA');
      expect(const Dzd(0).format(), '0,00${nbsp}DA');
      expect(const Dzd(99999).format(), '999,99${nbsp}DA');
      expect(const Dzd(100000).format(), '1${nnbsp}000,00${nbsp}DA');
    });

    test('never uses an ASCII space between digit groups', () {
      final s = const Dzd(1234567).format(symbol: false);
      expect(s.contains(' '), isFalse);
      expect(s, '12${nnbsp}345,67');
    });

    test('Arabic style uses the دج suffix', () {
      expect(const Dzd(123456).format(style: DzdStyle.ar),
          '1${nnbsp}234,56$nbspدج');
    });

    test('negative amounts', () {
      expect(const Dzd(-123456).format(), '-1${nnbsp}234,56${nbsp}DA');
      // In Arabic style the signed number is isolated left-to-right so the
      // minus sign stays on the left of the digits inside RTL text.
      expect(
        const Dzd(-123456).format(style: DzdStyle.ar),
        '\u2066-1${nnbsp}234,56\u2069$nbspدج',
      );
    });

    test('can omit zero centimes', () {
      expect(const Dzd(150000).format(omitZeroCentimes: true),
          '1${nnbsp}500${nbsp}DA');
      expect(const Dzd(150050).format(omitZeroCentimes: true),
          '1${nnbsp}500,50${nbsp}DA');
    });

    test('0.995 renders as 1,00 (regression)', () {
      expect(Dzd.fromDinars(0.995).format(symbol: false), '1,00');
    });

    test('toString is the French format', () {
      expect(const Dzd(250).toString(), '2,50${nbsp}DA');
    });
  });

  group('Dzd.tryParse', () {
    test('plain numbers', () {
      expect(Dzd.tryParse('1234'), const Dzd(123400));
      expect(Dzd.tryParse('0'), const Dzd(0));
      expect(Dzd.tryParse('-12'), const Dzd(-1200));
      expect(Dzd.tryParse('+12'), const Dzd(1200));
    });

    test('decimal comma or point, up to two decimals', () {
      expect(Dzd.tryParse('1234,5'), const Dzd(123450));
      expect(Dzd.tryParse('1234.56'), const Dzd(123456));
      expect(Dzd.tryParse('0,05'), const Dzd(5));
      expect(Dzd.tryParse(',5'), const Dzd(50));
    });

    test('grouped thousands', () {
      expect(Dzd.tryParse('1 234,56'), const Dzd(123456));
      expect(Dzd.tryParse('1${nnbsp}234${nnbsp}567,89'), const Dzd(123456789));
      expect(Dzd.tryParse('1${nbsp}234'), const Dzd(123400));
      expect(Dzd.tryParse('1.234.567,89'), const Dzd(123456789));
      expect(Dzd.tryParse('1,234,567.89'), const Dzd(123456789));
      expect(Dzd.tryParse('1.234.567'), const Dzd(123456700));
    });

    test('currency markers', () {
      expect(Dzd.tryParse('1 500 DA'), const Dzd(150000));
      expect(Dzd.tryParse('1500DZD'), const Dzd(150000));
      expect(Dzd.tryParse('1500 دج'), const Dzd(150000));
      expect(Dzd.tryParse('1500 د.ج'), const Dzd(150000));
      expect(Dzd.tryParse('  12,50  '), const Dzd(1250));
    });

    test('Arabic-Indic digits and separators', () {
      expect(Dzd.tryParse('١٢٣٤\u066B٥٦'), const Dzd(123456));
      expect(Dzd.tryParse('١\u066C٢٣٤'), const Dzd(123400));
    });

    test('round-trips format()', () {
      for (final c in [0, 5, 100, 99999, 123456789, -123456]) {
        expect(Dzd.tryParse(Dzd(c).format()), Dzd(c), reason: '$c');
        expect(Dzd.tryParse(Dzd(c).format(style: DzdStyle.ar)), Dzd(c),
            reason: '$c');
      }
    });

    test('returns null for invalid input', () {
      for (final s in [
        '',
        '   ',
        'abc',
        '12a',
        '1,234,5',
        '12.345',
        '1,999',
        '1.2.3',
        '1 23',
        '12,345,67',
        '1.234,567',
        '--5',
        '5-',
        '1,2.3',
        'DA',
        '12 34 56',
        '99999999999999999',
      ]) {
        expect(Dzd.tryParse(s), isNull, reason: s);
      }
    });
  });
}
