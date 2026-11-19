import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:symptom_engine/symptom_engine.dart' show Lang, Speaker, Utterance;
import 'package:web/web.dart' as web;

import '../session.dart' show workerUrl;

/// The `window.sbVoice` object from web/eleven.js.
extension type _SbVoice(JSObject _) implements JSObject {
  external JSPromise<JSAny?> play(String url);
  external void stopAudio();
  external JSPromise<JSAny?> recordStart();
  external bool get recording;
  external JSPromise<JSString> recordStopAndTranscribe(String endpoint);
  external void recordCancel();
  external JSPromise<JSAny?> agentStart(
    String urlEndpoint,
    String language,
    String firstMessage,
    JSFunction onLine,
    JSFunction onTool,
    JSFunction onEnd,
  );
  external JSPromise<JSAny?> agentStop();
}

class Voice {
  _SbVoice? get _js {
    final o = web.window.getProperty<JSObject?>('sbVoice'.toJS);
    return o == null ? null : _SbVoice(o);
  }

  /// Needs the Worker (which holds the ElevenLabs key) and the glue script.
  bool get available => workerUrl.isNotEmpty && _js != null;

  String _endpoint(String path, [Map<String, String>? query]) {
    final base = Uri.parse(workerUrl);
    final segments = [...base.pathSegments.where((s) => s.isNotEmpty), path];
    return base.replace(pathSegments: segments, queryParameters: query).toString();
  }

  /// Reads one of the app's own sentences aloud. The Worker refuses any
  /// other text, and caches each sentence so it is generated only once.
  Future<void> speak(String text, Lang lang) async {
    final js = _js;
    if (js == null || workerUrl.isEmpty) return;
    try {
      await js.play(_endpoint('tts', {'lang': lang.name, 'text': text})).toDart;
    } catch (_) {
      // Autoplay blocked or no credits left: the question is on screen anyway.
    }
  }

  void stopSpeaking() => _js?.stopAudio();

  bool get recording => _js?.recording ?? false;

  Future<void> startRecording() async => _js!.recordStart().toDart;

  /// Sends the recording to Scribe, which tells the two voices apart, and
  /// returns the conversation as clinician and patient turns.
  Future<List<Utterance>> stopAndTranscribe(Lang lang) async {
    final raw = (await _js!.recordStopAndTranscribe(_endpoint('transcribe', {'lang': lang.name})).toDart).toDart;
    final turns = (jsonDecode(raw) as Map<String, dynamic>)['turns'] as List;
    return [
      for (final t in turns.cast<Map<String, dynamic>>())
        Utterance(t['speaker'] == 'clinician' ? Speaker.clinician : Speaker.patient, (t['text'] as String).trim()),
    ];
  }

  void cancelRecording() => _js?.recordCancel();

  bool _talking = false;
  bool get talking => _talking;

  /// Starts the ElevenLabs voice agent. Every patient answer comes back
  /// through [onStep], where the rules engine decides what happens next.
  Future<void> startAgent({
    required Lang lang,
    required String firstMessage,
    required void Function(Speaker speaker, String text) onLine,
    required Future<String> Function(Map<String, Object?> params) onStep,
    required void Function(String? error) onEnd,
  }) async {
    _talking = true;
    try {
      await _js!
          .agentStart(
            _endpoint('agent'),
            lang.name,
            firstMessage,
            ((JSString source, JSString text) =>
                onLine(source.toDart == 'user' ? Speaker.patient : Speaker.clinician, text.toDart)).toJS,
            ((JSString name, JSString params) => onStep((jsonDecode(params.toDart) as Map).cast<String, Object?>())
                .then((s) => s.toJS)
                .toJS).toJS,
            ((JSString? error) {
              _talking = false;
              onEnd(error?.toDart);
            }).toJS,
          )
          .toDart;
    } catch (_) {
      _talking = false;
      rethrow;
    }
  }

  Future<void> stopAgent() async {
    _talking = false;
    await _js?.agentStop().toDart;
  }
}
