import 'package:flutter/material.dart';

import 'clinician/clinician_screens.dart';
import 'lang.dart';
import 'screens/consult_screen.dart';
import 'screens/home.dart';
import 'theme.dart';

void main() => runApp(const SymptomBridgeApp());

class SymptomBridgeApp extends StatelessWidget {
  const SymptomBridgeApp({super.key});

  @override
  Widget build(BuildContext context) => LangScope(
        child: MaterialApp(
          title: 'SymptomBridge',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          // ?caso=c01 (or e01 in English) opens that example in the
          // consultation, after the clinician sign-in. ?lang=en|pt picks the language.
          home: switch (Uri.base.queryParameters['caso']) {
            final String id => ClinicianSignIn(then: ConsultScreen(exampleId: id)),
            null => const HomeScreen(),
          },
        ),
      );
}
