// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

final _registered = <String>{};

/// A <model-viewer> element: drag to rotate, pinch or scroll to zoom,
/// slowly turns by itself.
class ModelView extends StatelessWidget {
  const ModelView({super.key, required this.src});

  /// Asset path, e.g. assets/works/dragon.glb.
  final String src;

  @override
  Widget build(BuildContext context) {
    final type = 'model-view-$src';
    if (_registered.add(type)) {
      ui_web.platformViewRegistry.registerViewFactory(type, (int _) {
        final el = html.Element.tag('model-viewer')
          // Flutter web serves assets under assets/.
          ..setAttribute('src', 'assets/$src')
          ..setAttribute('camera-controls', '')
          ..setAttribute('auto-rotate', '')
          ..setAttribute('auto-rotate-delay', '0')
          ..setAttribute('rotation-per-second', '18deg')
          ..setAttribute('interaction-prompt', 'none')
          ..setAttribute('shadow-intensity', '0.6')
          ..setAttribute('exposure', '1.1')
          ..setAttribute('environment-image', 'neutral');
        el.style
          ..width = '100%'
          ..height = '100%'
          ..backgroundColor = 'transparent';
        return el;
      });
    }
    return HtmlElementView(viewType: type);
  }
}
