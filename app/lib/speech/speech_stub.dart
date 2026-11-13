import 'package:symptom_engine/symptom_engine.dart' show Lang;

class SpeechInput {
  bool get supported => false;
  bool get listening => false;
  void start({
    required Lang lang,
    required void Function(String text, bool isFinal) onText,
    required void Function(String? error) onEnd,
  }) =>
      onEnd('speech recognition is not available here');
  void stop() {}
}
