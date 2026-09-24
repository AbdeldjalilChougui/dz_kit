# dz_kit

Building blocks for Algerian apps, in pure Dart. It covers the 69 wilayas and 1541 communes, +213 phone numbers, DZD amounts kept in integer centimes, CCP and RIP keys, and NIF and NIS checks.

[![pub package](https://img.shields.io/pub/v/dz_kit.svg)](https://pub.dev/packages/dz_kit)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- **Administrative geography**
  - All 69 wilayas under law 26-06 of 4 April 2026. Each one has its code, Arabic, French and English names, and the coordinates of its chef-lieu.
  - All 1541 communes, with Arabic and French names, the wilaya they belong to (under both the 2026 and the 2019 division), the daïra where the source has it, coordinates, and the Wikidata id.
  - Lookups by code (`19`, `"05"`, `"DZ-05"`), a list of the communes in each wilaya, and a search that ignores accents and case in Latin and Arabic: `setif`, `Sétif` and `سطيف` all find wilaya 19.
  - A versioned dataset (`DzGeo.dataVersion`) that can also answer for the older 58-wilaya division (`DzDivision.law2019`).
- **Phone numbers**
  - Converts any Algerian number to E.164 (`+213...`). It accepts `0555...`, `00213...`, `+213 5 55 ...`, `+213 (0)...`, spaces, dashes, dots and Arabic-Indic digits.
  - Detects the operator from the prefix: Mobilis 06, Djezzy 07, Ooredoo 05, and Algérie Télécom for landlines.
  - Checks the number against the ARPCE block allocation.
  - `DzPhone.same` compares the **full** national significant number, not the last 7 digits.
- **DZD money**
  - `Dzd` stores integer centimes, so no doubles are involved.
  - Formats in French (`1 234,56 DA`) or Arabic (`1 234,56 دج`) style. Digit groups are separated by U+202F and the currency symbol by U+00A0, so right-to-left text does not reorder the groups.
  - Rounds half away from zero on the decimal value: `Dzd.fromDinars(0.995)` gives `1,00`.
  - `Dzd.tryParse` returns `null` on invalid or ambiguous input.
- **Banking and tax identifiers**
  - CCP account key (clé), and RIP (relevé d'identité postale) key computation and validation. Both algorithms are checked against published Algérie Poste numbers.
  - NIF (15 or 20 digits) and NIS (15 or 18 digits) format checks.

## Install

```sh
dart pub add dz_kit
```

## Usage

```dart
import 'package:dz_kit/dz_kit.dart';

void main() {
  // Administrative geography (69 wilayas, law 26-06).
  final setif = DzGeo.searchWilayas('setif').first;
  print('${setif.codeString} ${setif.nameFr} / ${setif.nameAr}'); // 19 Sétif / سطيف
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
```

### 58 or 69 wilayas?

Algeria had 58 wilayas from 2019. Law 26-06 of 4 April 2026 (Journal officiel n° 25, 5 April 2026) created 11 more, numbered 59 to 69, which brings the total to **69 wilayas** and 1541 communes. Presidential decree 26-206 of 25 May 2026 (Journal officiel n° 40) set their names and seats. This package treats that division as current.

The law also gives the mother wilayas until **31 December 2026** to hand over their powers to the new ones. Until then, and in systems nobody has updated, you will still meet the 58 codes. To handle both:

- `DzGeo.dataVersion` (`'2026.1'`) identifies the bundled dataset, and `DzGeo.currentDivision` says which division it treats as current.
- Every commune has both `wilayaCode` (2026) and `wilayaCode2019`.
- Every wilaya from 59 to 69 has a `motherCode`.
- `DzGeo.wilayas`, `DzGeo.communesOf`, `DzGeo.searchWilayas` and `DzGeo.searchCommunes` take a `division:` argument. Pass `DzDivision.law2019` to get the 58-wilaya view.

### CCP and RIP algorithms

- **CCP key**: weight the account digits 4, 5, 6 … 13 from the rightmost digit, sum them, and take the result modulo 100. For example, CCP 200 gives 2 × 6 = 12.
- **RIP**: `007` (Algérie Poste) + `99999` (agency) + the account number padded to 10 digits + a 2-digit key. The key is `97 − ((N × 100) mod 97)`, where N is `99999` followed by the 10-digit account number, so it runs from 01 to 97.

Sources that agree on these algorithms:

- The open-source library [mouh2020/algeria](https://github.com/mouh2020/algeria/blob/main/algeria/ccp.py).
- A WinDev routine [posted on developpez.net](https://www.developpez.net/forums/d2167977/environnements-developpement/windev/calcul-rip-ccp/) ([code](https://pastebin.com/vaXrGCaS)).
- The CCP-key worked example in [this developpez.net thread](https://www.developpez.net/forums/d1678040/dotnet/general-dotnet/debuter/calcule-cle-ccp/): 1012344597 has key 34.

The tests use these published real numbers:

- Algérie Poste's "COVID-19-Algérie" solidarity account: CCP 200, key 12, RIP `007 99999 0000000200 91`. It was published by Algérie Poste and reported by [Algerie360](https://www.algerie360.com/coronavirus-en-algerie-ouverture-dun-compte-courant-postal-de-solidarite-pour-les-dons/).
- An account holder's RIP quoted on [excel-downloads.com](https://www.excel-downloads.com/threads/calcul-cl%C3%A9-ccp-rip-rib-banques-algeriennes.182912/): `00799999002311500797`. Its key is 97, where code that wraps the key to 0..96 prints 00.

## Limitations

- **NIF and NIS are checked for format only.** I found no published checksum algorithm for either, so a well-formed number that was never issued still passes:
  - NIF: 15 digits, or 20 for a secondary establishment.
  - NIS: 15 digits, or 18 for a secondary establishment, per executive decree 97-396, articles 4 and 5.
- **The operator is the one the number block was allocated to.** Algeria has a legal framework for mobile number portability (decree 21-199), so a subscriber may have switched operators. The allocation table follows the [ARPCE numbering plan page](https://www.arpce.dz/fr/service/num) as of September 2026. A block that ARPCE allocates later will parse, but `isAllocated` and `DzPhone.isValid` will return false for it until the table is updated.
- **Landline area codes are not mapped to wilayas.**
- **Some commune data is missing or approximate.**
  - 10 communes have no usable daïra: Wikidata either has no daïra for them or links them to a daïra in another wilaya. Nine of them have both `dairaFr` and `dairaAr` null. The tenth has only an Arabic daïra name.
  - Commune names follow Wikidata's labels, which sometimes differ from the Journal officiel spelling (for example `Aïn Oussara` and `Aïn Ouessara`). The wilaya names for 59 to 69 use the decree's spelling.
  - A wilaya's coordinates are those of its chef-lieu commune. For Algiers, the commune used is Alger-Centre.
- **English names**: communes have no English name. Wilayas take their English name from Wikidata. El Aricha has no Wikidata item yet, so its English name is the French one.

## Data sources

| Data | Source | License |
|---|---|---|
| Wilaya and commune names, daïras, coordinates, Wikidata ids | [Wikidata](https://www.wikidata.org), queried by SPARQL on 2026-09-24 | CC0 1.0 |
| Which communes belong to the 11 new wilayas, and to their mothers | Loi n° 26-06 du 4 avril 2026, [JORADP 2026 n° 25](https://www.joradp.dz/FTP/JO-FRANCAIS/2026/F2026025.pdf), pp. 4–9 | Official text |
| Numbers, names and seats of wilayas 59–69 (French and Arabic) | Décret présidentiel n° 26-206 du 25 mai 2026, JORADP 2026 n° 40 ([fr](https://www.joradp.dz/FTP/JO-FRANCAIS/2026/F2026040.pdf), [ar](https://www.joradp.dz/FTP/JO-ARABE/2026/A2026040.pdf)) | Official text |
| Commune lists for the 2019 wilayas and El Borma's move | Loi n° 19-12 ([JORADP 2019 n° 78](https://www.joradp.dz/FTP/JO-FRANCAIS/2019/F2019078.pdf)) and ordonnance n° 21-03 ([JORADP 2021 n° 22](https://www.joradp.dz/FTP/JO-FRANCAIS/2021/F2021022.pdf)) | Official text |
| Mobile, VoIP, VSAT and service number blocks | [ARPCE, Plan national de numérotation](https://www.arpce.dz/fr/service/num) | Facts |

The script [`tool/generate_data.dart`](tool/generate_data.dart) generates the Dart files in `lib/src/geo/data/`. It works in these steps:

1. It queries Wikidata, or with no `--refresh` flag reuses the committed snapshot in `tool/cache/`.
2. It applies the corrections in [`tool/sources/wikidata_fixes.json`](tool/sources/wikidata_fixes.json), each with a written reason:
   - It removes villages, ancient sites and duplicates that Wikidata types as communes.
   - It adds the communes of Adrar, Médéa and Boumerdès, which Wikidata models only as city items.
   - It fixes wrong parent links, such as El Borma and Hassi Fehal.
   - It fixes wrong labels, such as Sidi Brahim, which Wikidata labels "gambetta".
3. It moves communes to the new wilayas using the law 26-06 lists in [`tool/sources/law_26_06.json`](tool/sources/law_26_06.json), transcribed from the Journal officiel.
4. It checks every wilaya's commune count against [`tool/sources/expected_counts.json`](tool/sources/expected_counts.json), 1541 in total. If any count differs, it writes nothing.

```sh
dart run tool/generate_data.dart --refresh
```

## License

MIT. See [LICENSE](LICENSE). The generated data derives from Wikidata (CC0) and Algerian official texts.

Made by [Abdeldjalil Chougui](https://abdeldjalilchougui.biz/).
