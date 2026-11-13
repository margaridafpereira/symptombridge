import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:symptom_engine/symptom_engine.dart';

/// The language the app speaks. Starts from ?lang=en|pt in the address,
/// otherwise from the browser: Portuguese for Portuguese browsers, English
/// for everyone else.
final appLang = ValueNotifier<Lang>(_initialLang());

Lang _initialLang() {
  switch (Uri.base.queryParameters['lang']) {
    case 'en':
      return Lang.en;
    case 'pt':
      return Lang.pt;
  }
  return PlatformDispatcher.instance.locale.languageCode == 'pt' ? Lang.pt : Lang.en;
}

/// Puts [appLang] above the app so every screen, including ones already
/// open, rebuilds when it changes.
class LangScope extends InheritedNotifier<ValueNotifier<Lang>> {
  LangScope({super.key, required super.child}) : super(notifier: appLang);
}

extension LangContext on BuildContext {
  Lang get lang => dependOnInheritedWidgetOfExactType<LangScope>()?.notifier?.value ?? appLang.value;

  /// The Portuguese or English text, whichever the app is in.
  String tr(String pt, String en) => lang.pick(pt, en);
}

/// PT | EN switch for app bars.
class LangButton extends StatelessWidget {
  const LangButton({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SegmentedButton<Lang>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        segments: const [
          ButtonSegment(value: Lang.pt, label: Text('PT'), tooltip: 'Português'),
          ButtonSegment(value: Lang.en, label: Text('EN'), tooltip: 'English'),
        ],
        selected: {lang},
        onSelectionChanged: (s) => appLang.value = s.single,
      ),
    );
  }
}
