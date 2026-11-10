import 'concepts.dart';

/// Who said it. In the pre-visit interview everything is the patient.
enum Speaker { patient, clinician }

class Utterance {
  const Utterance(this.speaker, this.text);
  final Speaker speaker;
  final String text;
}

/// One thing we learnt, with the words that show it.
class Finding {
  const Finding(this.concept, this.present, this.evidence);
  final Concept concept;

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

  /// As said: "há 3 dias", "desde ontem".
  final List<String> durations;

  bool has(String id) => findings[id]?.present ?? false;
  bool denied(String id) => findings[id]?.present == false;
  bool mentioned(String id) => findings.containsKey(id);

  Iterable<Finding> get present => findings.values.where((f) => f.present);
  Iterable<Finding> get absent => findings.values.where((f) => !f.present);
}

/// Splits "Médico: … / Doente: …" transcripts into turns. Lines without a
/// speaker label belong to the patient.
List<Utterance> parseTranscript(String text) {
  final label = RegExp(r'^\s*(m[eé]dic[oa]|dr\.?|dra\.?|enfermeir[oa]|doente|paciente|utente)\s*:\s*', caseSensitive: false);
  final out = <Utterance>[];
  for (final line in text.split(RegExp(r'\r?\n'))) {
    if (line.trim().isEmpty) continue;
    final m = label.firstMatch(line);
    if (m == null) {
      out.add(Utterance(Speaker.patient, line.trim()));
      continue;
    }
    final who = m.group(1)!.toLowerCase();
    final speaker = who.startsWith('doente') || who.startsWith('paciente') || who.startsWith('utente')
        ? Speaker.patient
        : Speaker.clinician;
    out.add(Utterance(speaker, line.substring(m.end).trim()));
  }
  return out;
}

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'è': 'e', 'í': 'i', 'ì': 'i',
  'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o', 'ú': 'u', 'ù': 'u', 'ü': 'u', 'ç': 'c',
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
  for (final c in concepts) c: [for (final p in c.phrases) RegExp(p)],
};

final _negation = RegExp(r'\b(nao|sem|nunca|nenhum\w*|nem|negou)\b');
// "e" starts a new clause only before an affirmative verb: "não tenho febre e
// tenho tosse" keeps the cough, "sem febre e tosse" denies both.
final _clauseBreak =
    RegExp(r'[.;!?]|,\s|\bmas\b|\bporem\b|\be (?=(tenho|tive|estou|sinto|doi|doem|comecei|fiquei|ando|agora)\b)');

/// Was the match at [start] negated within its clause? "Não tenho febre nem
/// tosse" negates both; "não tenho febre, mas tenho tosse" only the first.
bool _negated(String norm, int start) {
  var clauseStart = 0;
  for (final m in _clauseBreak.allMatches(norm.substring(0, start))) {
    clauseStart = m.end;
  }
  final before = norm.substring(clauseStart, start);
  // Look at the last few words only: "não sei porquê, mas dói-me o peito".
  final words = before.trim().split(RegExp(r'\s+'));
  final window = words.length > 5 ? words.sublist(words.length - 5).join(' ') : words.join(' ');
  return _negation.hasMatch(window);
}

List<Finding> _match(String text, {bool? forcePresent}) {
  final norm = normalize(text);
  final out = <Finding>[];
  for (final MapEntry(key: concept, value: patterns) in _compiled.entries) {
    for (final re in patterns) {
      for (final m in re.allMatches(norm)) {
        final present = forcePresent ?? (concept.negationInside || !_negated(norm, m.start));
        out.add(Finding(concept, present, text.substring(m.start, m.end)));
      }
    }
  }
  return out;
}

final _yes = RegExp(r'^\s*(sim|tenho|tive|ja|um pouco|um bocado|algum[a]?|bastante|muito)\b');
final _no = RegExp(r'^\s*(nao|nunca|nada|nenhum[a]?)\b');

Extraction extract(List<Utterance> turns) {
  final findings = <String, Finding>{};
  void put(Finding f) => findings[f.concept.id] = f;

  for (var i = 0; i < turns.length; i++) {
    final t = turns[i];
    if (t.speaker == Speaker.patient) {
      for (final f in _match(t.text)) {
        put(f);
      }
      continue;
    }
    // A clinician's question counts only through the patient's yes or no.
    if (!t.text.trim().endsWith('?') || i + 1 >= turns.length || turns[i + 1].speaker != Speaker.patient) continue;
    final answer = normalize(turns[i + 1].text);
    final bool? yes = _yes.hasMatch(answer) ? true : (_no.hasMatch(answer) ? false : null);
    if (yes == null) continue;
    for (final f in _match(t.text, forcePresent: yes)) {
      put(Finding(f.concept, yes, '${f.evidence}? ${turns[i + 1].text}'));
    }
  }

  final patientText = turns.where((t) => t.speaker == Speaker.patient).map((t) => t.text).join('\n');
  final norm = normalize(patientText);

  // "Tenho 58 anos", not "há 3 anos".
  final a = RegExp(r'\b(tenho|com|idade de) (\d{1,3}) anos\b').firstMatch(norm);
  final age = a == null ? null : int.tryParse(a.group(2)!);

  double? temperature;
  final tm = RegExp(r'\b(3[5-9]|4[0-2])([.,](\d))?\s*(graus|º|°)').firstMatch(norm);
  if (tm != null) {
    temperature = double.parse('${tm.group(1)}.${tm.group(3) ?? '0'}');
    if (temperature >= 38 && !findings.containsKey('fever')) {
      put(Finding(conceptsById['fever']!, true, patientText.substring(tm.start, tm.end)));
    }
  }

  int? severity;
  final sv = RegExp(r'\b(\d{1,2})\s*(em|de|numa escala de|sobre)\s*10\b').firstMatch(norm);
  if (sv != null) severity = int.tryParse(sv.group(1)!);

  final durations = [
    for (final m in RegExp(
      r'\b(ha|desde ha|faz) (\d+|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|meia|algumas|poucas) (minutos?|horas?|dias?|semanas?|meses|mes|anos?)\b|\bdesde (ontem|anteontem|hoje|esta manha|a noite passada|o fim de semana)\b',
    ).allMatches(norm))
      patientText.substring(m.start, m.end),
  ];

  return Extraction(findings: findings, age: age, temperature: temperature, severity: severity, durations: durations);
}
