import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// On-the-fly translation through the network, like in Ember & Bloom:
/// the app is written in English, each phrase is fetched once and kept only
/// in memory while the app is open. Nothing is stored, no translation files
/// are shipped. Without internet the app simply stays in English.
///
/// ⚠️ The free Google endpoint is unofficial and may rate-limit — fine for
/// the prototype; a real release would go through our own proxy.
class TranslationService {
  TranslationService._();
  static final instance = TranslationService._();

  /// Code, flag and own name. Flags keep the names from being translated.
  static const languages = [
    ('en', '🇬🇧', 'English'),
    ('uk', '🇺🇦', 'Українська'),
    ('pl', '🇵🇱', 'Polski'),
    ('de', '🇩🇪', 'Deutsch'),
    ('fr', '🇫🇷', 'Français'),
  ];

  static const _prefsLang = 'lang';

  String lang = 'en';
  final Map<String, String> _cache = {}; // memory only — gone with the tab
  final Set<String> _outputs = {}; // texts that already are translations
  final Map<String, Future<String>> _pending = {};
  SharedPreferences? _prefs;

  /// Bumped when a translation arrives or the language changes:
  /// every on-screen Text rebuilds.
  final revision = ValueNotifier<int>(0);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    lang = _prefs!.getString(_prefsLang) ?? 'en';
  }

  Future<void> setLang(String code) async {
    lang = code;
    await _prefs?.setString(_prefsLang, code);
    revision.value++;
  }

  /// For build(): the translation if we have it, otherwise the English text
  /// (the translation is fetched in the background and the screen rebuilds).
  String t(String text) {
    if (lang == 'en' || !_worthSending(text)) return text;
    final hit = _cache['$lang|$text'];
    if (hit != null) return hit;
    translate(text);
    return text;
  }

  /// Waits for the translation (the typewriter line on the intro).
  Future<String> translate(String text) {
    if (lang == 'en' || !_worthSending(text)) return Future.value(text);
    final key = '$lang|$text';
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);
    // The braces matter: `=> _pending.remove(key)` would hand back this very
    // future, and whenComplete would wait for itself forever.
    return _pending[key] ??= _fetch(text, 'en', lang).whenComplete(() {
      _pending.remove(key);
    });
  }

  /// A search typed in the user's language, turned into English so it can
  /// find products ("буряк" → "beetroot").
  Future<String> toEnglish(String text) async {
    if (lang == 'en' || text.trim().isEmpty) return text;
    final key = 'en<$lang|$text';
    return _cache[key] ??= await _fetch(text, lang, 'en', remember: false);
  }

  /// Tests put a fake translator here (there is no network in tests).
  @visibleForTesting
  Future<String?> Function(String text, String from, String to)? fake;

  Future<String> _fetch(String text, String from, String to,
      {bool remember = true}) async {
    if (fake != null) {
      final out = await fake!(text, from, to);
      if (out != null && remember) {
        _cache['$to|$text'] = out;
        _outputs.add(out);
        revision.value++;
      }
      return out ?? text;
    }
    try {
      // Google's free endpoint (the one the Chrome translate bubble uses);
      // it allows calls from a web page.
      final uri = Uri.https('clients5.google.com', '/translate_a/t',
          {'client': 'dict-chrome-ex', 'sl': from, 'tl': to, 'q': text});
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        // ["translation"], or [["translation","en"]] in some versions.
        final first = data is List && data.isNotEmpty ? data.first : null;
        var out = first is String
            ? first
            : (first is List && first.isNotEmpty
                ? first.first as String
                : null);
        // Single words come back in lower case — keep the English capital.
        if (out != null &&
            out.isNotEmpty &&
            text[0].toUpperCase() == text[0] &&
            text[0].toLowerCase() != text[0]) {
          out = out[0].toUpperCase() + out.substring(1);
        }
        if (out != null && out.isNotEmpty) {
          if (remember) {
            _cache['$to|$text'] = out;
            _outputs.add(out);
            revision.value++;
          }
          return out;
        }
      }
      debugPrint('translate: HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('translate: $e');
    }
    return text;
  }

  /// Only real English words go out: not numbers, flags, the brand name or
  /// texts that already are translations.
  bool _worthSending(String text) {
    if (!RegExp('[A-Za-z]{2}').hasMatch(text)) return false;
    if (_outputs.contains(text)) return false;
    const brand = {'ShapePrompt', 'PayPal', 'MakerWorld'};
    if (brand.contains(text.trim())) return false;
    if (RegExp('[\u{1F1E6}-\u{1F1FF}]', unicode: true).hasMatch(text)) {
      return false;
    }
    return true;
  }
}

/// Short form for strings that aren't a Text widget: field labels, tooltips.
String t(String text) => TranslationService.instance.t(text);
