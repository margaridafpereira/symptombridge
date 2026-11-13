import 'package:symptom_engine/symptom_engine.dart';
import 'package:test/test.dart';

/// The app suggests each concept's question, and the patient answers yes or
/// no. That only works if the question is read back as that concept.
void main() {
  for (final lang in Lang.values) {
    test('every suggested question is understood as its own concept (${lang.name})', () {
      final misses = <String>[];
      for (final c in concepts) {
        final q = c.ask(lang);
        if (q == null) continue;
        final found = questionFindings(q, lang, answer: true).map((f) => f.concept.id).toSet();
        if (!found.contains(c.id)) misses.add('${c.id}: "$q" → $found');
      }
      expect(misses, isEmpty, reason: misses.join('\n'));
    });

    test('every concept has phrases (${lang.name})', () {
      expect([for (final c in concepts) if (c.phrasesFor(lang).isEmpty) c.id], isEmpty);
    });
  }

  test('a yes to "any blood when you cough?" is about the blood, not a cough', () {
    final e = extract(parseTranscript('Doctor: Any blood when you cough?\nPatient: A little.'), lang: Lang.en);
    expect(e.has('hemoptysis'), isTrue);
    expect(e.mentioned('cough'), isFalse);
  });

  test('"já tossiu sangue?" is about the blood', () {
    final e = extract(parseTranscript('Médico: Já tossiu sangue?\nDoente: Sim.'));
    expect(e.has('hemoptysis'), isTrue);
  });
}
