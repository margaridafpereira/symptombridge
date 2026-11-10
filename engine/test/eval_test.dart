import 'dart:convert';
import 'dart:io';

import 'package:symptom_engine/symptom_engine.dart';
import 'package:test/test.dart';

/// Runs the fictional cases through the engine and compares them with what a
/// clinician would expect.
///
/// - `cases.json` is the development set: written alongside the rules, so it
///   shows the engine does what it was built to do. A missed red flag fails.
/// - `challenge.json` was written afterwards to break it (colloquial words,
///   vague answers, speech-recognition errors) and is never tuned against.
///   It only reports.
void main() {
  _run('Development set', '../eval/cases.json', enforce: true);
  _run('Challenge set', '../eval/challenge.json', enforce: false);
}

void _run(String name, String path, {required bool enforce}) {
  final cases = (jsonDecode(File(path).readAsStringSync()) as List).cast<Map<String, dynamic>>();
  var expectedPresent = 0, foundPresent = 0, unexpected = 0, totalPresent = 0;
  var expectedAbsent = 0, foundAbsent = 0;
  var expectedFlags = 0, foundFlags = 0, falseFlags = 0;
  var scored = 0, top1 = 0, top3 = 0;
  final problems = <String>[];

  group(name, () {
    for (final c in cases) {
      test('${c['id']} ${c['title']}', () {
        final a = assess(c['transcript'] as String);
        final e = a.extraction;
        final present = (c['present'] as List).cast<String>();
        final absent = (c['absent'] as List).cast<String>();
        final notPresent = ((c['notPresent'] as List?) ?? const []).cast<String>();
        final flags = (c['redFlags'] as List).cast<String>().toSet();
        final dx = c['diagnosis'] as String?;

        expectedPresent += present.length;
        foundPresent += present.where(e.has).length;
        final extra = e.present.map((f) => f.concept.id).where((id) => !present.contains(id)).toList();
        totalPresent += e.present.length;
        unexpected += extra.length;
        expectedAbsent += absent.length;
        foundAbsent += absent.where(e.denied).length;

        final raised = a.redFlags.map((f) => f.id).toSet();
        expectedFlags += flags.length;
        foundFlags += flags.intersection(raised).length;
        falseFlags += raised.difference(flags).length;

        final ranked = a.hypotheses.map((h) => h.condition.id).toList();
        if (dx != null) {
          scored++;
          if (ranked.isNotEmpty && ranked.first == dx) top1++;
          if (ranked.take(3).contains(dx)) top3++;
        }

        final missed = present.where((id) => !e.has(id)).toList();
        final missedNeg = absent.where((id) => !e.denied(id)).toList();
        final wrongFlags = !(raised.length == flags.length && raised.containsAll(flags));
        final wrongDx = dx != null && !ranked.take(3).contains(dx);
        if (missed.isNotEmpty || missedNeg.isNotEmpty || extra.isNotEmpty || wrongFlags || wrongDx) {
          problems.add([
            '${c['id']} ${c['title']}:',
            if (missed.isNotEmpty) 'missed $missed',
            if (missedNeg.isNotEmpty) 'negation missed $missedNeg',
            if (extra.isNotEmpty) 'not in the case $extra${extra.any(notPresent.contains) ? ' (a trap)' : ''}',
            if (wrongFlags) 'red flags $raised, expected $flags',
            if (wrongDx) 'top 3 $ranked, expected $dx',
          ].join(' '));
        }

        if (enforce) {
          expect(raised.containsAll(flags), isTrue, reason: 'missed red flag: ${flags.difference(raised)}');
        }
      });
    }

    tearDownAll(() {
      String pct(int a, int b) => b == 0 ? '—' : '${(100 * a / b).toStringAsFixed(0)} %';
      final report = '''
$name: ${cases.length} fictional cases
  Findings recalled          ${pct(foundPresent, expectedPresent)}  ($foundPresent/$expectedPresent)
  Findings not in the case   ${pct(unexpected, totalPresent)}  ($unexpected/$totalPresent)
  Negations understood       ${pct(foundAbsent, expectedAbsent)}  ($foundAbsent/$expectedAbsent)
  Red flags caught           ${pct(foundFlags, expectedFlags)}  ($foundFlags/$expectedFlags)
  False red flags            $falseFlags
  Right condition first      ${pct(top1, scored)}  ($top1/$scored)
  Right condition in top 3   ${pct(top3, scored)}  ($top3/$scored)
${problems.isEmpty ? '' : '  Misses:\n    ${problems.join('\n    ')}\n'}''';
      // ignore: avoid_print
      print(report);
      final out = File('../eval/report.md');
      final previous = out.existsSync() && !enforce ? out.readAsStringSync() : '';
      out.writeAsStringSync('$previous```\n$report```\n\n');
    });
  });
}
