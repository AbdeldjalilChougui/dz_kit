import 'package:dz_kit/dz_kit.dart';

void main() {
  // Administrative geography (69 wilayas, law 26-06).
  final setif = DzGeo.searchWilayas('setif').first;
  print(
      '${setif.codeString} ${setif.nameFr} / ${setif.nameAr}'); // 19 Sétif / سطيف
  print(DzGeo.wilaya(59)); // Wilaya(59 Aflou)
  print(DzGeo.communesOf(63).map((c) => c.nameFr).join(', '));
  // Systems still on the 58 codes:
  print(DzGeo.communesOf(3, division: DzDivision.law2019).length); // 24

  // Phone numbers.
  print(DzPhone.normalize('0555 12 34 56')); // +213555123456
  print(DzPhone.operatorOf('+213 661 23 45 67')); // DzOperator.mobilis
  print(DzPhone.same('0555123456', '00213 555 12 34 56')); // true
  print(DzPhone.same('0555123456', '0655123456')); // false

  // DZD money in integer centimes.
  final price = Dzd.fromDinars(0.995);
  print(price.format()); // 1,00 DA
  print(Dzd.tryParse('1 234,56 DA')!.format(style: DzdStyle.ar)); // 1 234,56 دج
  print(Dzd.tryParse('12.345')); // null (ambiguous)

  // CCP and RIP.
  final ccp = CcpAccount.fromNumber('200');
  print(ccp); // 200 12
  print(Rip.format(ccp.rip)); // 007 99999 0000000200 91
  print(Rip.isValid('00799999002311500797')); // true

  // NIF and NIS: format only.
  print(Nif.isValid('000942040001075')); // true
  print(Nis.isValid('098416010002360')); // true
}
