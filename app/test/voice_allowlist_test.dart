import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:symptom_engine/symptom_engine.dart';
import 'package:symptombridge/intake_questions.dart';

/// The Worker reads aloud only the app's own sentences. This keeps its list
/// in step with the app: run with UPDATE_SPOKEN=1 to rewrite it.
void main() {
  test('the Worker can read aloud exactly the questions the app asks', () {
    final file = File('../worker/worker.js');
    final source = file.readAsStringSync();
    final expected = {for (final l in Lang.values) l.name: spokenTexts(l)};
    final block = RegExp(r'(// SPOKEN-BEGIN[^\n]*\n)const SPOKEN = (.*?);\n(// SPOKEN-END)', dotAll: true);
    final match = block.firstMatch(source);
    expect(match, isNotNull, reason: 'SPOKEN block missing in worker.js');

    final current = jsonDecode(match!.group(2)!) as Map<String, dynamic>;
    final same = jsonEncode(current) == jsonEncode(expected);
    if (!same && Platform.environment['UPDATE_SPOKEN'] == '1') {
      final json = const JsonEncoder.withIndent('  ').convert(expected);
      file.writeAsStringSync(source.replaceRange(match.start, match.end, '${match.group(1)}const SPOKEN = $json;\n${match.group(3)}'));
      return;
    }
    expect(same, isTrue, reason: 'run: UPDATE_SPOKEN=1 flutter test test/voice_allowlist_test.dart');
  });
}
