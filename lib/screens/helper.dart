import 'dart:async';

import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide Text;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../tr_text.dart';
import '../translation.dart';
import '../voice.dart';

/// The helper's switches, remembered between visits: mic (talk or type),
/// sound (answers read aloud or only shown) and whether the ice welcome
/// has been seen.
class HelperPrefs {
  HelperPrefs._();
  static final instance = HelperPrefs._();

  final mic = ValueNotifier<bool>(true);
  final sound = ValueNotifier<bool>(true);
  bool introSeen = false;
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    mic.value = _prefs!.getBool('helperMic') ?? true;
    sound.value = _prefs!.getBool('helperSound') ?? true;
    introSeen = _prefs!.getBool('helperIntroSeen') ?? false;
    mic.addListener(() => _prefs?.setBool('helperMic', mic.value));
    sound.addListener(() => _prefs?.setBool('helperSound', sound.value));
  }

  void markIntroSeen() {
    introSeen = true;
    _prefs?.setBool('helperIntroSeen', true);
  }
}

/// Bumped when the ice welcome closes: the dragon in the corner flashes
/// gold so the eye finds it.
final helperFlash = ValueNotifier<int>(0);

/// The little golden dragon in the corner. Tap → the helper window.
class HelperButton extends StatefulWidget {
  const HelperButton({super.key, this.size = 72});

  /// Small in the corner of ordinary screens, big on the home screen.
  final double size;

  @override
  State<HelperButton> createState() => _HelperButtonState();
}

class _HelperButtonState extends State<HelperButton>
    with TickerProviderStateMixin {
  // A slow bob up and down, so the dragon looks alive.
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  void _onFlash() => _flash.forward(from: 0);

  @override
  void initState() {
    super.initState();
    helperFlash.addListener(_onFlash);
  }

  @override
  void dispose() {
    helperFlash.removeListener(_onFlash);
    _bob.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bob, _flash]),
      builder: (context, child) {
        // Two soft gold pulses after the welcome closes.
        final f = _flash.isAnimating
            ? (1 -
                    (2 * _flash.value - (2 * _flash.value).floor() - 0.5)
                            .abs() *
                        2)
                .clamp(0.0, 1.0)
            : 0.0;
        return Transform.translate(
          offset: Offset(0, -4 * _bob.value),
          child: Transform.scale(
            scale: 1 + 0.18 * f,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: SP.goldLight.withOpacity(0.8 * f),
                      blurRadius: 30 * f,
                      spreadRadius: 6 * f),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: Tooltip(
        message: 'Your ShapePrompt helper',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showHelper(context),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SP.asphaltDeep,
              border: Border.all(color: SP.gold, width: 1.6),
              boxShadow: [
                BoxShadow(color: SP.gold.withOpacity(0.35), blurRadius: 16),
              ],
            ),
            padding: EdgeInsets.all(widget.size / 12),
            child: Image.asset('assets/helper/dragon_head.png'),
          ),
        ),
      ),
    );
  }
}

const _examples = [
  'A shiny dragon as a gift, up to 100 zł',
  'Something for my desk, matte black',
  'Which material is best for a flower pot?',
];

const _greeting = 'Hi! I\'m your ShapePrompt helper. Tell me what you\'d like '
    'and your budget — a gift or for home, shiny or matte, which color. '
    'I\'ll pick the work, material and size, and prepare the order for you.';

/// How the window opens: just to look, ready to listen, or ready to type.
enum HelperStart { look, talk, type }

Future<void> showHelper(BuildContext context,
    {HelperStart start = HelperStart.look}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _HelperSheet(start: start),
  ).whenComplete(Voice.instance.stopSpeaking);
}

class _Line {
  _Line(this.text, {required this.mine});
  final String text; // already in the reader's language
  final bool mine;
}

class _HelperSheet extends StatefulWidget {
  const _HelperSheet({required this.start});
  final HelperStart start;

  @override
  State<_HelperSheet> createState() => _HelperSheetState();
}

class _HelperSheetState extends State<_HelperSheet> with RebuildOnTranslation {
  final _prefs = HelperPrefs.instance;
  final _voice = Voice.instance;
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _lines = <_Line>[];

  /// The dragon's line that is still floating in, word by word.
  String _typing = '';
  int _shownWords = 0;
  Timer? _wordTimer;
  bool _listening = false;

  String get _lang => TranslationService.instance.lang;
  bool get _micReady => _voice.canListen && _prefs.mic.value;

  @override
  void initState() {
    super.initState();
    _say(_greeting);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.start == HelperStart.talk && _micReady) {
        _listen();
      } else if (widget.start == HelperStart.type ||
          widget.start == HelperStart.talk) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _wordTimer?.cancel();
    _voice.stopListening();
    _field.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The dragon answers: the words float in one by one, and if the sound
  /// is on it reads the answer aloud at the same time.
  Future<void> _say(String english) async {
    final text = await TranslationService.instance.translate(english);
    if (!mounted) return;
    _wordTimer?.cancel();
    if (_typing.isNotEmpty) _lines.add(_Line(_typing, mine: false));
    final words = text.split(' ');
    setState(() {
      _typing = text;
      _shownWords = 0;
    });
    if (_prefs.sound.value) _voice.speak(text, _lang);
    _wordTimer = Timer.periodic(const Duration(milliseconds: 140), (t) {
      if (!mounted) return t.cancel();
      setState(() => _shownWords++);
      _toBottom();
      if (_shownWords >= words.length) t.cancel();
    });
  }

