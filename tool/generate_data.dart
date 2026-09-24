// Generates lib/src/geo/data/*.g.dart from Wikidata (CC0) and the Journal
// officiel texts transcribed in tool/sources/.
//
//   dart run tool/generate_data.dart            # use tool/cache/ snapshot
//   dart run tool/generate_data.dart --refresh  # re-query Wikidata first
//
// Pipeline:
//   1. Wikidata SPARQL: wilayas (P31 Q240601), communes (P31 Q2989398),
//      daïras (P31 Q2614970) and each commune's P131 parents. The raw result
//      is reduced to the fields used and cached in tool/cache/.
//   2. tool/sources/wikidata_fixes.json removes non-communes and duplicates,
//      adds communes modelled only as city items, fixes parent links and
//      fills missing labels. Each entry records its reason.
//   3. tool/sources/law_26_06.json (loi 26-06 and décret 26-206, Journal
//      officiel 2026 n° 25 and n° 40) moves communes to the 11 new wilayas
//      and names them.
//   4. The result must match tool/sources/expected_counts.json exactly,
//      wilaya by wilaya, or nothing is written.
import 'dart:convert';
import 'dart:io';

const _endpoint = 'https://query.wikidata.org/sparql';
const _userAgent =
    'dz_kit-datagen/0.1 (https://github.com/AbeldjalilChougui/dz_kit)';

final _root = File.fromUri(Platform.script).parent.parent.path;
String _p(String rel) => '$_root/$rel';

Future<void> main(List<String> args) async {
  final cacheFile = File(_p('tool/cache/wikidata_snapshot.json'));
  Map<String, dynamic> snapshot;
  if (args.contains('--refresh') || !cacheFile.existsSync()) {
    snapshot = await _download();
    cacheFile.writeAsStringSync(
      '${const JsonEncoder.withIndent(' ').convert(snapshot)}\n',
    );
    stdout.writeln('Wrote ${cacheFile.path}');
  } else {
    snapshot = _readJson(cacheFile.path);
  }
  _build(snapshot);
}

// ---------------------------------------------------------------------------
// Download

