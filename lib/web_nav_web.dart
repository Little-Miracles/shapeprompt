// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void goTo(String url) => html.window.location.assign(url);

/// Removes ?paypal=… from the address, so a reload doesn't repeat it.
void clearQuery() {
  final loc = html.window.location;
  html.window.history.replaceState(null, '', '${loc.pathname}${loc.hash}');
}
