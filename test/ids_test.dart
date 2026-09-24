import 'package:dz_kit/dz_kit.dart';
import 'package:test/test.dart';

void main() {
  // Published examples used below:
  // - Algérie Poste "COVID-19-Algérie" solidarity account (2020):
  //   CCP 200 clé 12, RIP 007 99999 0000000200 91.
  // - Worked CCP-key example on developpez.net: 1012344597 -> clé 34.
  // - RIP quoted by an account holder on excel-downloads.com (2021):
  //   00799999002311500797, whose key is 97 (naive code prints 00).

  group('CcpAccount.computeKey', () {
    test('matches the Algérie Poste solidarity account', () {
      expect(CcpAccount.computeKey('200'), '12');
      expect(CcpAccount.computeKey('0000000200'), '12');
    });

    test('matches the worked example', () {
      expect(CcpAccount.computeKey('1012344597'), '34');
    });

    test('pads keys below 10 with a zero', () {
      // 1 * 4 = 4
      expect(CcpAccount.computeKey('1'), '04');
    });

    test('rejects non-digits, empty and over-long numbers', () {
      expect(() => CcpAccount.computeKey(''), throwsFormatException);
      expect(() => CcpAccount.computeKey('12a'), throwsFormatException);
      expect(() => CcpAccount.computeKey('12345678901'), throwsFormatException);
    });
  });

  group('CcpAccount.tryParse', () {
    test('accepts common separators between number and key', () {
      for (final s in [
        '200 12',
        '200/12',
        '200-12',
        '0000000200 12',
        '200 clé 12',
        '200 cle 12',
        ' 200  /  12 ',
      ]) {
        final a = CcpAccount.tryParse(s);
        expect(a, isNotNull, reason: s);
        expect(a!.number, '200', reason: s);
        expect(a.key, '12', reason: s);
      }
    });

    test('returns null when the key does not match', () {
      expect(CcpAccount.tryParse('200 13'), isNull);
      expect(CcpAccount.tryParse('1012344597 43'), isNull);
    });

    test('returns null for malformed input', () {
      for (final s in [
        '',
        '200',
        '200 1',
        '200 123',
        'abc 12',
        '12345678901 12'
      ]) {
        expect(CcpAccount.tryParse(s), isNull, reason: s);
      }
    });

    test('fromNumber computes the key', () {
      final a = CcpAccount.fromNumber('0000000200');
      expect(a.number, '200');
      expect(a.key, '12');
      expect(a.paddedNumber, '0000000200');
      expect(a.toString(), '200 12');
    });

    test('value equality', () {
      expect(CcpAccount.fromNumber('200'), CcpAccount.tryParse('200/12'));
      expect(CcpAccount.fromNumber('200').hashCode,
          CcpAccount.tryParse('200/12').hashCode);
    });
  });

  group('Rip', () {
    test('computes the RIP of the solidarity account', () {
      expect(Rip.computeKey('200'), '91');
      expect(Rip.fromCcp('200'), '00799999000000020091');
      expect(CcpAccount.fromNumber('200').rip, '00799999000000020091');
    });

    test('handles the key 97 edge case', () {
      expect(Rip.computeKey('23115007'), '97');
      expect(Rip.isValid('00799999002311500797'), isTrue);
    });

    test('validates with or without spaces', () {
      expect(Rip.isValid('007 99999 0000000200 91'), isTrue);
      expect(Rip.isValid('00799999000000020091'), isTrue);
      expect(Rip.isValid('00799999-0000000200-91'), isTrue);
    });

    test('rejects a wrong key, wrong prefix or wrong length', () {
      expect(Rip.isValid('00799999000000020090'), isFalse);
      expect(Rip.isValid('00799999002311500700'), isFalse);
      expect(Rip.isValid('00899999000000020091'), isFalse);
      expect(Rip.isValid('0079999900000002009'), isFalse);
      expect(Rip.isValid(''), isFalse);
      expect(Rip.isValid('0079999900000002009a'), isFalse);
    });

    test('extracts the CCP account from a RIP', () {
      final a = Rip.toCcp('007 99999 0000000200 91');
      expect(a, isNotNull);
      expect(a!.number, '200');
      expect(a.key, '12');
      expect(Rip.toCcp('00799999000000020090'), isNull);
    });

    test('formats in the printed grouping', () {
      expect(Rip.format('00799999000000020091'), '007 99999 0000000200 91');
      expect(Rip.format('bad'), isNull);
    });

    test('agrees with an independent implementation of the published formula',
        () {
      // 97 - ((ccp mod 97) * 3 + 85) mod 97, from the WinDev routine linked
      // on developpez.net; 3 = 100 mod 97 and 85 = 99999 * 10^12 mod 97.
      String reference(int ccp) {
        final k = 97 - (((ccp % 97) * 3 + 85) % 97);
        return k.toString().padLeft(2, '0');
      }

      for (final n in [
        1,
        7,
        200,
        23115007,
        1012344597,
        1234567890,
        9999999999
      ]) {
        expect(Rip.computeKey('$n'), reference(n), reason: '$n');
      }
    });
  });

  // NIF and NIS have no published check digit, so only the format is
  // checked. The numbers below are synthetic.
  group('Nif', () {
    test('accepts 15 digits, spaces allowed', () {
      expect(Nif.isValid('000942040001075'), isTrue);
      expect(Nif.isValid('0 009 42 0400010 75'), isTrue);
    });

    test('accepts 20 digits for a secondary establishment', () {
      expect(Nif.isValid('00094204000107500001'), isTrue);
      expect(Nif.isValid('00094204000107500001', allowEstablishment: false),
          isFalse);
    });

    test('rejects other lengths and non-digits', () {
      expect(Nif.isValid('00094204000107'), isFalse);
      expect(Nif.isValid('0009420400010755'), isFalse);
      expect(Nif.isValid('00094204000107A'), isFalse);
      expect(Nif.isValid(''), isFalse);
    });

    test('normalize strips separators', () {
      expect(Nif.normalize('0 009-42.0400010 75'), '000942040001075');
      expect(Nif.normalize('12'), isNull);
    });
  });

  group('Nis', () {
    test('accepts 15 digits and 18 for a secondary establishment', () {
      expect(Nis.isValid('098416010002360'), isTrue);
      expect(Nis.isValid('098 4160 10002 360'), isTrue);
      expect(Nis.isValid('098416010002360001'), isTrue);
      expect(Nis.isValid('098416010002360001', allowEstablishment: false),
          isFalse);
    });

    test('rejects other lengths and non-digits', () {
      expect(Nis.isValid('09841601000236'), isFalse);
      expect(Nis.isValid('0984160100023600'), isFalse);
      expect(Nis.isValid('09841601000236X'), isFalse);
    });
  });
}
