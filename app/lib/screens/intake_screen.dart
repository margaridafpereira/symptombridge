import 'package:flutter/material.dart';
import 'package:symptom_engine/symptom_engine.dart';

import '../session.dart';
import '../speech/speech.dart';
import '../theme.dart';
import '../clinician/access.dart';

/// Safety questions first: for each complaint, what must be ruled out.
const _screening = {
  'chest_pain': ['radiation_arm_jaw', 'sweating', 'exertional', 'dyspnea'],
  'headache': ['sudden_onset', 'worst_ever', 'neck_stiffness', 'fever'],
  'abdominal_pain': ['vomiting', 'fever', 'pregnant'],
  'dyspnea': ['at_rest', 'chest_pain', 'leg_swelling'],
  'fever': ['neck_stiffness', 'confusion', 'rash'],
  'palpitations': ['syncope', 'chest_pain'],
};

/// The question the app asks next and whether yes/no buttons fit it.
class _Question {
  const _Question(this.text, {this.concept, this.yesNo = true});
  final String text;
  final String? concept;
  final bool yesNo;
}

_Question _opening(Lang l) =>
    _Question(l.pick('Olá. O que o traz cá hoje? Conte-me com as suas palavras.', 'Hello. What brings you in today? Tell me in your own words.'),
        yesNo: false);
const _maxQuestions = 8;

