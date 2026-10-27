import 'dart:ui' as ui;

import 'package:flutter/material.dart' as m;

import 'translation.dart';

/// Drop-in replacement for Flutter's Text that translates itself into the
/// chosen language (same as in Ember & Bloom). A file opts in with:
///   import 'package:flutter/material.dart' hide Text;
///   import '../tr_text.dart';
class Text extends m.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    this.maxLines,
  });

  final String data;
  final m.TextStyle? style;
  final m.TextAlign? textAlign;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final int? maxLines;

  @override
  m.Widget build(m.BuildContext context) {
    final tr = TranslationService.instance;
    return m.ValueListenableBuilder<int>(
      valueListenable: tr.revision,
      builder: (_, __, ___) => m.Text(
        tr.t(data),
        style: style,
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
      ),
    );
  }
}

/// For screens with field labels (plain strings, not Text widgets):
/// rebuild when a translation arrives or the language changes.
mixin RebuildOnTranslation<T extends m.StatefulWidget> on m.State<T> {
  void _rebuild() => setState(() {});

  @override
  void initState() {
    super.initState();
    TranslationService.instance.revision.addListener(_rebuild);
  }

  @override
  void dispose() {
    TranslationService.instance.revision.removeListener(_rebuild);
    super.dispose();
  }
}

/// The globe: opens the language list.
class LanguageButton extends m.StatelessWidget {
  const LanguageButton({super.key, this.size = 26, this.color});
  final double size;
  final ui.Color? color;

  @override
  m.Widget build(m.BuildContext context) => m.IconButton(
        tooltip: 'Language',
        icon: m.Icon(m.Icons.language, size: size, color: color),
        onPressed: () => m.showModalBottomSheet<void>(
          context: context,
          builder: (ctx) => m.Padding(
            padding: const m.EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: m.Column(
              mainAxisSize: m.MainAxisSize.min,
              children: [
                for (final (code, flag, name) in TranslationService.languages)
                  m.ListTile(
                    leading:
                        m.Text(flag, style: const m.TextStyle(fontSize: 26)),
                    title: m.Text(name),
                    trailing: code == TranslationService.instance.lang
                        ? const m.Icon(m.Icons.check)
                        : null,
                    onTap: () {
                      TranslationService.instance.setLang(code);
                      m.Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        ),
      );
}
