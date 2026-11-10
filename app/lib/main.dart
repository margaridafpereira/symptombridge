import 'package:flutter/material.dart';

import 'screens/consult_screen.dart';
import 'screens/home.dart';
import 'theme.dart';

void main() => runApp(const SymptomBridgeApp());

class SymptomBridgeApp extends StatelessWidget {
  const SymptomBridgeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SymptomBridge',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // ?caso=c01 opens the consultation with that example loaded.
        home: switch (Uri.base.queryParameters['caso']) {
          final String id => ConsultScreen(exampleId: id),
          null => const HomeScreen(),
        },
      );
}
