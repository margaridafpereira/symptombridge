import 'package:symptom_engine/symptom_engine.dart';

void main() {
  final a = assess('''
Doente: Tenho 58 anos. Começou há duas horas, um aperto no peito que vai para o braço esquerdo.
Médico: Tem suores?
Doente: Sim, suores frios. Não tenho febre.
''');
  print('Findings: ${a.extraction.findings.values.toList()}');
  print('Red flags: ${a.redFlags}');
  print('Hypotheses: ${a.hypotheses}');
}
