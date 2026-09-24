import 'package:dz_kit/dz_kit.dart';
import 'package:test/test.dart';

void main() {
  group('DzPhone.normalize', () {
    test('accepts the usual ways of writing a mobile number', () {
      for (final s in [
        '0555123456',
        '0555 12 34 56',
        '0555-12-34-56',
        '0555.12.34.56',
        '00213555123456',
        '00 213 555 12 34 56',
        '+213555123456',
        '+213 5 55 12 34 56',
        '+213 (0) 555 12 34 56',
        '+2130555123456',
        '213555123456',
        '555123456',
        '٠٥٥٥١٢٣٤٥٦',
        ' +213-555-123-456 ',
      ]) {
        expect(DzPhone.normalize(s), '+213555123456', reason: s);
      }
    });

    test('accepts landlines', () {
      expect(DzPhone.normalize('021 23 45 67'), '+21321234567');
      expect(DzPhone.normalize('+213 21 23 45 67'), '+21321234567');
      expect(DzPhone.normalize('036 12 34 56'), '+21336123456');
    });

    test('accepts VoIP and VSAT numbers', () {
      expect(DzPhone.normalize('0982 12 34 56'), '+213982123456');
      expect(DzPhone.normalize('0961 12 34 56'), '+213961123456');
    });

    test('returns null for anything else', () {
      for (final s in [
        '',
        'abc',
        '0555 12 34 5',
        '0555 12 34 567',
        '0155123456',
        '015 12 34 56',
        '+33612345678',
        '0033612345678',
        '12345',
        '0555-12-34-5a',
        '+213',
        '++213555123456',
        '0555+123456',
        '21234567',
      ]) {
        expect(DzPhone.normalize(s), isNull, reason: s);
      }
    });
  });

  group('DzPhoneNumber', () {
    test('detects the mobile operator from the prefix', () {
      expect(DzPhoneNumber.tryParse('0661 23 45 67')!.operator,
          DzOperator.mobilis);
      expect(
          DzPhoneNumber.tryParse('0770 23 45 67')!.operator, DzOperator.djezzy);
      expect(DzPhoneNumber.tryParse('0550 23 45 67')!.operator,
          DzOperator.ooredoo);
      expect(DzPhoneNumber.tryParse('021 23 45 67')!.operator,
          DzOperator.algerieTelecom);
      expect(DzPhoneNumber.tryParse('0982 12 34 56')!.operator, isNull);
    });

    test('reports the number type', () {
      expect(DzPhoneNumber.tryParse('0661234567')!.type, DzNumberType.mobile);
      expect(DzPhoneNumber.tryParse('021234567')!.type, DzNumberType.landline);
      expect(DzPhoneNumber.tryParse('0982123456')!.type, DzNumberType.voip);
      expect(DzPhoneNumber.tryParse('0961123456')!.type, DzNumberType.vsat);
      expect(DzPhoneNumber.tryParse('0800123456')!.type,
          DzNumberType.specialService);
    });

    test('checks the ARPCE block allocation', () {
      // Allocated blocks.
      for (final s in [
        '0540123456', '0549123456', '0551234567', '0562123456', //
        '0655123456', '0661234567', '0676123456', '0699123456',
        '0771234567', '0784123456', '0791234567',
        '021234567', '038123456', '049123456',
        '0961123456', '0982123456', '0800112345', '0801112345',
      ]) {
        expect(DzPhoneNumber.tryParse(s)!.isAllocated, isTrue, reason: s);
      }
      // Well-formed but not allocated.
      for (final s in [
        '0543123456',
        '0563123456',
        '0651123456',
        '0677123456',
        '0681234567',
        '0695123456',
        '0785123456',
        '0761234567',
        '0962123456',
        '0981123456',
        '0807123456',
        '0800012345',
      ]) {
        expect(DzPhoneNumber.tryParse(s)!.isAllocated, isFalse, reason: s);
      }
    });

    test('formats national and international', () {
      final m = DzPhoneNumber.tryParse('+213555123456')!;
      expect(m.e164, '+213555123456');
      expect(m.nsn, '555123456');
      expect(m.national, '0555123456');
      expect(m.formatNational(), '0555 12 34 56');
      expect(m.formatInternational(), '+213 555 12 34 56');
      final l = DzPhoneNumber.tryParse('021234567')!;
      expect(l.formatNational(), '021 23 45 67');
      expect(l.formatInternational(), '+213 21 23 45 67');
      expect(m.toString(), '+213555123456');
    });

    test('value equality on the national significant number', () {
      expect(DzPhoneNumber.tryParse('0555123456'),
          DzPhoneNumber.tryParse('+213 555 12 34 56'));
      expect(DzPhoneNumber.tryParse('0555123456').hashCode,
          DzPhoneNumber.tryParse('+213 555 12 34 56').hashCode);
    });
  });

  group('DzPhone.isValid', () {
    test('needs a well-formed number in an allocated block', () {
      expect(DzPhone.isValid('0555 12 34 56'), isTrue);
      expect(DzPhone.isValid('+213 21 23 45 67'), isTrue);
      expect(DzPhone.isValid('0681234567'), isFalse);
      expect(DzPhone.isValid('0555'), isFalse);
      expect(DzPhone.isValid('hello'), isFalse);
    });
  });

  group('DzPhone.same', () {
    test('matches the same number written differently', () {
      expect(DzPhone.same('0555123456', '+213 555 12 34 56'), isTrue);
      expect(DzPhone.same('00213 21 23 45 67', '021234567'), isTrue);
    });

    test('compares the full national number, not the last 7 digits', () {
      // Same last seven digits (5123456), different operators.
      expect(DzPhone.same('0555123456', '0655123456'), isFalse);
      expect(DzPhone.same('0555123456', '0755123456'), isFalse);
      // A landline and a mobile ending the same way.
      expect(DzPhone.same('021234567', '0661234567'), isFalse);
    });

    test('never matches invalid input', () {
      expect(DzPhone.same('', ''), isFalse);
      expect(DzPhone.same('abc', 'abc'), isFalse);
    });
  });
}
