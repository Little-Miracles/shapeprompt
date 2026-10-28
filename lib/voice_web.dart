import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js;

/// The browser's own speech: speechSynthesis reads answers aloud (every
/// browser), SpeechRecognition turns the voice into text (Chrome, Edge,
/// Safari — not Firefox, there the mic simply isn't shown).
class Voice {
  Voice._();
  static final instance = Voice._();

  /// Our language codes → the browser's locale.
  static const _locales = {
    'en': 'en-US',
    'uk': 'uk-UA',
    'pl': 'pl-PL',
    'de': 'de-DE',
    'fr': 'fr-FR',
  };

  Object? get _recognitionClass =>
      js.getProperty(html.window, 'SpeechRecognition') ??
      js.getProperty(html.window, 'webkitSpeechRecognition');

  bool get canListen => _recognitionClass != null;
  bool get canSpeak => html.window.speechSynthesis != null;

  Object? _recognition;

  /// Bumped on every speak/stop, so a delayed start from an older call
  /// never fires.
  int _turn = 0;

  /// Reads the text aloud sentence by sentence. macOS 12's speech engine
  /// crashed Chrome (27.10) on one long text sent right after cancel():
  /// now short pieces, a pause after cancel, and silence when the system
  /// has no voice for the language.
  void speak(String text, String lang) {
    final synth = html.window.speechSynthesis;
    if (synth == null) return;
    final turn = ++_turn;
    synth.cancel();
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (turn != _turn) return;
      // Chrome fills the voice list a moment after the page opens.
      if (synth.getVoices().isEmpty) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (turn != _turn) return;
      }
      final locale = _locales[lang] ?? 'en-US';
      final voice = _voiceFor(synth, locale);
      if (voice == null) return;
      for (final piece in _pieces(text)) {
        synth.speak(html.SpeechSynthesisUtterance(piece)
          ..voice = voice
          ..lang = voice.lang ?? locale
          ..rate = 1.0);
      }
    });
  }

  html.SpeechSynthesisVoice? _voiceFor(
      html.SpeechSynthesis synth, String locale) {
    final voices = synth.getVoices();
    final lang = locale.split('-').first;
    html.SpeechSynthesisVoice? match(bool Function(String l) ok) {
      for (final v in voices) {
        final l = (v.lang ?? '').replaceAll('_', '-');
        if (ok(l)) return v;
      }
      return null;
    }

    return match((l) => l == locale) ?? match((l) => l.startsWith(lang));
  }

  /// Sentences of at most ~180 characters.
  static List<String> _pieces(String text) {
    final out = <String>[];
    for (final s in text.split(RegExp(r'(?<=[.!?…])\s+|\n+'))) {
      var rest = s.trim();
      while (rest.length > 180) {
        var cut = rest.lastIndexOf(RegExp(r'[,;—]\s'), 180);
        if (cut < 40) cut = rest.lastIndexOf(' ', 180);
        if (cut < 1) cut = 180;
        out.add(rest.substring(0, cut + 1).trim());
        rest = rest.substring(cut + 1).trim();
      }
      if (rest.isNotEmpty) out.add(rest);
    }
    return out;
  }

  void stopSpeaking() {
    _turn++;
    html.window.speechSynthesis?.cancel();
  }

  /// People pause while they think: listening ends only after this much
  /// silence, or after [_maxListen] in all (as in Smart Body Life).
  static const _pause = Duration(seconds: 5);
  static const _maxListen = Duration(seconds: 30);
  Timer? _silence;
  Timer? _limit;

  /// Bumped when listening is cancelled or started again: a late end of
  /// an older listening sends nothing.
  int _listenTurn = 0;

  /// Listens until a pause; [onPartial] shows the words while they come,
  /// [onResult] gets the whole text at the end.
  void listen(String lang,
      {required void Function(String text) onResult,
      void Function(String text)? onPartial,
      required void Function() onEnd}) {
    final cls = _recognitionClass;
    if (cls == null) {
      onEnd();
      return;
    }
    stopListening();
    final turn = ++_listenTurn;
    var heard = '';
    final r = js.callConstructor<Object>(cls, const []);
    js.setProperty(r, 'lang', _locales[lang] ?? 'en-US');
    js.setProperty(r, 'continuous', true);
    js.setProperty(r, 'interimResults', true);
    js.setProperty(r, 'maxAlternatives', 1);
    void finishAfter(Duration d) {
      _silence?.cancel();
      _silence = Timer(d, finishListening);
    }

    js.setProperty(r, 'onresult', js.allowInterop((Object e) {
      // Everything said so far: event.results[i][0].transcript
      final results = js.getProperty<Object>(e, 'results');
      final count = js.getProperty<int>(results, 'length');
      final parts = <String>[
        for (var i = 0; i < count; i++)
          js.getProperty<String>(
              js.callMethod<Object>(
                  js.callMethod<Object>(results, 'item', [i]), 'item', [0]),
              'transcript')
      ];
      heard = parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      onPartial?.call(heard);
      finishAfter(_pause);
    }));
    js.setProperty(r, 'onend', js.allowInterop((Object _) {
      _silence?.cancel();
      _limit?.cancel();
      if (identical(_recognition, r)) _recognition = null;
      if (turn == _listenTurn && heard.isNotEmpty) onResult(heard);
      onEnd();
    }));
    _recognition = r;
    js.callMethod<void>(r, 'start', const []);
    finishAfter(_pause * 2); // a little longer to start speaking
    _limit = Timer(_maxListen, finishListening);
  }

  /// Stops and sends what was heard.
  void finishListening() {
    final r = _recognition;
    if (r != null) js.callMethod<void>(r, 'stop', const []);
  }

  /// Stops without sending.
  void stopListening() {
    _listenTurn++;
    _silence?.cancel();
    _limit?.cancel();
    final r = _recognition;
    if (r != null) js.callMethod<void>(r, 'abort', const []);
    _recognition = null;
  }
}
