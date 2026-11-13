import 'concepts.dart';
import 'extractor.dart';
import 'lang.dart';

class Condition {
  const Condition(this.id, this.en, this.pt, this.features,
      {required this.requires, this.against = const {}, this.dangerous = false});
  final String id;
  final String en;
  final String pt;

  /// Concept id → how strongly it points to this condition (1 weak … 4 near-specific).
  final Map<String, int> features;

  /// Concept id → how strongly its presence argues against.
  final Map<String, int> against;

  /// At least one of these must be present: the complaint the condition is
  /// about. Nausea alone does not make a migraine.
  final Set<String> requires;

  /// Must not be missed (shown even when it ranks lower).
  final bool dangerous;

  String label(Lang lang) => lang.pick(pt, en);
}

/// A deliberately small, explicit knowledge base for five presenting
/// complaints. Weights are hand-set from the classic textbook picture of
/// each condition; they rank and explain, they do not give probabilities.
const conditions = <Condition>[
  // Chest pain
  Condition('acs', 'Acute coronary syndrome', 'Síndrome coronária aguda', {
    'chest_pain': 2, 'radiation_arm_jaw': 3, 'sweating': 2, 'exertional': 2, 'nausea': 1, 'cardiac_history': 2,
    'cv_risk': 1, 'dyspnea': 1,
  }, requires: {'chest_pain', 'radiation_arm_jaw'}, against: {'palpation_pain': 2, 'pleuritic': 1}, dangerous: true),
  Condition('pe', 'Pulmonary embolism', 'Tromboembolismo pulmonar', {
    'dyspnea': 2, 'pleuritic': 2, 'hemoptysis': 2, 'leg_swelling': 2, 'one_leg': 1, 'immobility': 3, 'chest_pain': 1,
    'palpitations': 1, 'syncope': 1,
  }, requires: {'dyspnea', 'pleuritic', 'chest_pain', 'hemoptysis'}, dangerous: true),
  Condition('pericarditis', 'Pericarditis', 'Pericardite', {
    'chest_pain': 2, 'pleuritic': 2, 'leaning_relief': 4, 'fever': 1, 'runny_nose': 1, 'sore_throat': 1,
  }, requires: {'chest_pain'}, against: {'exertional': 1}),
  Condition('msk_chest', 'Musculoskeletal chest pain', 'Dor torácica musculoesquelética', {
    'chest_pain': 1, 'palpation_pain': 4,
  }, requires: {'chest_pain'}, against: {'radiation_arm_jaw': 2, 'sweating': 2, 'dyspnea': 1}),
  Condition('gord', 'Reflux (GORD)', 'Refluxo gastroesofágico', {
    'chest_pain': 1, 'heartburn': 4, 'fatty_meal': 1,
  }, requires: {'chest_pain', 'heartburn'}, against: {'exertional': 1, 'radiation_arm_jaw': 1}),
  Condition('panic', 'Panic attack', 'Ataque de pânico', {
    'palpitations': 2, 'anxiety': 3, 'tingling': 2, 'dyspnea': 1, 'chest_pain': 1, 'dizziness': 1,
  }, requires: {'palpitations', 'anxiety'}),

  // Headache
  Condition('migraine', 'Migraine', 'Enxaqueca', {
    'headache': 2, 'photophobia': 2, 'nausea': 2, 'vomiting': 1,
  }, requires: {'headache'}, against: {'fever': 2, 'worst_ever': 2, 'sudden_onset': 1, 'neck_stiffness': 2}),
  Condition('tension', 'Tension-type headache', 'Cefaleia de tensão', {
    'headache': 2, 'anxiety': 1, 'fatigue': 1,
  }, requires: {'headache'}, against: {'nausea': 1, 'photophobia': 1, 'fever': 2, 'vomiting': 1, 'worst_ever': 2}),
  Condition('sah', 'Subarachnoid haemorrhage', 'Hemorragia subaracnoideia', {
    'headache': 2, 'worst_ever': 4, 'sudden_onset': 3, 'vomiting': 1, 'neck_stiffness': 2, 'syncope': 1,
  }, requires: {'headache'}, dangerous: true),
  Condition('meningitis', 'Meningitis', 'Meningite', {
    'headache': 2, 'fever': 3, 'neck_stiffness': 3, 'photophobia': 1, 'rash': 2, 'confusion': 2, 'vomiting': 1,
  }, requires: {'headache', 'neck_stiffness', 'rash'}, dangerous: true),
  Condition('sinusitis', 'Sinusitis', 'Sinusite', {
    'headache': 1, 'runny_nose': 2, 'fever': 1,
  }, requires: {'headache', 'runny_nose'}),
  Condition('stroke', 'Stroke or TIA', 'AVC ou AIT', {
    'face_droop': 4, 'limb_weakness': 4, 'speech_difficulty': 4, 'sudden_onset': 1, 'headache': 1, 'cv_risk': 1,
  }, requires: {'face_droop', 'limb_weakness', 'speech_difficulty'}, dangerous: true),

  // Abdominal pain
  Condition('appendicitis', 'Appendicitis', 'Apendicite', {
    'abdominal_pain': 2, 'rlq_pain': 3, 'migration': 3, 'fever': 1, 'nausea': 1, 'vomiting': 1,
  }, requires: {'abdominal_pain', 'rlq_pain', 'migration'}, against: {'diarrhea': 1}, dangerous: true),
  Condition('biliary', 'Gallbladder (biliary colic or cholecystitis)', 'Vesícula (cólica biliar ou colecistite)', {
    'abdominal_pain': 2, 'ruq_pain': 3, 'fatty_meal': 2, 'fever': 1, 'nausea': 1, 'vomiting': 1,
  }, requires: {'abdominal_pain', 'ruq_pain'}),
  Condition('gastroenteritis', 'Gastroenteritis', 'Gastroenterite', {
    'abdominal_pain': 1, 'diarrhea': 3, 'vomiting': 2, 'nausea': 1, 'fever': 1,
  }, requires: {'diarrhea', 'vomiting'}),
  Condition('renal_colic', 'Kidney stone (renal colic)', 'Cólica renal', {
    'flank_pain': 3, 'blood_urine': 3, 'nausea': 1, 'vomiting': 1, 'abdominal_pain': 1,
  }, requires: {'flank_pain', 'blood_urine'}),
  Condition('uti', 'Urinary infection', 'Infeção urinária', {
    'dysuria': 3, 'frequency': 2, 'abdominal_pain': 1, 'fever': 1, 'flank_pain': 1,
  }, requires: {'dysuria', 'frequency'}),
  Condition('ectopic', 'Ectopic pregnancy', 'Gravidez ectópica', {
    'abdominal_pain': 2, 'pregnant': 4, 'syncope': 1, 'dizziness': 1,
  }, requires: {'pregnant'}, dangerous: true),
  Condition('gi_bleed', 'Upper GI bleeding', 'Hemorragia digestiva alta', {
    'hematemesis': 4, 'melena': 4, 'dizziness': 1, 'abdominal_pain': 1,
  }, requires: {'hematemesis', 'melena'}, dangerous: true),

  // Breathlessness and cough
  Condition('asthma', 'Asthma attack', 'Crise de asma', {
    'dyspnea': 2, 'wheeze': 3, 'asthma_history': 3, 'cough': 1,
  }, requires: {'wheeze', 'asthma_history'}),
  Condition('copd', 'COPD exacerbation', 'Exacerbação de DPOC', {
    'dyspnea': 2, 'copd_history': 4, 'sputum': 2, 'cough': 1, 'wheeze': 1, 'cv_risk': 1,
  }, requires: {'copd_history'}),
  Condition('pneumonia', 'Pneumonia', 'Pneumonia', {
    'cough': 2, 'fever': 2, 'sputum': 2, 'dyspnea': 1, 'pleuritic': 1, 'chills': 1,
  }, requires: {'cough'}),
  Condition('heart_failure', 'Heart failure', 'Insuficiência cardíaca', {
    'dyspnea': 2, 'orthopnea': 3, 'leg_swelling': 2, 'hf_history': 3, 'cardiac_history': 1, 'fatigue': 1,
  }, requires: {'orthopnea', 'leg_swelling', 'hf_history'}, against: {'one_leg': 2}),
  Condition('urti', 'Common cold', 'Constipação', {
    'sore_throat': 2, 'runny_nose': 3, 'cough': 1, 'fever': 1,
  }, requires: {'sore_throat', 'runny_nose'}, against: {'dyspnea': 1}),
  Condition('flu', 'Influenza', 'Gripe', {
    'fever': 3, 'myalgia': 3, 'chills': 1, 'cough': 1, 'fatigue': 1, 'headache': 1, 'sore_throat': 1,
  }, requires: {'fever', 'myalgia'}),
  Condition('anaphylaxis', 'Anaphylaxis', 'Anafilaxia', {
    'swelling_face_throat': 4, 'allergen': 3, 'rash': 1, 'wheeze': 1, 'dyspnea': 1,
  }, requires: {'swelling_face_throat'}, dangerous: true),
];

