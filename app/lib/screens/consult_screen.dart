import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:symptom_engine/symptom_engine.dart';

import '../lang.dart';
import '../session.dart';
import '../speech/speech.dart';
import '../theme.dart';
import 'clinician_panel.dart';

/// Consultation mode: the device listens to the conversation and the
/// clinician's panel updates as it goes.
class ConsultScreen extends StatefulWidget {
  const ConsultScreen({super.key, this.session, this.ownsSession = false, this.exampleId});
  final Session? session;

  /// Take over a session handed on by another screen and dispose of it here.
  final bool ownsSession;

  /// Opens with this example case loaded (links like ?caso=c01).
  final String? exampleId;

  @override
  State<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends State<ConsultScreen> {
  late Session _session = widget.session ?? Session();
  late bool _ownsSession = widget.session == null || widget.ownsSession;
  final _speech = SpeechInput();
  final _input = TextEditingController();
  Speaker _speaker = Speaker.patient;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    final id = widget.exampleId;
    if (id != null) {
      _loadCases().then((cases) {
        final c = cases.where((c) => c['id'] == id).firstOrNull;
        if (c != null && mounted) _open(c);
      });
    }
  }

  static Future<List<Map<String, dynamic>>> _loadCases() async =>
      (jsonDecode(await rootBundle.loadString('assets/examples.json')) as List).cast<Map<String, dynamic>>();

  static Lang _langOf(Map<String, dynamic> c) => c['lang'] == 'en' ? Lang.en : Lang.pt;

  /// Loads an example; one in the other language starts a fresh session in
  /// that language and switches the screens to it.
  void _open(Map<String, dynamic> c) {
    final lang = _langOf(c);
    if (lang != _session.lang) {
      _speech.stop();
      if (_ownsSession) _session.dispose();
      setState(() {
        _session = Session(lang: lang);
        _ownsSession = true;
        _listening = false;
      });
      appLang.value = lang;
    }
    _session.load(c['transcript'] as String);
  }

