// Speech to text: the browser's Web Speech API on the web; elsewhere none yet
// (the app falls back to typing).
export 'speech_stub.dart' if (dart.library.js_interop) 'speech_web.dart';
