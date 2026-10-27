// Speech lives only in the browser; tests get a silent stub.
export 'voice_stub.dart' if (dart.library.html) 'voice_web.dart';
