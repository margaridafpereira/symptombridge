import 'package:symptom_engine/symptom_engine.dart' show Lang, Speaker, Utterance;

class Voice {
  bool get available => false;
  Future<void> speak(String text, Lang lang) async {}
  void stopSpeaking() {}
  bool get recording => false;
  Future<void> startRecording() async => throw UnsupportedError('no voice here');
  Future<List<Utterance>> stopAndTranscribe(Lang lang) async => throw UnsupportedError('no voice here');
  void cancelRecording() {}
  bool get talking => false;
  Future<void> startAgent({
    required Lang lang,
    required String firstMessage,
    required void Function(Speaker speaker, String text) onLine,
    required Future<String> Function(Map<String, Object?> params) onStep,
    required void Function(String? error) onEnd,
  }) async =>
      throw UnsupportedError('no voice here');
  Future<void> stopAgent() async {}
}
