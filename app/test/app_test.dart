import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:symptombridge/main.dart';
import 'package:symptombridge/screens/consult_screen.dart';
import 'package:symptombridge/screens/intake_screen.dart';
import 'package:symptombridge/session.dart';
import 'package:symptombridge/theme.dart';

Future<void> phone(WidgetTester tester, Widget home, {Size size = const Size(1080, 2400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
}

void main() {
  testWidgets('home offers both modes', (tester) async {
    await tester.pumpWidget(const SymptomBridgeApp());
    expect(find.text('Consulta'), findsOneWidget);
    expect(find.text('Pré-consulta'), findsOneWidget);
  });

  testWidgets('consultation: a cardiac story raises the red flag on the clinician panel', (tester) async {
    final session = Session();
    await phone(tester, ConsultScreen(session: session), size: const Size(2400, 1600));
    session.load('Doente: Tenho um aperto no peito que vai para o braço esquerdo.\nMédico: Tem suores?\nDoente: Sim, suores frios.');
    await tester.pump();
    expect(find.text('Possível síndrome coronária aguda'), findsOneWidget);
    expect(find.text('EMERGENTE'), findsOneWidget);
    expect(find.text('Síndrome coronária aguda'), findsOneWidget);
  });

  testWidgets('consultation: tapping a suggested question puts it in the conversation', (tester) async {
    final session = Session();
    await phone(tester, ConsultScreen(session: session), size: const Size(2400, 1600));
    session.load('Doente: Tenho dor de cabeça.');
    await tester.pump();
    final ask = find.widgetWithText(ActionChip, 'Começou de repente, em segundos?');
    expect(ask, findsWidgets);
    await tester.ensureVisible(ask.first);
    await tester.tap(ask.first);
    await tester.pump();
    expect(session.turns.last.text, 'Começou de repente, em segundos?');
  });

  testWidgets('pre-visit: chest pain asks the safety question first, and an emergency tells the patient what to do, not why',
      (tester) async {
    await phone(tester, const IntakeScreen());
    await tester.enterText(find.byType(TextField), 'Tenho um aperto no peito.');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(find.text('A dor vai para o braço, maxilar ou pescoço?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sim'));
    await tester.pump();
    expect(find.textContaining('avise já um profissional de saúde'), findsOneWidget);
    // The patient never sees the clinician's wording.
    expect(find.textContaining('coronária'), findsNothing);
  });

  testWidgets('pre-visit ends with a summary the clinician can open', (tester) async {
    await phone(tester, const IntakeScreen());
    await tester.enterText(find.byType(TextField), 'Tenho tosse e o nariz entupido.');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.tap(find.text('Terminar e enviar ao médico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver o ecrã do médico'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Painel do médico'));
    await tester.pumpAndSettle();
    expect(find.text('Constipação'), findsOneWidget);
  });
}
