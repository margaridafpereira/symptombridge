import 'package:symptom_engine/symptom_engine.dart';

/// Every sentence the app itself says to a patient. Kept free of Flutter so
/// the voice allowlist test can list them: the Worker only reads these out
/// loud, nothing else.
String openingQuestion(Lang l) =>
    l.pick('Olá. O que o traz cá hoje? Conte-me com as suas palavras.', 'Hello. What brings you in today? Tell me in your own words.');

String durationQuestion(Lang l) => l.pick('Há quanto tempo começou?', 'How long ago did it start?');

String severityQuestion(Lang l) => l.pick('De 0 a 10, quanto lhe dói?', 'From 0 to 10, how bad is the pain?');

String emergencyMessage(Lang l) => l.pick('Por favor, avise já um profissional de saúde. Se estiver em casa, ligue 112.',
    'Please tell a healthcare professional now. If you are at home, call 112.');

String thanksMessage(Lang l) =>
    l.pick('Obrigado. O médico vai ver as suas respostas antes de o chamar.', 'Thank you. The doctor will read your answers before calling you in.');

/// What the Worker may turn into speech, per language.
List<String> spokenTexts(Lang l) => {
      openingQuestion(l),
      durationQuestion(l),
      severityQuestion(l),
      emergencyMessage(l),
      thanksMessage(l),
      for (final c in concepts) ?c.ask(l),
    }.toList()
      ..sort();