  @override
  void dispose() {
    _speech.stop();
    if (_ownsSession) _session.dispose();
    super.dispose();
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
      onText: (text, isFinal) => isFinal ? _session.add(_speaker, text) : _session.setInterim(_speaker, text),
      onEnd: (error) {
        if (!mounted) return;
        setState(() => _listening = false);
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('Microfone', 'Microphone')}: $error')));
        }
      },
    );
  }

  void _send() {
    _session.add(_speaker, _input.text);
    _input.clear();
  }

  Future<void> _examples() async {
    final lang = context.lang;
    final cases = [for (final c in await _loadCases()) if (_langOf(c) == lang) c];
    if (!mounted) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(lang.pick('Casos fictícios', 'Made-up cases'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        for (final c in cases)
          ListTile(
            leading: Icon(c['mode'] == 'consult' ? Icons.forum_outlined : Icons.person_outline),
            title: Text(_titlePt(c)),
            subtitle: Text((c['transcript'] as String).split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(context, c),
          ),
      ]),
    );
    if (picked != null) _open(picked);
  }

  /// Titles are in English, for the evaluation report.
  String _titlePt(Map<String, dynamic> c) => '${c['id']} · ${c['title']}';

  void _ask(String question) {
    _session.add(Speaker.clinician, question);
    setState(() => _speaker = Speaker.patient);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          final flags = _session.assessment.redFlags.length;
          final wide = MediaQuery.sizeOf(context).width >= 900;
          final conversation = _Conversation(
            session: _session,
            speaker: _speaker,
            onSpeaker: (s) => setState(() => _speaker = s),
            listening: _listening,
            micSupported: _speech.supported,
            onMic: _toggleMic,
            input: _input,
            onSend: _send,
          );
          final panel = ClinicianPanel(session: _session, onAsk: _ask);
          final actions = [
            IconButton(tooltip: context.tr('Casos de exemplo', 'Example cases'), icon: const Icon(Icons.library_books_outlined), onPressed: _examples),
            IconButton(tooltip: context.tr('Limpar', 'Clear'), icon: const Icon(Icons.delete_sweep_outlined), onPressed: _session.clear),
          ];
          if (wide) {
            return Scaffold(
              appBar: AppBar(title: Text(context.tr('Consulta', 'Consultation')), actions: actions),
              body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 5, child: conversation),
                const VerticalDivider(width: 1),
                Expanded(flex: 6, child: panel),
              ]),
            );
          }
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: Text(context.tr('Consulta', 'Consultation')),
                actions: actions,
                bottom: TabBar(tabs: [
                  Tab(text: context.tr('Conversa', 'Conversation')),
                  Tab(
                    child: Badge(
                      isLabelVisible: flags > 0,
                      label: Text('$flags'),
                      backgroundColor: C.alarm,
                      child: Padding(padding: const EdgeInsets.only(right: 6), child: Text(context.tr('Painel do médico', 'Clinician panel'))),
                    ),
                  ),
                ]),
              ),
              body: TabBarView(children: [conversation, panel]),
            ),
          );
        },
      );
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.session,
    required this.speaker,
    required this.onSpeaker,
    required this.listening,
    required this.micSupported,
    required this.onMic,
    required this.input,
    required this.onSend,
  });

  final Session session;
  final Speaker speaker;
  final ValueChanged<Speaker> onSpeaker;
  final bool listening;
  final bool micSupported;
  final VoidCallback onMic;
  final TextEditingController input;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
          child: session.turns.isEmpty && session.interim.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      micSupported
                          ? context.tr('Carregue no microfone e conversem normalmente.\nToque em "Médico" ou "Doente" para dizer quem está a falar.',
                              'Tap the microphone and talk as usual.\nTap "Doctor" or "Patient" to say who is speaking.')
                          : context.tr('Este browser não tem reconhecimento de voz (use Chrome ou Edge). Pode escrever, ou abrir um caso de exemplo.',
                              'This browser has no speech recognition (use Chrome or Edge). You can type, or open an example case.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: C.muted, height: 1.5),
                    ),
                  ),
                )
              : ListView(padding: const EdgeInsets.all(16), reverse: true, children: [
                  if (session.interim.isNotEmpty) _Bubble(session.interimSpeaker, session.interim, interim: true),
                  for (final t in session.turns.reversed) _Bubble(t.speaker, t.text),
                ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: const BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line))),
          child: SafeArea(
            top: false,
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: SegmentedButton<Speaker>(
                    segments: [
                      ButtonSegment(value: Speaker.clinician, icon: const Icon(Icons.medical_services_outlined), label: Text(context.tr('Médico', 'Doctor'))),
                      ButtonSegment(value: Speaker.patient, icon: const Icon(Icons.person_outline), label: Text(context.tr('Doente', 'Patient'))),
                    ],
                    selected: {speaker},
                    onSelectionChanged: (s) => onSpeaker(s.single),
                  ),
                ),
                const SizedBox(width: 10),
                if (micSupported)
                  FloatingActionButton(
                    heroTag: 'mic',
                    tooltip: listening ? context.tr('Parar', 'Stop') : context.tr('Ouvir', 'Listen'),
                    backgroundColor: listening ? C.alarm : C.primary,
                    foregroundColor: Colors.white,
                    onPressed: onMic,
                    child: Icon(listening ? Icons.stop : Icons.mic),
                  ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: input,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: speaker == Speaker.patient
                      ? context.tr('O que o doente diz…', 'What the patient says…')
                      : context.tr('O que o médico pergunta…', 'What the doctor asks…'),
                  filled: true,
                  fillColor: C.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: IconButton(tooltip: context.tr('Enviar', 'Send'), icon: const Icon(Icons.send), onPressed: onSend),
                ),
              ),
            ]),
          ),
        ),
      ]);
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.speaker, this.text, {this.interim = false});
  final Speaker speaker;
  final String text;
  final bool interim;

  @override
  Widget build(BuildContext context) {
    final clinician = speaker == Speaker.clinician;
    return Align(
      alignment: clinician ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: clinician ? C.surface : C.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: clinician ? C.line : Colors.transparent),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(clinician ? context.tr('Médico', 'Doctor') : context.tr('Doente', 'Patient'),
              style: const TextStyle(fontSize: 11, color: C.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(text, style: TextStyle(color: interim ? C.muted : C.text, fontStyle: interim ? FontStyle.italic : null)),
        ]),
      ),
    );
  }
}
