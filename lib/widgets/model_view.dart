// The real viewer exists only in the browser; tests get a plain box.
export 'model_view_stub.dart' if (dart.library.html) 'model_view_web.dart';
