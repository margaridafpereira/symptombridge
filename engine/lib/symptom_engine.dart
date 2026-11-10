/// Turns what a patient says into findings, red flags and hypotheses a
/// clinician can check. Rules and an explicit knowledge base, no model.
library;

import 'src/differential.dart';
import 'src/extractor.dart';
import 'src/red_flags.dart';

export 'src/concepts.dart';
export 'src/differential.dart';
export 'src/extractor.dart';
export 'src/red_flags.dart';

/// Everything the clinician's screen shows for one patient.
class Assessment {
  Assessment(this.turns, this.extraction, this.redFlags, this.hypotheses);
  final List<Utterance> turns;
  final Extraction extraction;
  final List<RedFlag> redFlags;
  final List<Hypothesis> hypotheses;
}

Assessment assess(String transcript) {
  final turns = parseTranscript(transcript);
  final extraction = extract(turns);
  return Assessment(turns, extraction, redFlags(extraction), differential(extraction));
}
