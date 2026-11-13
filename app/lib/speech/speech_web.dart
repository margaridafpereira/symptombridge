import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:symptom_engine/symptom_engine.dart' show Lang;
import 'package:web/web.dart' as web;

/// The browser's speech recognition (Chrome, Edge), in European Portuguese or British English.
/// Audio is handled by the browser's own service; the app only sees text.
class SpeechInput {
  JSFunction? get _ctor =>
      web.window.getProperty<JSFunction?>('SpeechRecognition'.toJS) ??
      web.window.getProperty<JSFunction?>('webkitSpeechRecognition'.toJS);

  bool get supported => _ctor != null;
  bool get listening => _rec != null;

  JSObject? _rec;
  bool _stopping = false;

  void start({
    required Lang lang,
    required void Function(String text, bool isFinal) onText,
    required void Function(String? error) onEnd,
  }) {
    final ctor = _ctor;
    if (ctor == null) return onEnd('speech recognition is not available in this browser');
    final rec = ctor.callAsConstructor<JSObject>();
    rec
      ..setProperty('lang'.toJS, lang.pick('pt-PT', 'en-GB').toJS)
      ..setProperty('continuous'.toJS, true.toJS)
      ..setProperty('interimResults'.toJS, true.toJS);
    rec.setProperty(
      'onresult'.toJS,
      ((JSObject event) {
        final results = event.getProperty<JSObject>('results'.toJS);
        final start = event.getProperty<JSNumber>('resultIndex'.toJS).toDartInt;
        final length = results.getProperty<JSNumber>('length'.toJS).toDartInt;
        for (var i = start; i < length; i++) {
          final result = results.getProperty<JSObject>(i.toJS);
          final best = result.getProperty<JSObject>(0.toJS);
          final text = best.getProperty<JSString>('transcript'.toJS).toDart;
          onText(text.trim(), result.getProperty<JSBoolean>('isFinal'.toJS).toDart);
        }
      }).toJS,
    );
    rec.setProperty('onerror'.toJS, ((JSObject e) {
      final error = e.getProperty<JSString?>('error'.toJS)?.toDart;
      if (error != 'no-speech' && error != 'aborted') onEnd(error);
    }).toJS);
    rec.setProperty('onend'.toJS, ((JSAny? _) {
      // Chrome stops after a pause; keep listening until the user stops.
      if (!_stopping && _rec == rec) {
        rec.callMethod<JSAny?>('start'.toJS);
      } else {
        _rec = null;
        onEnd(null);
      }
    }).toJS);
    _stopping = false;
    _rec = rec;
    rec.callMethod<JSAny?>('start'.toJS);
  }

  void stop() {
    _stopping = true;
    _rec?.callMethod<JSAny?>('stop'.toJS);
  }
}
