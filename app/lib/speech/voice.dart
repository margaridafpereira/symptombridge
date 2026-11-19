// ElevenLabs voice: questions read aloud, Scribe transcription and the voice
// agent. Only on the web, through the Worker; elsewhere it reports itself
// unavailable and the app works as before.
export 'voice_stub.dart' if (dart.library.js_interop) 'voice_web.dart';
