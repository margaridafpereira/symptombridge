import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:symptom_engine/symptom_engine.dart';

import '../intake_questions.dart';
import '../session.dart';
import '../speech/speech.dart';
import '../speech/voice.dart';
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

_Question _opening(Lang l) => _Question(openingQuestion(l), yesNo: false);
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
  final _voice = Voice();
  final _input = TextEditingController();

  /// Questions read aloud by ElevenLabs, when the Worker has a key.
  bool _readAloud = true;
  bool _spokeEmergency = false;

  /// The ElevenLabs voice agent is running the interview.
  bool _agentOn = false;

  /// The last answer was spoken, so the microphone reopens by itself after
  /// the next question: the same interview, hands-free.
  bool _byVoice = false;

  /// Speech recognition splits an answer into pieces; wait for a pause
  /// before treating it as finished.
  Timer? _pause;
  String _heard = '';
  static const _pauseToFinish = Duration(milliseconds: 1800);
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _say(_current!.text));
  }

  @override
  void dispose() {
    _pause?.cancel();
    _speech.stop();
    _voice.stopSpeaking();
    if (_agentOn) _voice.stopAgent();
    if (!_handedOver) _session.dispose();
    super.dispose();
  }

  bool get _emergency => _session.assessment.redFlags.any((f) => f.urgency == Urgency.emergency);

  void _answer(String text, {bool byVoice = false}) {
    if (text.trim().isEmpty) return;
    _byVoice = byVoice;
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
    _say(q?.text ?? thanksMessage(_session.lang)).then((_) {
      if (mounted && q != null && _byVoice && !_listening && _speech.supported) _startListening();
    });
  }

  /// Reads a sentence aloud; an emergency is always said first, once.
  /// Completes when the audio has finished, so the microphone does not hear it.
  Future<void> _say(String text) async {
    if (!_readAloud || !_voice.available || _agentOn) return;
    final l = _session.lang;
    if (_emergency && !_spokeEmergency) {
      _spokeEmergency = true;
      await _voice.speak(emergencyMessage(l), l);
      if (!mounted || !_readAloud) return;
    }
    await _voice.speak(text, l);
  }

  /// The voice agent asks the questions; every answer comes back here, the
  /// rules engine picks the next question, and an emergency always wins.
  Future<void> _startAgent() async {
    final l = _session.lang;
    _speech.stop();
    _voice.stopSpeaking();
    _session.clear();
    setState(() {
      _agentOn = true;
      _listening = false;
      _asked.clear();
      _count = 0;
      _askedDuration = _askedSeverity = false;
    });
    try {
      await _voice.startAgent(
        lang: l,
        firstMessage: openingQuestion(l),
        onLine: _agentLine,
        onStep: _agentStep,
        onEnd: (error) {
          if (!mounted) return;
          setState(() {
            _agentOn = false;
            _current = null;
          });
          if (error != null) _toast(l.pick('Assistente de voz: $error', 'Voice assistant: $error'));
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _agentOn = false;
        _current = _opening(l);
      });
      _session.add(Speaker.clinician, _current!.text);
      _toast(l.pick('Não foi possível iniciar o assistente de voz: $e', 'Could not start the voice assistant: $e'));
    }
  }

  void _agentLine(Speaker speaker, String text) {
    final last = _session.turns.lastOrNull;
    if (last != null && last.speaker == speaker && last.text == text.trim()) return;
    _session.add(speaker, text);
  }

  Future<String> _agentStep(Map<String, Object?> params) async {
    final answer = params['patient_answer'];
    if (answer is String && answer.trim().isNotEmpty) _agentLine(Speaker.patient, answer);
    final l = _session.lang;
    final a = _session.assessment;
    final q = _count >= _maxQuestions ? null : _choose(a.extraction, a.hypotheses);
    if (q != null) {
      _count++;
      if (q.concept != null) _asked.add(q.concept!);
    }
    return jsonEncode({
      'urgent': _emergency,
      if (_emergency) 'tell_patient': emergencyMessage(l),
      'next_question': q?.text,
      'finished': q == null,
      if (q == null) 'closing': thanksMessage(l),
    });
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

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
      return _Question(durationQuestion(l), yesNo: false);
    }
    final pain = e.has('chest_pain') || e.has('headache') || e.has('abdominal_pain') || e.has('flank_pain');
    if (!_askedSeverity && pain && e.severity == null) {
      _askedSeverity = true;
      return _Question(severityQuestion(l), yesNo: false);
    }
    for (final h in hypotheses.take(3)) {
      for (final c in h.askNext) {
        if (open(c.id)) return _Question(c.ask(l)!, concept: c.id);
      }
    }
    return null;
  }

  void _toggleMic() => _listening ? _finishListening() : _startListening();

  void _startListening() {
    _voice.stopSpeaking();
    _pause?.cancel();
    _heard = '';
    setState(() => _listening = true);
    _speech.start(
      lang: _session.lang,
      onText: (text, isFinal) {
        _pause?.cancel();
        if (isFinal) {
          _heard = '$_heard $text'.trim();
          _session.setInterim(Speaker.patient, _heard);
          _pause = Timer(_pauseToFinish, _finishListening);
        } else {
          _session.setInterim(Speaker.patient, '$_heard $text'.trim());
        }
      },
      onEnd: (error) {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  /// The patient paused or tapped stop: everything heard is one answer.
  void _finishListening() {
    _pause?.cancel();
    _speech.stop();
    if (!mounted) return;
    final text = _session.interim.trim().isNotEmpty ? _session.interim.trim() : _heard;
    _heard = '';
    setState(() => _listening = false);
    if (text.isEmpty) return;
    _answer(text, byVoice: true);
  }

  void _send() {
    _speech.stop();
    _voice.stopSpeaking();
    if (_agentOn) _voice.stopAgent();
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
            appBar: AppBar(title: Text(l.pick('Pré-consulta', 'Before your visit')), actions: [
              if (_voice.available)
                IconButton(
                  tooltip: _readAloud ? l.pick('Não ler as perguntas', 'Stop reading questions aloud') : l.pick('Ler as perguntas em voz alta', 'Read questions aloud'),
                  icon: Icon(_readAloud ? Icons.volume_up : Icons.volume_off),
                  onPressed: () {
                    setState(() => _readAloud = !_readAloud);
                    if (!_readAloud) _voice.stopSpeaking();
                  },
                ),
            ]),
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
                      child: _agentOn
                          ? _AgentBar(lang: l, onStop: () => _voice.stopAgent())
                          : q == null
                          ? Column(children: [
                              Text(thanksMessage(l), textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
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
                              if (_voice.available && !_session.turns.any((t) => t.speaker == Speaker.patient)) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.record_voice_over),
                                    label: Text(l.pick('Prefiro conversar por voz com o assistente', "I'd rather talk to the voice assistant")),
                                    onPressed: _startAgent,
                                  ),
                                ),
                              ],
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

/// While the voice agent runs the interview.
class _AgentBar extends StatelessWidget {
  const _AgentBar({required this.lang, required this.onStop});
  final Lang lang;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.graphic_eq, color: C.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(lang.pick('A conversar com o assistente de voz. Fale à vontade.', 'Talking to the voice assistant. Speak freely.'),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.alarm),
          icon: const Icon(Icons.call_end),
          label: Text(lang.pick('Terminar', 'End')),
          onPressed: onStop,
        ),
      ]);
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
              child: Text(emergencyMessage(lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
