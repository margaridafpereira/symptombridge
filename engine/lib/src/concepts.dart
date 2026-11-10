/// What a patient can tell us: symptoms, modifiers (how it started, what
/// makes it worse) and history. Phrases are European Portuguese regular
/// expressions, matched on lower-case text with accents removed.
enum Kind { symptom, modifier, history }

class Concept {
  const Concept(
    this.id,
    this.en,
    this.pt,
    this.phrases, {
    this.kind = Kind.symptom,
    this.snomed,
    this.askEn,
    this.askPt,
    this.negationInside = false,
  });

  final String id;
  final String en;
  final String pt;

  /// Regular expressions, without accents, lower case.
  final List<String> phrases;
  final Kind kind;

  /// SNOMED CT concept id, only where certain; null otherwise.
  final String? snomed;

  /// The question a clinician would ask to check it.
  final String? askEn;
  final String? askPt;

  /// The phrase itself contains a negation ("não consigo falar"), so a "não"
  /// in it must not flip the finding.
  final bool negationInside;
}

const concepts = <Concept>[
  // Chest
  Concept('chest_pain', 'Chest pain', 'Dor no peito', [
    r'dor (no|do|ao|em) peito', r'(aperto|pressao|peso) (no|ao|do) peito', r'dor toracica',
    r'peito .{0,15}(doi|a doer|aperta)', r'doi(-me|-lhe)? (o|no) peito',
  ], snomed: '29857009', askEn: 'Any chest pain?', askPt: 'Tem dor no peito?'),
  Concept('radiation_arm_jaw', 'Pain spreading to arm, jaw or neck', 'Dor que irradia para o braço, maxilar ou pescoço', [
    r'(espalha|irradia|vai|passa|desce|sobe)\w* (para|pel[oa]|ate) (o |a )?(braco|maxilar|queixo|mandibula|pescoco|ombro)',
    r'dor (no|do) braco esquerdo',
  ], kind: Kind.modifier, askEn: 'Does the pain spread to the arm, jaw or neck?', askPt: 'A dor vai para o braço, maxilar ou pescoço?'),
  Concept('sweating', 'Sweating', 'Suores', [
    r'suor(es)?( frios?)?', r'(a |estou a |comecei a |fiquei a )suar', r'transpir\w*', r'suad[oa]',
  ], askEn: 'Any sweating?', askPt: 'Tem suores?'),
  Concept('exertional', 'Worse on exertion', 'Piora com o esforço', [
    r'(quando|ao|a|com o) (subir|andar|caminhar|correr|fazer esforco)', r'esforco', r'(subo|subir) (as )?escadas',
  ], kind: Kind.modifier, askEn: 'Does it come on with effort, like stairs?', askPt: 'Aparece com o esforço, como subir escadas?'),
  Concept('pleuritic', 'Worse on breathing in', 'Piora ao respirar fundo', [
    r'doi (mais )?(ao|quando|se) (respir|inspir|tossir|tusso)\w*', r'dor ao respirar fundo', r'(respirar|inspirar) fundo doi',
  ], kind: Kind.modifier, askEn: 'Is it worse when you breathe in deeply?', askPt: 'Piora quando respira fundo?'),
  Concept('leaning_relief', 'Better leaning forward', 'Alivia inclinado para a frente', [
    r'(melhora|alivia|passa)\w* .{0,20}(inclin\w*|sentad\w* para a frente|para a frente)',
  ], kind: Kind.modifier, askEn: 'Is it better leaning forward?', askPt: 'Alivia quando se inclina para a frente?'),
  Concept('palpation_pain', 'Hurts when pressed', 'Dói ao carregar', [
    r'doi (mais )?(quando|ao|se) (carrego|toco|aperto|carregar|tocar|apertar|carregam)',
  ], kind: Kind.modifier, askEn: 'Does it hurt when you press on it?', askPt: 'Dói quando carrega no sítio?'),
  Concept('heartburn', 'Heartburn', 'Azia', [
    r'azia', r'queimor', r'ardor (no estomago|no peito)', r'sabor (acido|amargo)', r'refluxo',
  ], askEn: 'Any heartburn or acid taste?', askPt: 'Tem azia ou sabor ácido na boca?'),
  Concept('palpitations', 'Palpitations', 'Palpitações', [
    r'palpitac\w*', r'coracao (aos saltos|acelerado|a bater (muito )?(rapido|forte|depressa)|a disparar|dispar\w*)',
  ], snomed: '80313002', askEn: 'Any palpitations?', askPt: 'Sente o coração acelerado?'),
  Concept('syncope', 'Fainting', 'Desmaio', [
    r'desmai\w*', r'perdi (os )?sentidos', r'perdi a consciencia', r'apaguei',
  ], snomed: '271594007', askEn: 'Did you faint?', askPt: 'Chegou a desmaiar?'),
  Concept('dizziness', 'Dizziness', 'Tonturas', [r'tontur\w*', r'tont[oa]', r'vertigem'],
      snomed: '404640003', askEn: 'Any dizziness?', askPt: 'Tem tonturas?'),
  Concept('anxiety', 'Anxiety or stress', 'Ansiedade ou stress', [
    r'ansios\w*', r'ansiedade', r'nervos', r'stress', r'(ataque|crise) de (panico|ansiedade)', r'panico',
  ], kind: Kind.modifier),
  Concept('tingling', 'Tingling in hands or around the mouth', 'Formigueiro nas mãos ou à volta da boca', [
    r'formigueiro (nas maos|nos dedos|a volta da boca|na boca)', r'(maos|dedos) .{0,10}formig\w*',
  ]),

  // Neuro
  Concept('headache', 'Headache', 'Dor de cabeça', [
    r'dor(es)? de cabeca', r'cefaleia', r'cabeca .{0,12}(doi|a doer|a estalar|estala)',
  ], snomed: '25064002', askEn: 'Any headache?', askPt: 'Tem dor de cabeça?'),
  Concept('sudden_onset', 'Sudden onset', 'Início súbito', [
    r'de repente', r'subit\w*', r'repentin\w*', r'(do nada|num instante|de um momento para o outro)',
  ], kind: Kind.modifier, askEn: 'Did it start suddenly, within seconds?', askPt: 'Começou de repente, em segundos?'),
  Concept('worst_ever', 'Worst pain of their life', 'A pior dor da vida', [
    r'pior dor .{0,25}vida', r'nunca (tive|senti) uma dor (assim|destas|igual)', r'como (uma )?(pancada|martelada|explosao)',
  ], kind: Kind.modifier, negationInside: true, askEn: 'Is it the worst headache of your life?', askPt: 'É a pior dor de cabeça da sua vida?'),
  Concept('neck_stiffness', 'Stiff neck', 'Pescoço rígido', [
    r'pescoco (rigido|preso|duro|tenso)', r'rigidez (do|no|de) pescoco', r'nao consigo (dobrar|baixar|mexer) o pescoco',
  ], snomed: '161882006', negationInside: true, askEn: 'Can you bend your neck forward?', askPt: 'Consegue dobrar o pescoço para a frente?'),
  Concept('photophobia', 'Light hurts', 'A luz incomoda', [
    r'fotofobia', r'(a )?luz (me )?(incomoda|faz doer|irrita|faz mal)', r'incomoda(-me)? a luz', r'nao suporto a luz',
  ], snomed: '409668002', negationInside: true, askEn: 'Does light bother you?', askPt: 'A luz incomoda-o?'),
  Concept('face_droop', 'Face drooping', 'Face descaída', [
    r'boca (torta|ao lado|descaida|de lado)', r'cara (torta|descaida)', r'(lado|metade) da cara (descaid\w*|dormente|parad\w*)',
  ], askEn: 'Any drooping of the face?', askPt: 'Notou a cara ou a boca descaída?'),
  Concept('limb_weakness', 'Weakness in an arm or leg', 'Fraqueza num braço ou perna', [
    r'(braco|perna|mao) .{0,20}(sem forca|fraco|fraca|dormente|nao (mexe|consigo mexer))', r'perdi (a )?forca',
  ], negationInside: true, askEn: 'Any weakness in an arm or leg?', askPt: 'Tem falta de força num braço ou perna?'),
  Concept('speech_difficulty', 'Trouble speaking', 'Dificuldade em falar', [
    r'(fala|falar|palavras) .{0,15}(enrolad\w*|arrastad\w*|dificuldade|estranh\w*|trocad\w*)', r'nao consigo (encontrar as palavras|falar bem)',
  ], snomed: '8011004', negationInside: true, askEn: 'Any trouble speaking?', askPt: 'Tem dificuldade em falar?'),
  Concept('confusion', 'Confusion', 'Confusão', [
    r'confus[oa]', r'desorientad\w*', r'nao (sabe|sei) onde (esta|estou)', r'(muito )?sonolent\w*',
  ], negationInside: true, askEn: 'Any confusion or drowsiness?', askPt: 'Tem estado confuso ou sonolento?'),

  // Breathing
  Concept('dyspnea', 'Shortness of breath', 'Falta de ar', [
    r'falta de ar', r'falta-me o ar', r'dificuldade (em|a) respirar', r'custa(-me)? (a )?respirar', r'respiracao (dificil|curta|ofegante)',
    r'ar nao chega',
  ], snomed: '267036007', askEn: 'Any shortness of breath?', askPt: 'Tem falta de ar?'),
  Concept('at_rest', 'Even at rest', 'Mesmo em repouso', [
    r'em repouso', r'mesmo (parad[oa]|sentad[oa]|deitad[oa])', r'sem fazer nada',
  ], kind: Kind.modifier, askEn: 'Are you short of breath even at rest?', askPt: 'Tem falta de ar mesmo parado?'),
  Concept('cannot_finish_sentences', "Can't finish sentences", 'Não consegue acabar frases', [
    r'nao consigo (terminar|acabar) (as )?frases', r'nao consigo falar (de|com) (tanta )?falta de ar',
  ], negationInside: true),
  Concept('wheeze', 'Wheezing', 'Pieira', [r'pieira', r'chiadeira', r'(peito|respiracao) a chiar', r'assobi\w*'],
      snomed: '56018004', askEn: 'Any wheezing?', askPt: 'Ouve um chiar a respirar?'),
  Concept('orthopnea', 'Breathless lying flat', 'Falta de ar deitado', [
    r'(nao consigo|custa(-me)?) (estar |ficar )?deitad\w*', r'(dormir|durmo) com (varias|mais|duas|tres) almofadas', r'acordo (sem ar|com falta de ar)',
  ], negationInside: true, askEn: 'Are you breathless lying flat?', askPt: 'Tem falta de ar quando se deita?'),
  Concept('cough', 'Cough', 'Tosse', [r'\btosse', r'\btossir', r'\btusso'], snomed: '49727002', askEn: 'Any cough?', askPt: 'Tem tosse?'),
  Concept('sputum', 'Phlegm', 'Expetoração', [r'expetora\w*', r'catarro', r'escarr\w*', r'fleuma'],
      askEn: 'Are you coughing up phlegm?', askPt: 'Tem expetoração?'),
  Concept('hemoptysis', 'Coughing up blood', 'Tosse com sangue', [
    r'(tosse|tossir|tusso|expetora\w*|catarro|escarr\w*) .{0,20}sangue', r'sangue (na|no) (tosse|catarro|expetoracao)',
  ], snomed: '66857006', askEn: 'Any blood when you cough?', askPt: 'Já tossiu sangue?'),
  Concept('sore_throat', 'Sore throat', 'Dor de garganta', [r'dor de garganta', r'garganta .{0,10}(doi|inflamada|irritada|a doer)'],
      snomed: '162397003', askEn: 'Any sore throat?', askPt: 'Dói-lhe a garganta?'),
  Concept('runny_nose', 'Runny or blocked nose', 'Nariz entupido ou a pingar', [
    r'nariz (entupido|a pingar|a escorrer)', r'corrimento nasal', r'constipad\w*', r'ranho',
  ], askEn: 'Runny or blocked nose?', askPt: 'Tem o nariz entupido ou a pingar?'),
  Concept('swelling_face_throat', 'Swelling of lips, tongue or throat', 'Inchaço dos lábios, língua ou garganta', [
    r'(labios|lingua|garganta|cara) .{0,15}(inchad\w*|a inchar|a fechar)', r'garganta a fechar',
  ], askEn: 'Any swelling of lips, tongue or throat?', askPt: 'Tem os lábios, a língua ou a garganta inchados?'),
  Concept('allergen', 'Possible allergen exposure', 'Possível contacto com alergénio', [
    r'picad[oa]', r'picada', r'depois de comer (marisco|amendoins?|frutos secos)', r'alergi\w*',
  ], kind: Kind.modifier),

  // General
  Concept('fever', 'Fever', 'Febre', [r'febre', r'temperatura (alta|elevada)', r'febril'],
      snomed: '386661006', askEn: 'Any fever?', askPt: 'Tem febre?'),
  Concept('chills', 'Chills', 'Arrepios', [r'arrepio\w*', r'calafrio\w*'], snomed: '43724002', askEn: 'Any chills?', askPt: 'Tem arrepios?'),
  Concept('myalgia', 'Aching muscles', 'Dores no corpo', [r'dores (no corpo|musculares|nos musculos)', r'corpo (todo )?(dorido|a doer|moido)'],
      askEn: 'Aching all over?', askPt: 'Tem dores no corpo?'),
  Concept('fatigue', 'Tiredness', 'Cansaço', [r'cansad\w*', r'cansaco', r'fadiga', r'exaust\w*'], snomed: '84229001'),
  Concept('rash', 'Rash', 'Manchas na pele', [r'manchas (na pele|vermelh\w*|roxa\w*)', r'erupcao', r'pintas (vermelh\w*|roxa\w*)'],
      snomed: '271807003', askEn: 'Any rash?', askPt: 'Tem manchas na pele?'),
  Concept('leg_swelling', 'Swollen leg', 'Perna inchada', [
    r'(pernas?|tornozelos?|pes|barriga da perna) .{0,15}(inchad\w*|inchaco)', r'inchaco (na|nas|da|dos) (pern\w*|tornozel\w*|pes)',
  ], askEn: 'Any swelling in the legs?', askPt: 'Tem as pernas inchadas?'),
  Concept('one_leg', 'One leg only', 'Só uma perna', [r'(so |apenas )?(uma perna|na perna (esquerda|direita)|perna (esquerda|direita))'],
      kind: Kind.modifier),
  Concept('immobility', 'Recent travel, surgery or bed rest', 'Viagem longa, cirurgia ou acamado recente', [
    r'viagem (longa|de avia|de muitas horas)', r'voo (longo|de \d+ horas)', r'acamad\w*', r'(fui )?operad[oa]', r'cirurgia', r'\bgesso',
  ], kind: Kind.history, askEn: 'Any recent long trip, surgery or bed rest?', askPt: 'Fez alguma viagem longa, cirurgia ou esteve acamado?'),

  // Abdomen
  Concept('abdominal_pain', 'Abdominal pain', 'Dor abdominal', [
    r'dor(es)? (de|na) barriga', r'dor(es)? (no|de) estomago', r'dor abdominal', r'barriga .{0,10}(doi|a doer)',
    r'dor (no|do) (lado direito|lado esquerdo) da barriga', r'doi(-me|-lhe)? a barriga', r'dor (a volta|perto) do umbigo',
  ], snomed: '21522001', askEn: 'Any tummy pain?', askPt: 'Tem dor de barriga?'),
  Concept('rlq_pain', 'Pain low on the right', 'Dor em baixo à direita', [
    r'(lado direito|direita)[ ,].{0,25}(em baixo|parte de baixo|fundo da barriga)', r'em baixo (a|do lado) direit\w*', r'fossa iliaca direita',
  ], kind: Kind.modifier, askEn: 'Is the pain low on the right side?', askPt: 'A dor é em baixo, do lado direito?'),
  Concept('migration', 'Pain moved from the navel', 'A dor começou no umbigo e mudou de sítio', [
    r'comec\w* .{0,30}umbigo .{0,40}(passou|mudou|foi|desceu)', r'umbigo .{0,30}(depois|agora) .{0,20}(direita|lado direito)',
  ], kind: Kind.modifier, askEn: 'Did it start around the navel and then move?', askPt: 'Começou à volta do umbigo e depois mudou de sítio?'),
  Concept('ruq_pain', 'Pain under the right ribs', 'Dor debaixo das costelas à direita', [
    r'debaixo das costelas', r'(lado direito em cima|em cima do lado direito|em cima a direita)',
  ], kind: Kind.modifier, askEn: 'Is the pain under the right ribs?', askPt: 'A dor é debaixo das costelas, do lado direito?'),
  Concept('fatty_meal', 'After a fatty meal', 'Depois de uma refeição gordurosa', [
    r'(depois|apos) (de )?(comer|uma refeicao|o jantar|o almoco) .{0,25}(gordur\w*|frit\w*|pesad\w*)', r'depois de (fritos|comida gordurosa)',
  ], kind: Kind.modifier, askEn: 'Did it start after a fatty meal?', askPt: 'Começou depois de uma refeição gordurosa?'),
  Concept('flank_pain', 'Pain in the side of the back', 'Dor nas costas, de lado', [
    r'(dor|doi) .{0,40}(rins|rim|lado das costas|costas de lado|zona lombar de um lado)', r'colica renal',
  ], askEn: 'Is the pain in the side of the back?', askPt: 'A dor é nas costas, de um lado?'),
  Concept('blood_urine', 'Blood in urine', 'Sangue na urina', [r'sangue na urina', r'urina .{0,10}(com sangue|vermelha|cor de coca)'],
      askEn: 'Any blood in your urine?', askPt: 'Viu sangue na urina?'),
  Concept('dysuria', 'Pain on passing urine', 'Dor ao urinar', [r'(arde|ardor|dor|doi) (a|ao|quando) urin\w*', r'custa(-me)? (a )?urinar'],
      snomed: '49650001', askEn: 'Does it burn when you pass urine?', askPt: 'Arde quando urina?'),
  Concept('frequency', 'Passing urine often', 'Urinar muitas vezes', [
    r'(urinar|fazer chichi|(vou|ido|ir) a casa de banho) .{0,15}(muitas vezes|toda a hora|a toda a hora|de hora a hora)', r'vontade constante de urinar',
  ], askEn: 'Are you passing urine more often?', askPt: 'Tem urinado muitas vezes?'),
  Concept('nausea', 'Nausea', 'Náuseas', [r'nause\w*', r'enjo\w*', r'agoniad\w*', r'vontade de vomitar'],
      snomed: '422587007', askEn: 'Any nausea?', askPt: 'Tem náuseas?'),
  Concept('vomiting', 'Vomiting', 'Vómitos', [r'(?<!vontade de )vomit(ei|o|ar|os|ado|ando|ou|ei)\b'],
      snomed: '422400008', askEn: 'Any vomiting?', askPt: 'Tem vomitado?'),
  Concept('diarrhea', 'Diarrhoea', 'Diarreia', [r'diarreia', r'(fezes|coco) (liquid\w*|mole\w*)', r'solt[oa] dos intestinos'],
      snomed: '62315008', askEn: 'Any diarrhoea?', askPt: 'Tem diarreia?'),
  Concept('melena', 'Black stools', 'Fezes pretas', [r'(fezes|coco) (pretas?|negras?|escuras?|cor de alcatrao)'],
      snomed: '2901004', askEn: 'Any black stools?', askPt: 'As fezes estão pretas?'),
  Concept('hematemesis', 'Vomiting blood', 'Vómito com sangue', [r'vomit\w* .{0,10}sangue', r'sangue no vomito'],
      snomed: '8765009', askEn: 'Any blood in the vomit?', askPt: 'Vomitou sangue?'),
  Concept('rigid_abdomen', 'Rigid abdomen', 'Barriga rígida', [r'barriga (dura|rigida|como uma tabua)'], kind: Kind.modifier),
  Concept('pregnant', 'Possibly pregnant', 'Possível gravidez', [
    r'gravid\w*', r'periodo atrasado', r'atraso (na|da) menstruac\w*', r'falta(-me)? o periodo',
  ], kind: Kind.history, askEn: 'Could you be pregnant?', askPt: 'Pode estar grávida?'),

  // Mental health
  Concept('suicidal', 'Thoughts of suicide', 'Pensamentos suicidas', [
    r'matar-me', r'suicid\w*', r'acabar com (a minha vida|tudo)', r'nao quero (mais )?viver', r'tirar a (minha )?(propria )?vida',
  ], negationInside: true),

  // History
  Concept('cardiac_history', 'Heart disease', 'Doença cardíaca', [
    r'enfarte', r'angina', r'stent', r'cateterismo', r'bypass', r'doenca (do coracao|cardiaca)',
  ], kind: Kind.history, askEn: 'Any heart disease before?', askPt: 'Tem alguma doença do coração?'),
  Concept('cv_risk', 'Cardiovascular risk factors', 'Fatores de risco cardiovascular', [
    r'fum(ador|adora|o)\b', r'tensao alta', r'hipertens\w*', r'diabet\w*', r'colesterol',
  ], kind: Kind.history, askEn: 'Do you smoke, or have diabetes, high blood pressure or cholesterol?', askPt: 'Fuma, ou tem diabetes, tensão alta ou colesterol?'),
  Concept('asthma_history', 'Asthma', 'Asma', [r'\basma', r'asmatic\w*', r'bombinha', r'inalador'], kind: Kind.history,
      askEn: 'Do you have asthma?', askPt: 'Tem asma?'),
  Concept('copd_history', 'COPD', 'DPOC', [r'\bdpoc\b', r'enfisema', r'bronquite cronica'], kind: Kind.history,
      askEn: 'Do you have COPD?', askPt: 'Tem DPOC?'),
  Concept('hf_history', 'Heart failure', 'Insuficiência cardíaca', [r'insuficiencia cardiaca', r'coracao (fraco|cansado)'],
      kind: Kind.history, askEn: 'Have you been told your heart is weak?', askPt: 'Já lhe disseram que tem insuficiência cardíaca?'),
];

final conceptsById = {for (final c in concepts) c.id: c};