class Hypothesis {
  const Hypothesis(this.condition, this.score, this.supporting, this.against, this.askNext);
  final Condition condition;
  final int score;

  /// What the patient said that fits.
  final List<Finding> supporting;

  /// What argues against: a contradicting finding, or a typical feature the patient denied.
  final List<Finding> against;

  /// Typical features nobody has asked about yet.
  final List<Concept> askNext;

  @override
  String toString() => '${condition.id}($score)';
}

/// Ranks the conditions the findings point to. A condition is listed only
/// when its own complaint is present.
List<Hypothesis> differential(Extraction e, {int max = 5}) {
  final out = <Hypothesis>[];
  for (final c in conditions) {
    if (!c.requires.any(e.has)) continue;
    final supporting = [for (final id in c.features.keys) if (e.has(id)) e.findings[id]!];
    final contra = [
      for (final id in c.against.keys) if (e.has(id)) e.findings[id]!,
      // A strong typical feature that was explicitly denied also counts against.
      for (final MapEntry(key: id, value: w) in c.features.entries) if (w >= 2 && e.denied(id)) e.findings[id]!,
    ];
    final score = supporting.fold<int>(0, (s, f) => s + c.features[f.concept.id]!) -
        contra.fold<int>(0, (s, f) => s + (c.against[f.concept.id] ?? c.features[f.concept.id]!));
    if (score <= 0) continue;
    final ask = [
      for (final MapEntry(key: id, value: w) in c.features.entries)
        if (w >= 2 && !e.mentioned(id) && conceptsById[id]!.askPt != null) conceptsById[id]!,
    ];
    out.add(Hypothesis(c, score, supporting, contra, ask));
  }
  out.sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : (b.condition.dangerous ? 1 : 0) - (a.condition.dangerous ? 1 : 0));
  return out.take(max).toList();
}
