import 'package:symptom_engine/symptom_engine.dart';
import 'package:test/test.dart';

/// A model whose answers the test decides.
class FakeModel implements Understander {
  FakeModel(this.answer, {this.fail});
  final List<ModelFinding> answer;
  final Exception? fail;

  @override
  String get name => 'fake';

  @override
  Future<List<ModelFinding>> understand(String transcript) async {
    if (fail != null) throw fail!;
    return answer;
  }
}

Set<String> flags(Assessment a) => a.redFlags.map((f) => f.id).toSet();

void main() {
  test('the model adds what the rules could not read, and its red flag follows', () async {
    const t = 'O meu marido de repente ficou com a cara à banda e não consegue levantar o braço.';
    expect(flags(await assessWith(t, null)), isEmpty, reason: 'rules alone miss it');

    final a = await assessWith(t, FakeModel(const [
      ModelFinding('face_droop', present: true, quote: 'a cara à banda'),
      ModelFinding('limb_weakness', present: true, quote: 'não consegue levantar o braço'),
    ]));
    expect(flags(a), contains('stroke'));
    expect(a.extraction.findings['face_droop']!.source, FindingSource.model);
  });

  test('a quote that is not in the transcript is thrown away', () async {
    final a = await assessWith('Tenho dor de cabeça.', FakeModel(const [
      ModelFinding('fever', present: true, quote: 'tenho febre alta'),
    ]));
    expect(a.extraction.has('fever'), isFalse);
    expect(a.merge!.rejected.single.id, 'fever');
  });

  test('the model cannot delete a symptom the rules found, only leave a note', () async {
    const t = 'Tenho um aperto no peito que vai para o braço esquerdo.';
    final a = await assessWith(t, FakeModel(const [
      ModelFinding('chest_pain', present: false, quote: 'aperto no peito'),
    ]));
    expect(a.extraction.has('chest_pain'), isTrue);
    expect(flags(a), contains('acs'));
    expect(a.merge!.notes.single, contains('leu como negado'));
  });

  test('saying nothing does not switch a red flag off', () async {
    final a = await assessWith('Dor no peito e suores frios.', FakeModel(const []));
    expect(flags(a), contains('acs'));
  });

  test("a relative's heart attack stops counting as the patient's history", () async {
    const t = 'O meu pai morreu de enfarte. Dói-me o peito quando respiro fundo.';
    expect(flags(await assessWith(t, null)), contains('acs'), reason: 'rules alone raise a false alarm');

    final a = await assessWith(t, FakeModel(const [
      ModelFinding('cardiac_history', present: true, quote: 'o meu pai morreu de enfarte', aboutOther: true),
    ]));
    expect(a.extraction.has('cardiac_history'), isFalse);
    expect(flags(a), isNot(contains('acs')));
    expect(a.merge!.reattributed.single.concept.id, 'cardiac_history');
  });

  test('only history can be given to someone else, never a symptom', () async {
    final a = await assessWith('Dor no peito e suores.', FakeModel(const [
      ModelFinding('chest_pain', present: true, quote: 'Dor no peito', aboutOther: true),
    ]));
    expect(a.extraction.has('chest_pain'), isTrue);
  });

  test('present beats denied when the two disagree', () async {
    final a = await assessWith('Médico: Tem falta de ar?\nDoente: Não muito, só às vezes.', FakeModel(const [
      ModelFinding('dyspnea', present: true, quote: 'só às vezes'),
    ]));
    expect(a.extraction.has('dyspnea'), isTrue);
  });

  test('if the model fails, the rules still answer and say why', () async {
    final a = await assessWith('Dor no peito e suores frios.', FakeModel(const [], fail: UnderstandingException('free quota used up')));
    expect(a.modelError, 'free quota used up');
    expect(flags(a), contains('acs'));
  });
}
