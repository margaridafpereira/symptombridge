import 'package:flutter/material.dart';
import 'package:symptom_engine/symptom_engine.dart';

import '../session.dart';
import '../speech/speech.dart';
import '../theme.dart';
import 'consult_screen.dart';

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

const _opening = _Question('Olá. O que o traz cá hoje? Conte-me com as suas palavras.', yesNo: false);
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
  _Question? _current = _opening;
  int _count = 0;
  bool _listening = false;
  bool _askedDuration = false, _askedSeverity = false;

  /// Once sent, the clinician's screen owns the session.
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    _session.add(Speaker.clinician, _opening.text);
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
    bool open(String id) => !e.mentioned(id) && !_asked.contains(id) && conceptsById[id]?.askPt != null;
    for (final MapEntry(key: complaint, value: checks) in _screening.entries) {
      if (!e.has(complaint)) continue;
      for (final id in checks) {
        if (open(id)) return _Question(conceptsById[id]!.askPt!, concept: id);
      }
    }
    if (!_askedDuration && e.durations.isEmpty && e.present.isNotEmpty) {
      _askedDuration = true;
      return const _Question('Há quanto tempo começou?', yesNo: false);
    }
    final pain = e.has('chest_pain') || e.has('headache') || e.has('abdominal_pain') || e.has('flank_pain');
    if (!_askedSeverity && pain && e.severity == null) {
      _askedSeverity = true;
      return const _Question('De 0 a 10, quanto lhe dói?', yesNo: false);
    }
    for (final h in hypotheses.take(3)) {
      for (final c in h.askNext) {
        if (open(c.id)) return _Question(c.askPt!, concept: c.id);
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
    _handedOver = true;
    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => _SentScreen(session: _session)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          final emergency = _session.assessment.redFlags.any((f) => f.urgency == Urgency.emergency);
          final q = _current;
          return Scaffold(
            appBar: AppBar(title: const Text('Pré-consulta')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(children: [
                  if (emergency) const _EmergencyBanner(),
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
                              const Text('Obrigado. O médico vai ver as suas respostas antes de o chamar.',
                                  textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(icon: const Icon(Icons.send), label: const Text('Enviar ao médico'), onPressed: _send),
                              ),
                            ])
                          : Column(children: [
                              if (q.yesNo)
                                Row(children: [
                                  for (final (label, answer) in const [('Sim', 'Sim.'), ('Não', 'Não.'), ('Não sei', 'Não sei.')]) ...[
                                    Expanded(
                                      child: label == 'Sim'
                                          ? FilledButton(onPressed: () => _answer(answer), child: Text(label))
                                          : OutlinedButton(onPressed: () => _answer(answer), child: Text(label)),
                                    ),
                                    if (label != 'Não sei') const SizedBox(width: 8),
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
                                      hintText: q.yesNo ? 'Ou responda por palavras…' : 'Escreva ou fale…',
                                      filled: true,
                                      fillColor: C.background,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      suffixIcon: IconButton(tooltip: 'Enviar', icon: const Icon(Icons.send), onPressed: () => _answer(_input.text)),
                                    ),
                                  ),
                                ),
                                if (_speech.supported) ...[
                                  const SizedBox(width: 10),
                                  FloatingActionButton(
                                    heroTag: 'mic',
                                    tooltip: _listening ? 'Parar' : 'Falar',
                                    backgroundColor: _listening ? C.alarm : C.primary,
                                    foregroundColor: Colors.white,
                                    onPressed: _toggleMic,
                                    child: Icon(_listening ? Icons.stop : Icons.mic),
                                  ),
                                ],
                              ]),
                              const SizedBox(height: 8),
                              TextButton(onPressed: _send, child: const Text('Terminar e enviar ao médico')),
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
  const _EmergencyBanner();

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.alarm, borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.emergency, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text('Por favor, avise já um profissional de saúde. Se estiver em casa, ligue 112.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

/// After sending: in the demo the same device shows what the clinician gets.
class _SentScreen extends StatelessWidget {
  const _SentScreen({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Enviado')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle, color: C.primary, size: 64),
              const SizedBox(height: 16),
              const Text('As suas respostas foram enviadas ao médico.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Nesta demonstração, pode ver o que o médico recebe.',
                  textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text('Ver o ecrã do médico'),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(builder: (_) => ConsultScreen(session: session, ownsSession: true)),
                ),
              ),
            ]),
          ),
        ),
      );
}