/// Pre-visit interview: the patient answers a few questions by voice or by
/// typing, then sends it to the clinician. The patient never sees hypotheses.
class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key});

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  final _session = Session();
  final _speech = SpeechInput();
  final _input = TextEditingController();
  final _asked = <String>{};
  late _Question? _current = _opening(_session.lang);
  int _count = 0;
  bool _listening = false;
  bool _askedDuration = false, _askedSeverity = false;

  /// Once sent, the clinician's screen owns the session.
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    _session.add(Speaker.clinician, _current!.text);
  }

  @override
  void dispose() {
    _speech.stop();
    if (!_handedOver) _session.dispose();
    super.dispose();
  }

  void _answer(String text) {
    if (text.trim().isEmpty) return;
    _session.add(Speaker.patient, text);
    _input.clear();
    _next();
  }

  void _next() {
    final q = _count >= _maxQuestions ? null : _choose(_session.assessment.extraction, _session.assessment.hypotheses);
    setState(() {
      _current = q;
      if (q != null) {
        _count++;
        if (q.concept != null) _asked.add(q.concept!);
        _session.add(Speaker.clinician, q.text);
      }
    });
  }

  _Question? _choose(Extraction e, List<Hypothesis> hypotheses) {
    final l = _session.lang;
    bool open(String id) => !e.mentioned(id) && !_asked.contains(id) && conceptsById[id]?.ask(l) != null;
    for (final MapEntry(key: complaint, value: checks) in _screening.entries) {
      if (!e.has(complaint)) continue;
      for (final id in checks) {
        if (open(id)) return _Question(conceptsById[id]!.ask(l)!, concept: id);
      }
    }
    if (!_askedDuration && e.durations.isEmpty && e.present.isNotEmpty) {
      _askedDuration = true;
      return _Question(l.pick('Há quanto tempo começou?', 'How long ago did it start?'), yesNo: false);
    }
    final pain = e.has('chest_pain') || e.has('headache') || e.has('abdominal_pain') || e.has('flank_pain');
    if (!_askedSeverity && pain && e.severity == null) {
      _askedSeverity = true;
      return _Question(l.pick('De 0 a 10, quanto lhe dói?', 'From 0 to 10, how bad is the pain?'), yesNo: false);
    }
    for (final h in hypotheses.take(3)) {
      for (final c in h.askNext) {
        if (open(c.id)) return _Question(c.ask(l)!, concept: c.id);
      }
    }
    return null;
  }

  void _toggleMic() {
    if (_listening) {
      _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    _speech.start(
      lang: _session.lang,
      onText: (text, isFinal) {
        if (isFinal) {
          _speech.stop();
          setState(() => _listening = false);
          _answer(text);
        } else {
          _session.setInterim(Speaker.patient, text);
        }
      },
      onEnd: (error) {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  void _send() {
    _speech.stop();
    _handedOver = true;
    Inbox.instance.add(SentIntake(_session, DateTime.now()));
    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => _SentScreen(lang: _session.lang)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          final l = _session.lang;
          final emergency = _session.assessment.redFlags.any((f) => f.urgency == Urgency.emergency);
          final q = _current;
          return Scaffold(
            appBar: AppBar(title: Text(l.pick('Pré-consulta', 'Before your visit'))),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(children: [
                  if (emergency) _EmergencyBanner(lang: l),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.all(16), reverse: true, children: [
                      if (_session.interim.isNotEmpty) _Line(Speaker.patient, _session.interim, interim: true),
                      for (final t in _session.turns.reversed) _Line(t.speaker, t.text),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: const BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line))),
                    child: SafeArea(
                      top: false,
                      child: q == null
                          ? Column(children: [
                              Text(l.pick('Obrigado. O médico vai ver as suas respostas antes de o chamar.',
                                      'Thank you. The doctor will read your answers before calling you in.'),
                                  textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(icon: const Icon(Icons.send), label: Text(l.pick('Enviar ao médico', 'Send to the doctor')), onPressed: _send),
                              ),
                            ])
                          : Column(children: [
                              if (q.yesNo)
                                Row(children: [
                                  for (final (i, label, answer) in [
                                    (0, l.pick('Sim', 'Yes'), l.pick('Sim.', 'Yes.')),
                                    (1, l.pick('Não', 'No'), l.pick('Não.', 'No.')),
                                    (2, l.pick('Não sei', "Don't know"), l.pick('Não sei.', "I don't know.")),
                                  ]) ...[
                                    Expanded(
                                      child: i == 0
                                          ? FilledButton(onPressed: () => _answer(answer), child: Text(label))
                                          : OutlinedButton(onPressed: () => _answer(answer), child: Text(label)),
                                    ),
                                    if (i < 2) const SizedBox(width: 8),
                                  ],
                                ]),
                              if (q.yesNo) const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: TextField(
                                    controller: _input,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: _answer,
                                    decoration: InputDecoration(
                                      hintText: q.yesNo
                                          ? l.pick('Ou responda por palavras…', 'Or answer in your own words…')
                                          : l.pick('Escreva ou fale…', 'Type or speak…'),
                                      filled: true,
                                      fillColor: C.background,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      suffixIcon: IconButton(tooltip: l.pick('Enviar', 'Send'), icon: const Icon(Icons.send), onPressed: () => _answer(_input.text)),
                                    ),
                                  ),
                                ),
                                if (_speech.supported) ...[
                                  const SizedBox(width: 10),
                                  FloatingActionButton(
                                    heroTag: 'mic',
                                    tooltip: _listening ? l.pick('Parar', 'Stop') : l.pick('Falar', 'Speak'),
                                    backgroundColor: _listening ? C.alarm : C.primary,
                                    foregroundColor: Colors.white,
                                    onPressed: _toggleMic,
                                    child: Icon(_listening ? Icons.stop : Icons.mic),
                                  ),
                                ],
                              ]),
                              const SizedBox(height: 8),
                              TextButton(onPressed: _send, child: Text(l.pick('Terminar e enviar ao médico', 'Finish and send to the doctor'))),
                            ]),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      );
}

/// What the patient sees when a red flag fires: what to do, never why.
class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.lang});
  final Lang lang;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.alarm, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.emergency, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  lang.pick('Por favor, avise já um profissional de saúde. Se estiver em casa, ligue 112.',
                      'Please tell a healthcare professional now. If you are at home, call 112.'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.speaker, this.text, {this.interim = false});
  final Speaker speaker;
  final String text;
  final bool interim;

  @override
  Widget build(BuildContext context) {
    final app = speaker == Speaker.clinician;
    return Align(
      alignment: app ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: app ? C.surface : C.primary,
          borderRadius: BorderRadius.circular(14),
          border: app ? Border.all(color: C.line) : null,
        ),
        child: Text(text,
            style: TextStyle(
              color: app ? C.text : Colors.white.withValues(alpha: interim ? 0.7 : 1),
              fontSize: 15,
              fontStyle: interim ? FontStyle.italic : null,
            )),
      ),
    );
  }
}

/// After sending: what the patient sees. Nothing clinical.
class _SentScreen extends StatelessWidget {
  const _SentScreen({required this.lang});
  final Lang lang;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(lang.pick('Enviado', 'Sent'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle, color: C.primary, size: 64),
              const SizedBox(height: 16),
              Text(lang.pick('As suas respostas foram enviadas ao médico.', 'Your answers have been sent to the doctor.'),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  lang.pick('Aguarde que o chamem. Se se sentir pior, avise já um profissional.',
                      'Please wait to be called. If you feel worse, tell a professional straight away.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: Text(lang.pick('Voltar ao início', 'Back to the start')),
              ),
            ]),
          ),
        ),
      );
}
