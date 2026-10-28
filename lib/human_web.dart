// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js;

/// A one-time token that proves a real person is here (Cloudflare
/// Turnstile, see web/index.html).
Future<String?> humanToken(String siteKey) async {
  try {
    final token = await js.promiseToFuture<Object?>(
        js.callMethod(html.window, 'spHumanToken', [siteKey]));
    return token as String?;
  } catch (_) {
    return null;
  }
}