Future<Map<String, dynamic>> _download() async {
  const labels = 'OPTIONAL{?x rdfs:label ?fr FILTER(lang(?fr)="fr")} '
      'OPTIONAL{?x rdfs:label ?ar FILTER(lang(?ar)="ar")} '
      'OPTIONAL{?x rdfs:label ?en FILTER(lang(?en)="en")} '
      'OPTIONAL{?x wdt:P625 ?coord}';
  final wilayas = await _query(
    'SELECT ?x ?iso ?fr ?ar ?en ?coord WHERE { ?x wdt:P31 wd:Q240601; '
    'wdt:P17 wd:Q262. OPTIONAL{?x wdt:P300 ?iso} $labels }',
  );
  final communes = await _query(
    'SELECT ?x ?fr ?ar ?en ?coord WHERE { ?x wdt:P31 wd:Q2989398. $labels }',
  );
  final parents = await _query(
    'SELECT ?x ?p WHERE { ?x wdt:P31 wd:Q2989398. ?x p:P131 ?st. '
    '?st ps:P131 ?p. FILTER NOT EXISTS { ?st pq:P582 ?end } }',
  );
  final dairas = await _query(
    'SELECT ?x ?fr ?ar ?en ?coord ?w WHERE { ?x wdt:P31 wd:Q2614970. '
    'OPTIONAL{?x wdt:P131 ?w} $labels }',
  );
  final fixes = _readJson(_p('tool/sources/wikidata_fixes.json'));
  final extraIds = (fixes['include'] as Map<String, dynamic>).keys.toList();
  final values = extraIds.map((q) => 'wd:$q').join(' ');
  final extra = await _query(
    'SELECT ?x ?fr ?ar ?en ?coord ?p WHERE { VALUES ?x { $values } '
    'OPTIONAL{?x wdt:P131 ?p} $labels }',
  );

  Map<String, dynamic> items(List<Map<String, String>> rows,
      {String? parentKey}) {
    final out = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final id = _qid(r['x']!);
      final item = out.putIfAbsent(id, () => <String, dynamic>{});
      for (final k in ['fr', 'ar', 'en', 'iso']) {
        if (r[k] != null) item[k] = r[k];
      }
      if (r['coord'] != null) {
        final set = (item['coords'] ??= <String>[]) as List<String>;
        if (!set.contains(r['coord'])) set.add(r['coord']!);
      }
      if (parentKey != null && r[parentKey] != null) {
        final set = (item['parents'] ??= <String>[]) as List<String>;
        final p = _qid(r[parentKey]!);
        if (!set.contains(p)) set.add(p);
      }
    }
    for (final item in out.values) {
      (item['coords'] as List<String>?)?.sort();
      (item['parents'] as List<String>?)?.sort();
    }
    return Map.fromEntries(
        out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  final communeItems = items(communes);
  for (final r in parents) {
    final item = communeItems[_qid(r['x']!)];
    if (item == null) continue;
    final set = (item['parents'] ??= <String>[]) as List<String>;
    final p = _qid(r['p']!);
    if (!set.contains(p)) set.add(p);
  }
  for (final item in communeItems.values) {
    (item['parents'] as List<String>?)?.sort();
  }

  final now = DateTime.now().toUtc();
  return {
    'source': 'Wikidata (CC0), $_endpoint',
    'retrieved': '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}',
    'wilayas': items(wilayas),
    'communes': communeItems,
    'dairas': items(dairas, parentKey: 'w'),
    'extra': items(extra, parentKey: 'p'),
  };
}

Future<List<Map<String, String>>> _query(String sparql) async {
  final uri = Uri.parse(_endpoint).replace(queryParameters: {'query': sparql});
  final client = HttpClient()..userAgent = _userAgent;
  try {
    for (var attempt = 1;; attempt++) {
      try {
        final req = await client.getUrl(uri);
        req.headers.set('Accept', 'application/sparql-results+json');
        final res = await req.close().timeout(const Duration(seconds: 120));
        final body = await res.transform(utf8.decoder).join();
        if (res.statusCode != 200) {
          throw HttpException('HTTP ${res.statusCode}', uri: uri);
        }
        final json = jsonDecode(body) as Map<String, dynamic>;
        final bindings = (json['results'] as Map<String, dynamic>)['bindings']
            as List<dynamic>;
        return [
          for (final b in bindings.cast<Map<String, dynamic>>())
            {
              for (final e in b.entries)
                e.key: (e.value as Map<String, dynamic>)['value'] as String,
            },
        ];
      } catch (e) {
        if (attempt >= 5) rethrow;
        stderr.writeln('Query failed ($e), retry $attempt');
        await Future<void>.delayed(Duration(seconds: 5 * attempt));
      }
    }
  } finally {
    client.close();
  }
}

String _qid(String uri) => uri.substring(uri.lastIndexOf('/') + 1);

// ---------------------------------------------------------------------------
// Build

class _Commune {
  _Commune(this.id, this.fr, this.ar, this.code2019, this.coord);
  final String id;
  final String fr;
  final String ar;
  final String code2019;
  final (double, double)? coord;
  String? code2026;
  String? dairaFr;
  String? dairaAr;
}

void _build(Map<String, dynamic> snap) {
  final fixes = _readJson(_p('tool/sources/wikidata_fixes.json'));
  final law = _readJson(_p('tool/sources/law_26_06.json'));
  final expected = _readJson(_p('tool/sources/expected_counts.json'));

  final wilayaItems = (snap['wilayas'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();
  final communeItems = (snap['communes'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();
  final dairaItems = (snap['dairas'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();
  final extraItems = (snap['extra'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();

  final exclude = (fixes['exclude'] as Map<String, dynamic>).keys.toSet();
  final include = (fixes['include'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();
  final wilayaFix = (fixes['wilaya'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();
  final labelFix = (fixes['labels'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();
  final aliases =
      (fixes['law_aliases'] as Map<String, dynamic>).cast<String, String>();

  // Wilaya item -> code under the 58 division (ISO 3166-2 DZ-nn).
  final codeOfItem = <String, String>{};
  for (final e in wilayaItems.entries) {
    final iso = e.value['iso'] as String?;
    if (iso != null) codeOfItem[e.key] = iso.substring(3);
  }
  // Items of the new wilayas: their communes still belong to the mother
  // under the 58 division.
  final newWilayas = (law['wilayas'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();
  for (final nw in newWilayas.values) {
    final id = nw['wikidata'] as String?;
    if (id != null) codeOfItem[id] = nw['mother'] as String;
  }

  // Daïra item -> (fr, ar, wilaya code 58).
  String? dairaWilaya(String d) {
    final parents = dairaItems[d]?['parents'] as List<dynamic>?;
    if (parents == null) return null;
    for (final p in parents) {
      final c = codeOfItem[p];
      if (c != null) return c;
    }
    return null;
  }

  final communes = <String, _Commune>{};
  final problems = <String>[];

  void addCommune(String id, Map<String, dynamic> item, String? forcedCode) {
    final parents =
        (item['parents'] as List<dynamic>? ?? const []).cast<String>();
    final dairas = parents.where(dairaItems.containsKey).toList();
    final codes = <String>{
      for (final p in parents)
        if (codeOfItem[p] != null) codeOfItem[p]!,
      for (final d in dairas)
        if (dairaWilaya(d) != null) dairaWilaya(d)!,
    };
    final code = forcedCode ?? (codes.length == 1 ? codes.single : null);
    if (code == null) {
      problems.add('$id ${item['fr']}: wilaya unresolved ($codes)');
      return;
    }
    final label = labelFix[id];
    final fr = _cleanFr((label?['fr'] ?? item['fr'] ?? '') as String);
    final ar = _cleanAr((label?['ar'] ?? item['ar'] ?? '') as String);
    if (fr.isEmpty || ar.isEmpty) {
      problems.add('$id: missing label fr="$fr" ar="$ar"');
      return;
    }
    final coords = (item['coords'] as List<dynamic>?)?.cast<String>();
    final c = _Commune(id, fr, ar, code, _parsePoint(coords?.first));
    // Only keep a daïra link that agrees with the commune's wilaya.
    final daira = dairas.where((d) => dairaWilaya(d) == code).toList();
    if (daira.length == 1) {
      final d = dairaItems[daira.single]!;
      c.dairaFr = _cleanDairaFr((d['fr'] ?? '') as String);
      c.dairaAr = _cleanDairaAr((d['ar'] ?? '') as String);
      if (c.dairaFr!.isEmpty) c.dairaFr = null;
      if (c.dairaAr!.isEmpty) c.dairaAr = null;
    }
    communes[id] = c;
  }

  for (final e in communeItems.entries) {
    if (exclude.contains(e.key)) continue;
    addCommune(e.key, e.value,
        (wilayaFix[e.key]?['wilaya'] ?? include[e.key]?['wilaya']) as String?);
  }
  for (final e in include.entries) {
    if (communes.containsKey(e.key)) continue;
    final item = extraItems[e.key];
    if (item == null) {
      problems.add('${e.key}: included item missing from snapshot');
      continue;
    }
    addCommune(e.key, item, e.value['wilaya'] as String);
  }

  // Apply law 26-06: move the listed communes to the new wilayas, and check
  // that each mother keeps exactly the communes the law lists.
  final mothers =
      (law['mothers'] as Map<String, dynamic>).cast<String, List<dynamic>>();
  for (final c in communes.values) {
    c.code2026 = c.code2019;
  }
  String? resolve(String name, List<_Commune> pool) {
    final hits = pool.where((c) => _fold(c.fr) == _fold(name)).toList();
    if (hits.length == 1) return hits.single.id;
    if (hits.length > 1) {
      problems.add('Law name "$name" is ambiguous: ${hits.map((c) => c.id)}');
      return null;
    }
    final alias = aliases[name];
    if (alias != null && pool.any((c) => c.id == alias)) return alias;
    problems.add('Law name "$name" not found');
    return null;
  }

  for (final m in mothers.entries) {
    final pool = communes.values.where((c) => c.code2019 == m.key).toList();
    final used = <String>{};
    for (final name in m.value.cast<String>()) {
      final id = resolve(name, pool);
      if (id != null && !used.add(id)) problems.add('Duplicate match $name');
    }
    for (final nw in newWilayas.entries) {
      if (nw.value['mother'] != m.key) continue;
      for (final name
          in (nw.value['communes'] as List<dynamic>).cast<String>()) {
        final id = resolve(name, pool);
        if (id == null) continue;
        if (!used.add(id)) problems.add('Duplicate match $name');
        communes[id]!.code2026 = nw.key;
      }
    }
    final left = pool.where((c) => !used.contains(c.id));
    for (final c in left) {
      problems.add('Wilaya ${m.key}: ${c.id} ${c.fr} is not listed in law');
    }
  }

  // Check counts.
  final counts = (expected['counts'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();
  final actual = <String, int>{};
  for (final c in communes.values) {
    actual[c.code2026!] = (actual[c.code2026!] ?? 0) + 1;
  }
  for (final e in counts.entries) {
    final want = e.value['communes'] as int;
    if (actual[e.key] != want) {
      problems.add('Wilaya ${e.key}: ${actual[e.key]} communes, want $want');
    }
  }
  if (communes.length != expected['total']) {
    problems.add('Total ${communes.length}, want ${expected['total']}');
  }

  // Wilayas.
  final wilayaOut = <Map<String, Object?>>[];
  for (final e in wilayaItems.entries) {
    final iso = e.value['iso'] as String?;
    if (iso == null) continue;
    wilayaOut.add({
      'code': int.parse(iso.substring(3)),
      'fr': _cleanWilayaFr(e.value['fr'] as String),
      'ar': _cleanWilayaAr(e.value['ar'] as String),
      'en': _cleanWilayaEn(e.value['en'] as String),
      'coord': _parsePoint(
          (e.value['coords'] as List<dynamic>?)?.cast<String>().first),
      'mother': null,
      'id': e.key,
    });
  }
  for (final nw in newWilayas.entries) {
    final id = nw.value['wikidata'] as String?;
    final item = id == null ? null : wilayaItems[id];
    final coord =
        _parsePoint((item?['coords'] as List<dynamic>?)?.cast<String>().first);
    wilayaOut.add({
      'code': int.parse(nw.key),
      'fr': nw.value['fr'],
      'ar': nw.value['ar'],
      'en': item == null
          ? nw.value['fr']
          : _cleanWilayaEn(item['en'] as String? ?? nw.value['fr'] as String),
      'coord': coord,
      'mother': int.parse(nw.value['mother'] as String),
      'id': id,
    });
  }
  wilayaOut.sort((a, b) => (a['code'] as int).compareTo(b['code'] as int));

  // Centre point: the chef-lieu, which decree 84-79 (and 26-206 for the new
  // wilayas) names after the wilaya. Use that commune's coordinates so every
  // wilaya is placed the same way; fall back to the wilaya item's P625 (or
  // an explicit seat from wikidata_fixes.json) when no commune matches.
  final seats = (fixes['seats'] as Map<String, dynamic>? ?? const {})
      .cast<String, Map<String, dynamic>>();
  final seatFallbacks = <String>[];
  for (final w in wilayaOut) {
    final code = w['code'].toString().padLeft(2, '0');
    final seatId = seats[code]?['commune'] as String?;
    final seat = communes.values.where((c) =>
        c.code2026 == code &&
        (seatId != null
            ? c.id == seatId
            : _fold(c.fr) == _fold(w['fr'] as String)));
    if (seat.length == 1 && seat.single.coord != null) {
      w['coord'] = seat.single.coord;
    } else {
      seatFallbacks.add('$code ${w['fr']}');
    }
  }
  if (seatFallbacks.isNotEmpty) {
    stdout.writeln('Wilaya item coordinates used for: $seatFallbacks');
  }
  if (wilayaOut.length != 69) problems.add('${wilayaOut.length} wilayas');
  for (final w in wilayaOut) {
    if (w['coord'] == null) problems.add('Wilaya ${w['code']} has no coords');
  }

  if (problems.isNotEmpty) {
    stderr.writeln('Refusing to write data:\n  ${problems.join('\n  ')}');
    exit(1);
  }

  _writeWilayas(wilayaOut);
  _writeCommunes(communes.values.toList(), snap['retrieved'] as String);
  final fmt = Process.runSync('dart', ['format', _p('lib/src/geo/data')]);
  stdout.write(fmt.stdout);
  stdout.writeln('${wilayaOut.length} wilayas, ${communes.length} communes, '
      '${communes.values.where((c) => c.dairaFr != null).length} with daïra.');
}

const _header = '// GENERATED by tool/generate_data.dart. Do not edit.\n'
    '//\n'
    '// Sources: Wikidata (CC0 1.0, https://www.wikidata.org), and for the\n'
    '// 2026 division loi 26-06 (JORADP 2026 n° 25) and décret présidentiel\n'
    '// 26-206 (JORADP 2026 n° 40). See README "Data sources".\n';

void _writeWilayas(List<Map<String, Object?>> rows) {
  final b = StringBuffer(_header)
    ..writeln()
    ..writeln("import '../models.dart';")
    ..writeln()
    ..writeln('/// All 69 wilayas, ordered by code.')
    ..writeln('const List<Wilaya> wilayaData = [');
  for (final w in rows) {
    final (lat, lon) = w['coord']! as (double, double);
    b.writeln('  Wilaya(code: ${w['code']}, nameAr: ${_lit(w['ar'])}, '
        'nameFr: ${_lit(w['fr'])}, nameEn: ${_lit(w['en'])}, '
        'latitude: $lat, longitude: $lon'
        '${w['mother'] == null ? '' : ', motherCode: ${w['mother']}'}'
        '${w['id'] == null ? '' : ', wikidataId: ${_lit(w['id'])}'}),');
  }
  b.writeln('];');
  File(_p('lib/src/geo/data/wilayas.g.dart')).writeAsStringSync(b.toString());
}

void _writeCommunes(List<_Commune> list, String retrieved) {
  list.sort((a, b) {
    final c = int.parse(a.code2026!).compareTo(int.parse(b.code2026!));
    if (c != 0) return c;
    final n = _fold(a.fr).compareTo(_fold(b.fr));
    return n != 0 ? n : a.id.compareTo(b.id);
  });
  final b = StringBuffer(_header)
    ..writeln()
    ..writeln("import '../models.dart';")
    ..writeln()
    ..writeln('/// Date the Wikidata snapshot was taken.')
    ..writeln("const String wikidataSnapshotDate = '$retrieved';")
    ..writeln()
    ..writeln('/// All 1541 communes, ordered by wilaya then French name.')
    ..writeln('const List<Commune> communeData = [');
  for (final c in list) {
    b.write('  Commune(wikidataId: ${_lit(c.id)}, nameAr: ${_lit(c.ar)}, '
        'nameFr: ${_lit(c.fr)}, wilayaCode: ${int.parse(c.code2026!)}, '
        'wilayaCode2019: ${int.parse(c.code2019)}');
    if (c.dairaAr != null) b.write(', dairaAr: ${_lit(c.dairaAr)}');
    if (c.dairaFr != null) b.write(', dairaFr: ${_lit(c.dairaFr)}');
    if (c.coord != null) {
      b.write(', latitude: ${c.coord!.$1}, longitude: ${c.coord!.$2}');
    }
    b.writeln('),');
  }
  b.writeln('];');
  File(_p('lib/src/geo/data/communes.g.dart')).writeAsStringSync(b.toString());
}

String _lit(Object? s) {
  final str = s! as String;
  return "'${str.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";
}

(double, double)? _parsePoint(String? wkt) {
  if (wkt == null) return null;
  final m = RegExp(r'Point\(([-0-9.eE]+) ([-0-9.eE]+)\)').firstMatch(wkt);
  if (m == null) return null;
  double r(String s) => (double.parse(s) * 1e6).round() / 1e6;
  return (r(m.group(2)!), r(m.group(1)!));
}

// ---------------------------------------------------------------------------
// Label cleanup

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String _cleanFr(String s) =>
    _squash(s.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').split(',').first);

String _cleanAr(String s) {
  var t = s.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '');
  t = t.split(RegExp('[،,]')).first;
  t = t.replaceFirst(RegExp(r'^بلدية\s+'), '');
  return _squash(t);
}

String _cleanWilayaFr(String s) => _squash(s.replaceFirst(
    RegExp(r"^wilaya\s+(de\s+|d['’]\s*)", caseSensitive: false), ''));

String _cleanWilayaAr(String s) =>
    _squash(s.replaceFirst(RegExp(r'^ولاية\s+'), ''));

String _cleanWilayaEn(String s) =>
    _squash(s.replaceFirst(RegExp(r'\s+Province$'), ''));

String _cleanDairaFr(String s) => _squash(s
    .replaceFirst(
        RegExp(r"^da[iï]ra\s+(de\s+|d['’]\s*|du\s+|des\s+)?",
            caseSensitive: false),
        '')
    .replaceFirst(RegExp(r'\s+District$'), ''));

String _cleanDairaAr(String s) => _squash(
    s.replaceFirst(RegExp(r'^دائرة\s+'), '').split(RegExp('[،,]')).first);

/// Accent-, case- and punctuation-insensitive key for matching names.
String _fold(String s) {
  const from = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final out = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    final c = i >= 0 ? to[i] : ch;
    if (RegExp(r'[a-z0-9]').hasMatch(c)) out.write(c);
  }
  return out.toString();
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
