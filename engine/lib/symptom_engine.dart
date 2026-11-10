/// Turns what a patient says into findings, red flags and hypotheses a
/// clinician can check. Rules and an explicit knowledge base, no model.
library;

import 'src/differential.dart';
import 'src/extractor.dart';
import 'src/red_flags.dart';
import 'src/understanding.dart';

export 'src/concepts.dart';
export 'src/differential.dart';
export 'src/extractor.dart';
export 'src/red_flags.dart';
export 'src/understanding.dart';

/// Everything the clinician's screen shows for one patient.
class Assessment {
  Assessment(this.turns, this.extraction, this.redFlags, this.hypotheses, {this.merge, this.modelError, this.model});
  final List<Utterance> turns;
  final Extraction extraction;
  final List<RedFlag> redFlags;
  final List<Hypothesis> hypotheses;

  /// What the language model added, confirmed or was overruled on; null when rules only.
  final MergeReport? merge;

  /// Why the model could not be used (quota, network); the assessment is then rules only.
  final String? modelError;
  final String? model;
}

Assessment assess(String transcript) {
  final turns = parseTranscript(transcript);
  final extraction = extract(turns);
  return Assessment(turns, extraction, redFlags(extraction), differential(extraction));
}

/// Rules, then a language model on top when one is given. If the model
/// fails for any reason, the rules-only assessment is returned with the
/// reason, so the clinician's screen never goes blank.
Future<Assessment> assessWith(String transcript, Understander? understander) async {
  final turns = parseTranscript(transcript);
  final rules = extract(turns);
  if (understander == null) return Assessment(turns, rules, redFlags(rules), differential(rules));
  try {
    final model = await understander.understand(transcript);
    final (merged, report) = merge(rules, model, transcript);
    return Assessment(turns, merged, redFlags(merged), differential(merged), merge: report, model: understander.name);
  } on Exception catch (e) {
    return Assessment(turns, rules, redFlags(rules), differential(rules), modelError: '$e', model: understander.name);
  }
}
