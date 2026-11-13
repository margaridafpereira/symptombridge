import 'concepts.dart';
import 'lang.dart';

/// Who said it. In the pre-visit interview everything is the patient.
enum Speaker { patient, clinician }

class Utterance {
  const Utterance(this.speaker, this.text);
  final Speaker speaker;
  final String text;
}

/// Who found it: the rules, the language model, or both agreeing.
enum FindingSource { rules, model, both }

/// One thing we learnt, with the words that show it.
class Finding {
  const Finding(this.concept, this.present, this.evidence, [this.source = FindingSource.rules]);
  final Concept concept;
  final FindingSource source;

  /// False when the patient denied it ("não tenho febre").
  final bool present;

  /// The words in the transcript this comes from, so a clinician can check.
  final String evidence;

  @override
  String toString() => '${present ? '+' : '-'}${concept.id} «$evidence»';
}

class Extraction {
  Extraction({
    required this.findings,
    this.age,
    this.temperature,
    this.severity,
    this.durations = const [],
  });

  /// One per concept: the latest statement wins ("no fever… actually yes, last night").
  final Map<String, Finding> findings;
  final int? age;
  final double? temperature;

  /// Pain on a 0–10 scale.
  final int? severity;

  /// As said: "há 3 dias", "since yesterday".
  final List<String> durations;

  bool has(String id) => findings[id]?.present ?? false;
  bool denied(String id) => findings[id]?.present == false;
  bool mentioned(String id) => findings.containsKey(id);

  Iterable<Finding> get present => findings.values.where((f) => f.present);
  Iterable<Finding> get absent => findings.values.where((f) => !f.present);
}

/// Splits "Médico: … / Doente: …" (or "Doctor: … / Patient: …") transcripts
/// into turns. Lines without a speaker label belong to the patient.
List<Utterance> parseTranscript(String text) {
  final label = RegExp(
    r'^\s*(m[eé]dic[oa]|dr\.?|dra\.?|enfermeir[oa]|doente|paciente|utente|doctor|clinician|nurse|patient)\s*:\s*',
    caseSensitive: false,
  );
  final out = <Utterance>[];
  for (final line in text.split(RegExp(r'\r?\n'))) {
    if (line.trim().isEmpty) continue;
    final m = label.firstMatch(line);
    if (m == null) {
      out.add(Utterance(Speaker.patient, line.trim()));
      continue;
    }
    final who = m.group(1)!.toLowerCase();
    const patientLabels = ['doente', 'paciente', 'utente', 'patient'];
    final speaker = patientLabels.contains(who) ? Speaker.patient : Speaker.clinician;
    out.add(Utterance(speaker, line.substring(m.end).trim()));
  }
  return out;
}

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'è': 'e', 'í': 'i', 'ì': 'i',
  'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o', 'ú': 'u', 'ù': 'u', 'ü': 'u', 'ç': 'c', '’': "'",
};

