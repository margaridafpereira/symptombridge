/// English phrases for every concept, as regular expressions on lower-case
/// text. Kept apart from the Portuguese ones in concepts.dart so each
/// language can be read and tested on its own. "can.?t" matches can't, cant
/// and can’t, which keeps apostrophes out of the patterns.
const englishPhrases = <String, List<String>>{
  // Chest
  'chest_pain': [
    r'chest (pain|tightness|pressure|discomfort|heaviness)', r'(pain|tightness|pressure|heaviness|ache) in (my|his|her|the) chest',
    r'chest (hurts|is (hurting|tight|sore|aching))', r'(tight|heavy|sore) chest',
  ],
  'radiation_arm_jaw': [
    r'(spread|radiat|go|goes|going|went|mov|shoot)\w* (in)?to (my |his |her |the )?(left )?(arm|jaw|neck|shoulder)',
    r'down (my|his|her|the) (left )?arm', r'(pain|ache) in (my|his|her|the) left arm',
  ],
  'sweating': [r'\bsweat(s|y|ing|ed)?\b', r'clammy', r'perspir\w*'],
  'exertional': [
    r'(when|while) (i |he |she )?(walk|climb|run|exercis|go up|do anything)\w*', r'(on|with) (exertion|effort)',
    r'(up|climbing) (the )?stairs',
  ],
  'pleuritic': [
    r'hurts? (more )?(when|if) (i |he |she )?(breathe|breathing|take a deep breath|cough)',
    r'(pain|worse) (on|when) breathing (in|deeply)', r'deep breaths? hurts?', r'worse when (i )?breathe in',
  ],
  'leaning_relief': [r'(better|eases|easier|relieved)\w* .{0,25}(lean\w* forward|sit\w* forward)'],
  'palpation_pain': [r'hurts? (more )?(when|if) (i |you )?(press|touch|push)\w*', r'tender to (the )?touch', r'sore when (i )?press'],
  'heartburn': [r'heartburn', r'acid (reflux|taste)', r'reflux', r'burning (in|behind) (my |the )?(chest|stomach)', r'sour taste'],
  'palpitations': [
    r'palpitation\w*', r'heart (is |was )?(racing|pounding|fluttering|skipping|beating (really |very )?(fast|hard))',
    r'(racing|pounding) heart',
  ],
  'syncope': [r'\bfaint(ed|ing)?\b', r'passed out', r'blacked out', r'lost consciousness', r'\bcollapsed'],
  'dizziness': [r'dizz\w*', r'light-?headed\w*', r'vertigo', r'(room|everything) (is )?spinning'],
  'anxiety': [r'anxi\w*', r'stress\w*', r'panic\w*', r'nervous'],
  'tingling': [
    r'(tingling|pins and needles) (in (my |the )?(hands|fingers)|around (my |the )?mouth)', r'(hands|fingers) .{0,10}tingl\w*',
  ],

  // Neuro
  'headache': [r'head ?aches?', r'(my |his |her )?head (hurts|is (hurting|pounding|splitting))', r'pain in (my|his|her|the) head'],
  'sudden_onset': [r'(all of a )?sudden(ly)?', r'out of (the )?nowhere', r'came on (in seconds|instantly|at once)', r'in an instant'],
  'worst_ever': [
    r'worst (pain|headache) .{0,20}(life|ever)', r'never (had|felt) (a )?(pain|headache) like', r'like (being hit|a thunderclap|an explosion)',
  ],
  'neck_stiffness': [r'(stiff|rigid) neck', r'neck (is )?(stiff|rigid)', r'can.?t (bend|move) (my |his |her )?neck', r'neck stiffness'],
  'photophobia': [
    r'photophobia', r'light (hurts|bothers|is too bright)', r'can.?t (stand|bear) (the )?light', r'(sensitive|sensitivity) to light',
  ],
  'face_droop': [
    r'(face|mouth|smile) (is |has )?(droop\w*|lopsided|crooked|twisted|fallen|dropped)', r'droop\w* (face|mouth)',
    r'(one side|half) of (his|her|my|the) face',
  ],
  'limb_weakness': [
    r'(arm|leg|hand) .{0,20}(weak|numb|no strength|heavy|can.?t (move|lift)|won.?t move)',
    r'can.?t (lift|raise|move) (his|her|my|the) (arm|leg|hand)', r'lost (the |all )?strength',
  ],
  'speech_difficulty': [
    r'(speech|words|talking) .{0,15}(slurr\w*|garbled|strange|jumbled|muddled)', r'slurr\w* (his |her |my )?(speech|words)',
    r'(trouble|difficulty) (speaking|talking|finding (the )?words)', r'can.?t (speak|talk) (properly|clearly|right)',
  ],
  'confusion': [r'confus\w*', r'disorient\w*', r'(doesn|don).?t know where (he|she|i) (is|am)', r'(very )?drowsy'],

  // Breathing
  'dyspnea': [
    r'short(ness)? of breath', r'breathless\w*', r'can.?t (catch|get) (my |his |her )?breath',
    r'(trouble|difficulty|struggling) (breathing|to breathe)', r'out of breath', r'hard to breathe',
  ],
  'at_rest': [r'at rest', r'even (when|while) (i.?m )?(sitting|resting|lying|doing nothing)', r'doing nothing'],
  'cannot_finish_sentences': [r'can.?t (finish|complete) (my |a )?sentences?', r'too breathless to (speak|talk)'],
  'wheeze': [r'wheez\w*', r'whistl\w* (when|in) (i breathe|my chest)', r'chest (is )?whistling'],
  'orthopnea': [
    r'can.?t (lie|sleep) (flat|down)', r'(sleep|sleeping) (on|with) (two|three|several|more|extra) pillows',
    r'wake (up )?(gasping|breathless|short of breath)',
  ],
  'cough': [r'\bcough\w*'],
  'sputum': [r'phlegm', r'sputum', r'mucus', r'coughing up (green|yellow)'],
  'hemoptysis': [r'cough\w* (up )?(some )?blood', r'blood in (my |the )?(phlegm|sputum|spit)'],
  'sore_throat': [r'sore throat', r'throat (is )?(sore|hurts|scratchy|painful)'],
  'runny_nose': [r'(runny|blocked|stuffy|bunged up) nose', r'nose (is )?(running|blocked|stuffed)', r'(caught|got|have) a (bad )?cold', r'sneez\w*'],
  'swelling_face_throat': [r'(lips|tongue|throat|face) .{0,15}(swollen|swelling|closing)', r'swollen (lips|tongue|face)'],
  'allergen': [r'\bstung\b', r'\bbitten\b', r'after (eating )?(prawns|shellfish|peanuts|nuts)', r'allerg\w*'],

  // General
  'fever': [r'fever\w*', r'(a|high|raised) temperature', r'running a temp'],
  'chills': [r'\bchills\b', r'shiver\w*', r'\brigou?rs\b'],
  'myalgia': [r'(aching|aches) (all over|everywhere)', r'muscle (aches|pains?)', r'body aches', r'ache all over'],
  'fatigue': [r'\btired\w*', r'exhaust\w*', r'fatigue\w*', r'worn out'],
  'rash': [r'\brash', r'(red|purple) (spots|blotches|marks)', r'spots on (my|his|her) skin'],
  'leg_swelling': [
    r'(legs?|ankles?|feet|calf) .{0,15}(swollen|swelling|puffy)', r'swollen (legs?|ankles?|feet|calf)',
    r'swelling (in|of) (my |his |her |the )?(legs?|ankles?|feet|calf)',
  ],
  'one_leg': [r'(only )?(one leg|(the|my|his|her) (left|right) (leg|calf))'],
  'immobility': [
    r'long[- ]haul flight', r'(long|\d+[- ]hour) (flight|trip|drive|journey)', r'bed ?bound', r'bed rest',
    r'(had|recent|after) (an |my )?(operation|surgery)', r'\bin a (cast|plaster)',
  ],

  // Abdomen
  'abdominal_pain': [
    r'(stomach|tummy|belly|abdominal) (pain|ache|cramps?)', r'(stomach|tummy|belly) ?ache', r'(stomach|tummy|belly) (hurts|is (hurting|sore))',
    r'pain .{0,15}(in|around) (my |the )?(stomach|tummy|belly|abdomen|navel|belly button)',
  ],
  'rlq_pain': [r'(lower right|bottom right|right lower)', r'(low|down) on the right', r'right side,? low down'],
  'migration': [
    r'start\w* .{0,30}(belly button|navel|middle) .{0,40}(moved|went|shifted|now)', r'(belly button|navel) .{0,30}(then|now) .{0,20}right',
  ],
  'ruq_pain': [r'under (my |the )?(right )?ribs', r'(upper right|right upper|top right)'],
  'fatty_meal': [r'after (eating )?(a )?((fatty|greasy|fried|heavy|big) ){1,2}(meal|food|dinner|lunch)', r'after (a )?(takeaway|fry-up)'],
  'flank_pain': [r'(pain|hurts|ache) .{0,40}(kidney|loin|side of (my|the) back|flank)', r'renal colic'],
  'blood_urine': [r'blood in (my |the )?(urine|pee|wee)', r'(urine|pee|wee) .{0,10}(red|bloody|pink|cola)'],
  'dysuria': [r'(burns|burning|stings|stinging|hurts|pain) (when|while) (i )?(pee|wee|urinat)\w*', r'painful (urination|to pee)'],
  'frequency': [
    r'(peeing|weeing|urinating|going to the (toilet|loo|bathroom)) .{0,15}(all the time|a lot|constantly|every hour|often)',
    r'(need|needing) to (pee|wee|go) (all the time|constantly)',
  ],
  'nausea': [r'nause\w*', r'(feel|feeling|felt) sick', r'queasy', r'want to (be sick|throw up)'],
  'vomiting': [r'(?<!want to )(vomit(ed|ing|s)?\b|threw up|throwing up|been sick|being sick|was sick)'],
  'diarrhea': [r'diarrh\w*', r'(loose|watery|runny) (stools|poo|bowels)', r'the runs'],
  'melena': [r'(black|tarry) (stools|poo|motions)', r'(stools|poo) (is |are )?(black|tarry)'],
  'hematemesis': [r'(vomit\w*|threw up|throwing up|sick) .{0,10}blood', r'blood in (the|my) (vomit|sick)'],
  'rigid_abdomen': [r'(stomach|belly|tummy|abdomen) (is |feels )?(hard|rigid|like a board)'],
  'pregnant': [r'pregnan\w*', r'period (is )?(late|overdue)', r'missed (my |a )?period'],

  // Mental health
  'suicidal': [
    r'kill (myself|himself|herself)', r'suicid\w*', r'end (it all|my life)', r'(don.?t|do not) want to (live|be alive)',
    r'take my (own )?life',
  ],

  // History
  'cardiac_history': [r'heart attack', r'angina', r'\bstent', r'bypass', r'heart (disease|condition|problem)'],
  'cv_risk': [r'\bsmok(e|er|es|ing)\b', r'high blood pressure', r'hypertens\w*', r'diabet\w*', r'cholesterol'],
  'asthma_history': [r'asthma\w*', r'inhaler'],
  'copd_history': [r'\bcopd\b', r'emphysema', r'chronic bronchitis'],
  'hf_history': [r'heart failure', r'weak heart'],
};