  void _send(String text) {
    text = text.trim();
    if (text.isEmpty) return;
    _field.clear();
    setState(() {
      if (_typing.isNotEmpty) _lines.add(_Line(_typing, mine: false));
      _typing = '';
      _lines.add(_Line(text, mine: true));
    });
    _toBottom();
    // The real answers (Gemini, the order, PayPal) come in the next step;
    // for now the dragon shows that it heard.
    _say('I heard you! Soon I will find the right work, color and price '
        'for this and prepare the order. My brain arrives in the next '
        'build step, together with PayPal.');
  }

  void _listen() {
    if (_listening) {
      _voice.stopListening();
      return;
    }
    _voice.stopSpeaking();
    setState(() => _listening = true);
    _voice.listen(_lang, onResult: _send, onEnd: () {
      if (mounted) setState(() => _listening = false);
    });
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });

  @override
  Widget build(BuildContext context) {
    final words = _typing.split(' ');
    final floating = words.take(_shownWords).join(' ');
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, 10, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: SP.asphalt,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: SP.gold.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _switches(),
              Flexible(
                child: ListView(
                  controller: _scroll,
                  shrinkWrap: true,
                  children: [
                    const _DragonWithSign(),
                    const SizedBox(height: 12),
                    for (final l in _lines) _bubble(l.text, mine: l.mine),
                    if (_typing.isNotEmpty) _bubble(floating, mine: false),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _examples)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _send(t(e)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: SP.emerald.withOpacity(0.7)),
                        ),
                        child: Text(e, style: SP.body(12, color: SP.goldLight)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _field,
                      focusNode: _focus,
                      onSubmitted: _send,
                      style: SP.body(13, color: SP.text),
                      decoration: InputDecoration(
                        hintText: _listening
                            ? t('Listening… speak now')
                            : t('Write your wish…'),
                        hintStyle: SP.body(13),
                        filled: true,
                        fillColor: SP.asphaltCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          tooltip: t('Send'),
                          icon: const Icon(Icons.send_rounded, color: SP.gold),
                          onPressed: () => _send(_field.text),
                        ),
                      ),
                    ),
                  ),
                  if (_micReady) ...[
                    const SizedBox(width: 8),
                    _MicButton(listening: _listening, onTap: _listen),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🎙 and 🔊 at the top: each can be turned off.
  Widget _switches() {
    Widget toggle(ValueNotifier<bool> v, IconData on, IconData off,
            String tipOn, String tipOff) =>
        ValueListenableBuilder<bool>(
          valueListenable: v,
          builder: (_, isOn, __) => IconButton(
            tooltip: t(isOn ? tipOn : tipOff),
            icon: Icon(isOn ? on : off,
                color: isOn ? SP.gold : SP.textSoft.withOpacity(0.5)),
            onPressed: () {
              v.value = !isOn;
              if (!v.value) {
                _voice.stopSpeaking();
                _voice.stopListening();
              }
              setState(() {});
            },
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_voice.canListen)
          toggle(_prefs.mic, Icons.mic, Icons.mic_off, 'Microphone on',
              'Microphone off — type instead'),
        if (_voice.canSpeak)
          toggle(_prefs.sound, Icons.volume_up, Icons.volume_off,
              'Sound on — I read answers aloud', 'Sound off — just read'),
      ],
    );
  }

  /// Texts here are already in the reader's language — plain Text.
  Widget _bubble(String text, {required bool mine}) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: mine ? SP.emeraldDeep.withOpacity(0.55) : SP.asphaltCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: (mine ? SP.emerald : SP.gold).withOpacity(0.4)),
          ),
          child: m.Text(text, style: SP.body(13, color: SP.text)),
        ),
      );
}

/// The round mic: gold when waiting, pulsing emerald while it listens.
class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: t(listening ? 'Stop listening' : 'Talk'),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: listening ? null : SP.goldGradient,
              color: listening ? SP.emerald : null,
              boxShadow: [
                if (listening)
                  BoxShadow(
                      color: SP.emerald.withOpacity(0.7),
                      blurRadius: 18,
                      spreadRadius: 3),
              ],
            ),
            child: Icon(listening ? Icons.graphic_eq : Icons.mic,
                color: SP.asphaltDeep),
          ),
        ),
      );
}

/// The dragon holding its sign, with a greeting written on the sign.
class _DragonWithSign extends StatelessWidget {
  const _DragonWithSign();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 230,
        child: AspectRatio(
          aspectRatio: 671 / 700,
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Positioned.fill(
                    child: Image.asset('assets/helper/dragon_sign.png')),
                // The white sign sits at about 52–97% across, 47–72% down.
                Positioned(
                  left: box.maxWidth * 0.53,
                  top: box.maxHeight * 0.48,
                  width: box.maxWidth * 0.43,
                  height: box.maxHeight * 0.23,
                  child: Center(
                    child: Text(
                      'Hi! Let me\nhelp you choose',
                      textAlign: TextAlign.center,
                      style: SP.title(12, color: SP.asphaltDeep),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
