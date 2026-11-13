import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'concepts.dart';
import 'extractor.dart';
import 'lang.dart';

/// What a language model read in the transcript, before we trust it.
class ModelFinding {
  const ModelFinding(this.id, {required this.present, required this.quote, this.aboutOther = false, this.past = false});
  final String id;
  final bool present;

  /// The exact words the model says it read. Checked against the transcript.
  final String quote;

  /// About someone else ("o meu pai teve um enfarte").
  final bool aboutOther;

  /// Said to have happened before and gone.
  final bool past;

  factory ModelFinding.fromJson(Map<String, Object?> j) => ModelFinding(
        j['id'] as String? ?? '',
        present: j['status'] != 'absent',
        quote: j['quote'] as String? ?? '',
        aboutOther: j['who'] == 'other',
        past: j['when'] == 'past',
      );
}

/// Something that reads a transcript and says which concepts it mentions.
abstract class Understander {
  String get name;
  Future<List<ModelFinding>> understand(String transcript);
}

/// Gemini behind the SymptomBridge Cloudflare Worker (worker/worker.js).
class WorkerUnderstander implements Understander {
  WorkerUnderstander(this.endpoint, {http.Client? client, this.timeout = const Duration(seconds: 40)})
      : _client = client ?? http.Client();

  final Uri endpoint;
  final Duration timeout;
  final http.Client _client;

  @override
  String get name => 'Gemini (via ${endpoint.host})';

  @override
  Future<List<ModelFinding>> understand(String transcript) async {
    final body = jsonEncode({
      'transcript': transcript,
      'concepts': [for (final c in concepts) {'id': c.id, 'label': '${c.pt} (${c.en})'}],
    });
    final r = await _client
        .post(endpoint, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(timeout);
    final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, Object?>;
    if (r.statusCode != 200) throw UnderstandingException(json['error'] as String? ?? 'HTTP ${r.statusCode}');
    return [
      for (final f in (json['findings'] as List? ?? const []))
        if (f is Map) ModelFinding.fromJson(f.cast<String, Object?>()),
    ];
  }
}

class UnderstandingException implements Exception {
  UnderstandingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What the merge did, for the clinician and for the evaluation.
class MergeReport {
  final added = <Finding>[];
  final confirmed = <Finding>[];

  /// The model's words were not in the transcript: thrown away.
  final rejected = <ModelFinding>[];

  /// History that belongs to someone else, taken off the patient.
  final reattributed = <Finding>[];

  /// Things the clinician should see but that change nothing on their own:
  /// "the patient says it has gone", "the model read this as denied".
  final notes = <String>[];
}

/// Combines the rule-based findings with what the model read.
///
/// Safety rules:
/// - the model can add findings, never delete one the rules found: a
///   disagreement becomes a note for the clinician;
/// - the one exception is history attributed to someone else, which stops
///   counting as the patient's;
/// - every model finding must quote words that really are in the transcript.
(Extraction, MergeReport) merge(Extraction rules, List<ModelFinding> model, String transcript, {Lang lang = Lang.pt}) {
  final report = MergeReport();
  final l = lang.pick;
  final findings = Map.of(rules.findings);
  final text = normalize(transcript).replaceAll(RegExp(r'\s+'), ' ');

  for (final m in model) {
    final concept = conceptsById[m.id];
    final quote = normalize(m.quote).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (concept == null || quote.length < 2 || !text.contains(quote)) {
      report.rejected.add(m);
      continue;
    }
    final existing = findings[m.id];

    if (m.aboutOther) {
      if (concept.kind == Kind.history && existing != null && existing.present) {
        findings.remove(m.id);
        report.reattributed.add(existing);
        report.notes.add(l('${concept.pt}: refere-se a outra pessoa («${m.quote}»), não conta como do doente.',
            '${concept.en}: about someone else («${m.quote}»), not counted as the patient\'s.'));
      }
      continue;
    }

    final present = m.present && !m.past;
    if (existing == null) {
      final f = Finding(concept, present, m.quote, FindingSource.model);
      findings[m.id] = f;
      report.added.add(f);
      if (m.present && m.past) {
        report.notes.add(l('${concept.pt}: o doente diz que já passou («${m.quote}»).',
            '${concept.en}: the patient says it has gone («${m.quote}»).'));
      }
    } else if (existing.present == present) {
      final f = Finding(concept, present, existing.evidence, FindingSource.both);
      findings[m.id] = f;
      report.confirmed.add(f);
    } else if (!existing.present && present) {
      // Present beats denied: missing a symptom is the worse error.
      final f = Finding(concept, true, m.quote, FindingSource.model);
      findings[m.id] = f;
      report.added.add(f);
      report.notes.add(l('${concept.pt}: as regras leram negado, o modelo leu presente («${m.quote}»).',
          '${concept.en}: rules read it as denied, the model as present («${m.quote}»).'));
    } else {
      report.notes.add(m.past
          ? l('${concept.pt}: o doente diz que já passou («${m.quote}»); continua visível, confirme.',
              '${concept.en}: the patient says it has gone («${m.quote}»); still shown, please check.')
          : l('${concept.pt}: o modelo leu como negado («${m.quote}»); continua visível, confirme.',
              '${concept.en}: the model read it as denied («${m.quote}»); still shown, please check.'));
    }
  }

  return (
    Extraction(
      findings: findings,
      age: rules.age,
      temperature: rules.temperature,
      severity: rules.severity,
      durations: rules.durations,
    ),
    report,
  );
}
