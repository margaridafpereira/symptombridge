import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:symptom_engine/symptom_engine.dart';

/// The Worker that holds the Gemini key. Empty means rules only.
/// Set at build time: --dart-define=SYMPTOMBRIDGE_API=https://…workers.dev
const workerUrl = String.fromEnvironment('SYMPTOMBRIDGE_API');

/// One conversation, from either mode. Each new line is assessed straight
/// away with the rules; the language model runs after a pause, so the free
/// quota is not spent on every word.
class Session extends ChangeNotifier {
  Session({Understander? understander, this.modelDelay = const Duration(milliseconds: 1500)})
      : understander = understander ?? (workerUrl.isEmpty ? null : WorkerUnderstander(Uri.parse(workerUrl)));

  final Understander? understander;
  final Duration modelDelay;

  final turns = <Utterance>[];

  /// What is being said right now, not final yet.
  String interim = '';
  Speaker interimSpeaker = Speaker.patient;

  Assessment assessment = assess('');
  bool modelRunning = false;
  String? modelError;
  bool get usesModel => understander != null;

  Timer? _debounce;
  int _generation = 0;

  String get transcript => turns
      .map((t) => '${t.speaker == Speaker.clinician ? 'Médico' : 'Doente'}: ${t.text}')
      .join('\n');

  void add(Speaker speaker, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    turns.add(Utterance(speaker, t));
    interim = '';
    _assess();
  }

  void setInterim(Speaker speaker, String text) {
    interimSpeaker = speaker;
    interim = text;
    notifyListeners();
  }

  void load(String transcript) {
    turns
      ..clear()
      ..addAll(parseTranscript(transcript));
    _assess(immediateModel: true);
  }

  void clear() {
    turns.clear();
    interim = '';
    modelError = null;
    _debounce?.cancel();
    _generation++;
    assessment = assess('');
    notifyListeners();
  }

  void _assess({bool immediateModel = false}) {
    assessment = assess(transcript);
    notifyListeners();
    final model = understander;
    if (model == null) return;
    _debounce?.cancel();
    _debounce = Timer(immediateModel ? Duration.zero : modelDelay, () => _runModel(model));
  }

  Future<void> _runModel(Understander model) async {
    final generation = ++_generation;
    final text = transcript;
    modelRunning = true;
    notifyListeners();
    final a = await assessWith(text, model);
    if (generation != _generation) return; // a newer line arrived meanwhile
    assessment = a;
    modelError = a.modelError;
    modelRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