/// Lower case without accents, one character for one character, so match
/// positions map straight back to the original text.
String normalize(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

final _compiled = {
  for (final lang in Lang.values)
    lang: {
      for (final c in concepts) c: [for (final p in c.phrasesFor(lang)) RegExp(p)],
    },
};

/// Everything about reading a patient that depends on the language.
class _Grammar {
  const _Grammar({
    required this.negation,
    required this.clauseBreak,
    required this.yes,
    required this.no,
    required this.age,
    required this.temperature,
    required this.severity,
    required this.durations,
  });
  final RegExp negation, clauseBreak, yes, no, temperature, severity, durations;

  /// In each pattern, group 1 is the age.
  final List<RegExp> age;
}

final _grammar = {
  Lang.pt: _Grammar(
    negation: RegExp(r'\b(nao|sem|nunca|nenhum\w*|nem|negou)\b'),
    // "e" starts a new clause only before an affirmative verb: "não tenho febre e
    // tenho tosse" keeps the cough, "sem febre e tosse" denies both.
    clauseBreak: RegExp(r'[.;!?]|,\s|\bmas\b|\bporem\b|\be (?=(tenho|tive|estou|sinto|doi|doem|comecei|fiquei|ando|agora)\b)'),
    yes: RegExp(r'^\s*(sim|tenho|tive|ja|um pouco|um bocado|algum[a]?|bastante|muito)\b'),
    no: RegExp(r'^\s*(nao|nunca|nada|nenhum[a]?)\b'),
    // "Tenho 58 anos", not "há 3 anos".
    age: [RegExp(r'\b(?:tenho|com|idade de) (\d{1,3}) anos\b')],
    temperature: RegExp(r'\b(3[5-9]|4[0-2])([.,](\d))?\s*(graus|º|°)'),
    severity: RegExp(r'\b(\d{1,2})\s*(em|de|numa escala de|sobre)\s*10\b'),
    durations: RegExp(
      r'\b(ha|desde ha|faz) (\d+|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|meia|algumas|poucas) (minutos?|horas?|dias?|semanas?|meses|mes|anos?)\b'
      r'|\bdesde (ontem|anteontem|hoje|esta manha|a noite passada|o fim de semana)\b',
    ),
  ),
  Lang.en: _Grammar(
    negation: RegExp(r"\b(no|not|never|without|none|nor|denies|denied)\b|n't\b"),
    clauseBreak: RegExp(r"[.;!?]|,\s|\bbut\b|\bthough\b|\band (?=(i have|i've|i am|i'm|i feel|it hurts|now|i started)\b)"),
    yes: RegExp(r'^\s*(yes|yeah|yep|i do|i have|a bit|a little|some|quite|very|sometimes)\b'),
    no: RegExp(r'^\s*(no|nope|never|not really|none|nothing)\b'),
    // "I'm 62" or "62 years old", not "for 3 days".
    age: [
      RegExp(r'\b(\d{1,3})[- ]years?[- ]old\b'),
      RegExp(r"\b(?:i'm|i am|aged) (\d{1,3})\b(?! ?(minutes?|hours?|days?|weeks?|months?|degrees|out of|/))"),
    ],
    temperature: RegExp(r'\b(3[5-9]|4[0-2])([.,](\d))?\s*(degrees|º|°)'),
    severity: RegExp(r'\b(\d{1,2})\s*(out of|/|on a scale of)\s*10\b'),
    durations: RegExp(
      r'\bfor (the (last|past) )?(\d+|a|an|one|two|three|four|five|six|seven|a few|a couple of|several) (minutes?|hours?|days?|weeks?|months?|years?)\b'
      r'|\b(\d+|an?|one|two|three|a few|a couple of) (minutes?|hours?|days?|weeks?|months?) ago\b'
      r'|\bsince (yesterday|this morning|last night|the weekend|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    ),
  ),
};

/// Was the match at [start] negated within its clause? "Não tenho febre nem
/// tosse" negates both; "não tenho febre, mas tenho tosse" only the first.
bool _negated(String norm, int start, _Grammar g) {
  var clauseStart = 0;
  for (final m in g.clauseBreak.allMatches(norm.substring(0, start))) {
    clauseStart = m.end;
  }
  final before = norm.substring(clauseStart, start);
  // Look at the last few words only: "não sei porquê, mas dói-me o peito".
  final words = before.trim().split(RegExp(r'\s+'));
  final window = words.length > 5 ? words.sublist(words.length - 5).join(' ') : words.join(' ');
  return g.negation.hasMatch(window);
}

List<Finding> _match(String text, Lang lang, {bool? forcePresent}) {
  final norm = normalize(text);
  final g = _grammar[lang]!;
  final out = <Finding>[];
  for (final MapEntry(key: concept, value: patterns) in _compiled[lang]!.entries) {
    for (final re in patterns) {
      for (final m in re.allMatches(norm)) {
        final present = forcePresent ?? (concept.negationInside || !_negated(norm, m.start, g));
        out.add(Finding(concept, present, text.substring(m.start, m.end)));
      }
    }
  }
  return out;
}

Extraction extract(List<Utterance> turns, {Lang lang = Lang.pt}) {
  final g = _grammar[lang]!;
  final findings = <String, Finding>{};
  void put(Finding f) => findings[f.concept.id] = f;

  for (var i = 0; i < turns.length; i++) {
    final t = turns[i];
    if (t.speaker == Speaker.patient) {
      for (final f in _match(t.text, lang)) {
        put(f);
      }
      continue;
    }
    // A clinician's question counts only through the patient's yes or no.
    if (!t.text.trim().endsWith('?') || i + 1 >= turns.length || turns[i + 1].speaker != Speaker.patient) continue;
    final answer = normalize(turns[i + 1].text);
    final bool? yes = g.yes.hasMatch(answer) ? true : (g.no.hasMatch(answer) ? false : null);
    if (yes == null) continue;
    for (final f in _match(t.text, lang, forcePresent: yes)) {
      put(Finding(f.concept, yes, '${f.evidence}? ${turns[i + 1].text}'));
    }
  }

  final patientText = turns.where((t) => t.speaker == Speaker.patient).map((t) => t.text).join('\n');
  final norm = normalize(patientText);

  int? age;
  for (final re in g.age) {
    final a = re.firstMatch(norm);
    if (a != null) {
      age = int.tryParse(a.group(1)!);
      break;
    }
  }

  double? temperature;
  final tm = g.temperature.firstMatch(norm);
  if (tm != null) {
    temperature = double.parse('${tm.group(1)}.${tm.group(3) ?? '0'}');
    if (temperature >= 38 && !findings.containsKey('fever')) {
      put(Finding(conceptsById['fever']!, true, patientText.substring(tm.start, tm.end)));
    }
  }

  int? severity;
  final sv = g.severity.firstMatch(norm);
  if (sv != null) severity = int.tryParse(sv.group(1)!);

  final durations = [for (final m in g.durations.allMatches(norm)) patientText.substring(m.start, m.end)];

  return Extraction(findings: findings, age: age, temperature: temperature, severity: severity, durations: durations);
}
