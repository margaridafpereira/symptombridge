import 'extractor.dart';
import 'lang.dart';

enum Urgency {
  /// Act now: the patient should be seen immediately.
  emergency,

  /// See soon: within minutes to an hour.
  urgent,
}

class RedFlag {
  const RedFlag(this.id, this.urgency, this.en, this.pt, this.actionEn, this.actionPt, this.evidence);
  final String id;
  final Urgency urgency;
  final String en;
  final String pt;

  /// What the clinician should consider doing.
  final String actionEn;
  final String actionPt;

  /// The patient's words that raised it.
  final List<String> evidence;

  String label(Lang lang) => lang.pick(pt, en);
  String action(Lang lang) => lang.pick(actionPt, actionEn);

  @override
  String toString() => '$id (${urgency.name})';
}

class _Rule {
  const _Rule(this.id, this.urgency, this.en, this.pt, this.actionEn, this.actionPt, this.when, this.uses);
  final String id;
  final Urgency urgency;
  final String en, pt, actionEn, actionPt;
  final bool Function(Extraction e) when;

  /// Concepts whose evidence is shown with the flag.
  final List<String> uses;
}

/// Fixed rules, never a model: a missed red flag is the worst failure this
/// tool can have, so these are deliberately simple, sensitive and auditable.
/// They follow widely taught discriminators (Manchester Triage System, FAST,
/// NICE red flags). They flag for a clinician; they decide nothing.
final _rules = <_Rule>[
  _Rule(
    'acs', Urgency.emergency,
    'Possible acute coronary syndrome', 'Possível síndrome coronária aguda',
    'ECG within 10 minutes of arrival.', 'ECG nos primeiros 10 minutos.',
    (e) => e.has('chest_pain') && (e.has('radiation_arm_jaw') || e.has('sweating') || e.has('nausea') ||
        e.has('vomiting') || e.has('exertional') || e.has('cardiac_history') || e.has('syncope')),
    ['chest_pain', 'radiation_arm_jaw', 'sweating', 'nausea', 'vomiting', 'exertional', 'cardiac_history', 'syncope'],
  ),
  _Rule(
    'stroke', Urgency.emergency,
    'Possible stroke (FAST)', 'Possível AVC (FAST)',
    'Note the time symptoms started; activate the stroke pathway.', 'Registar a hora de início; ativar a Via Verde AVC.',
    (e) => e.has('face_droop') || e.has('limb_weakness') || e.has('speech_difficulty'),
    ['face_droop', 'limb_weakness', 'speech_difficulty'],
  ),
  _Rule(
    'thunderclap', Urgency.emergency,
    'Thunderclap headache', 'Cefaleia em trovão',
    'Exclude subarachnoid haemorrhage.', 'Excluir hemorragia subaracnoideia.',
    (e) => e.has('headache') && (e.has('worst_ever') || e.has('sudden_onset')),
    ['headache', 'worst_ever', 'sudden_onset'],
  ),
  _Rule(
    'meningism', Urgency.emergency,
    'Possible meningitis', 'Possível meningite',
    'Check for non-blanching rash; do not delay antibiotics if suspected.',
    'Procurar petéquias; não atrasar antibiótico se houver suspeita.',
    (e) => e.has('neck_stiffness') && (e.has('fever') || e.has('headache')) || e.has('fever') && e.has('rash'),
    ['neck_stiffness', 'fever', 'headache', 'rash', 'photophobia'],
  ),
  _Rule(
    'resp_distress', Urgency.emergency,
    'Breathing difficulty at rest', 'Dificuldade respiratória em repouso',
    'Check oxygen saturation and respiratory rate now.', 'Avaliar já saturação de oxigénio e frequência respiratória.',
    (e) => e.has('cannot_finish_sentences') || e.has('dyspnea') && e.has('at_rest'),
    ['dyspnea', 'at_rest', 'cannot_finish_sentences'],
  ),
  _Rule(
    'anaphylaxis', Urgency.emergency,
    'Possible anaphylaxis', 'Possível anafilaxia',
    'Assess airway; adrenaline if anaphylaxis is confirmed.', 'Avaliar via aérea; adrenalina se confirmada anafilaxia.',
    (e) => e.has('swelling_face_throat') && (e.has('dyspnea') || e.has('wheeze') || e.has('allergen')),
    ['swelling_face_throat', 'dyspnea', 'wheeze', 'allergen'],
  ),
  _Rule(
    'pe', Urgency.urgent,
    'Possible pulmonary embolism', 'Possível tromboembolismo pulmonar',
    'Assess with Wells score.', 'Avaliar com score de Wells.',
    (e) => (e.has('dyspnea') || e.has('pleuritic') || e.has('chest_pain')) &&
        (e.has('immobility') || e.has('leg_swelling') && e.has('one_leg') || e.has('hemoptysis')),
    ['dyspnea', 'pleuritic', 'chest_pain', 'immobility', 'leg_swelling', 'one_leg', 'hemoptysis'],
  ),
  _Rule(
    'sepsis', Urgency.emergency,
    'Fever with confusion: possible sepsis', 'Febre com confusão: possível sépsis',
    'Full observations now (qSOFA / NEWS2).', 'Sinais vitais completos já (qSOFA / NEWS2).',
    (e) => e.has('fever') && e.has('confusion'),
    ['fever', 'confusion'],
  ),
  _Rule(
    'peritonism', Urgency.emergency,
    'Rigid abdomen', 'Abdómen em tábua',
    'Surgical assessment now.', 'Avaliação cirúrgica imediata.',
    (e) => e.has('rigid_abdomen'),
    ['rigid_abdomen', 'abdominal_pain'],
  ),
  _Rule(
    'ectopic', Urgency.urgent,
    'Abdominal pain, possibly pregnant', 'Dor abdominal com possível gravidez',
    'Pregnancy test; exclude ectopic pregnancy.', 'Teste de gravidez; excluir gravidez ectópica.',
    (e) => e.has('abdominal_pain') && e.has('pregnant'),
    ['abdominal_pain', 'pregnant', 'syncope', 'dizziness'],
  ),
  _Rule(
    'gi_bleed', Urgency.urgent,
    'Possible gastrointestinal bleeding', 'Possível hemorragia digestiva',
    'Check heart rate and blood pressure.', 'Avaliar frequência cardíaca e tensão arterial.',
    (e) => e.has('hematemesis') || e.has('melena'),
    ['hematemesis', 'melena'],
  ),
  _Rule(
    'hemoptysis', Urgency.urgent,
    'Coughing up blood', 'Hemoptises',
    'Assess volume and oxygenation.', 'Avaliar quantidade e oxigenação.',
    (e) => e.has('hemoptysis'),
    ['hemoptysis'],
  ),
  _Rule(
    'cardiac_syncope', Urgency.urgent,
    'Fainting with cardiac features', 'Desmaio com sinais cardíacos',
    'ECG; consider arrhythmia.', 'ECG; considerar arritmia.',
    (e) => e.has('syncope') && (e.has('palpitations') || e.has('exertional') || e.has('chest_pain')),
    ['syncope', 'palpitations', 'exertional', 'chest_pain'],
  ),
  _Rule(
    'suicide', Urgency.emergency,
    'Thoughts of suicide', 'Pensamentos suicidas',
    'Do not leave the patient alone; follow the local risk protocol.', 'Não deixar o doente sozinho; seguir o protocolo local de risco.',
    (e) => e.has('suicidal'),
    ['suicidal'],
  ),
];

List<RedFlag> redFlags(Extraction e) => [
      for (final r in _rules)
        if (r.when(e))
          RedFlag(r.id, r.urgency, r.en, r.pt, r.actionEn, r.actionPt, [
            for (final id in r.uses)
              if (e.has(id)) e.findings[id]!.evidence,
          ]),
    ]..sort((a, b) => a.urgency.index.compareTo(b.urgency.index));
