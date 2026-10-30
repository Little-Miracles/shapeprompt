import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide Text;
import 'package:shared_preferences/shared_preferences.dart';

import '../assistant.dart';
import '../pricing.dart';
import '../theme.dart';
import '../tr_text.dart';
import '../translation.dart';
import '../voice.dart';
import '../web_nav.dart';
import 'new_work.dart';
import 'work_detail.dart' show MadeForYouPay;

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

const _greeting = 'Hello! I\'m the little golden dragon, the host of '
    'ShapePrompt. Tell me what you\'d like and your budget: a gift or for '
    'home, shiny or matte, which color. I\'ll pick the work, material and '
    'size and prepare the order for you.';

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
  _Line(this.text,
      {required this.mine,
      this.picks = const [],
      this.custom,
      this.route,
      this.newThing});
  // The dragon's words in English (translated on screen, so another
  // language turns the whole conversation); the guest's as written.
  final String text;
  final bool mine;

  /// The orders the dragon prepared with these words.
  final List<Pick> picks;

  /// A custom request the dragon prepared with these words.
  final Custom? custom;

  /// Pages for something we have never made: 'photo', 'idea' or 'both'.
  final String? route;
  final String? newThing;

  Map<String, dynamic> toJson() => {
        'text': text,
        'mine': mine,
        'picks': [for (final p in picks) p.json],
        if (custom != null) 'custom': custom!.json,
        if (route != null) 'route': route,
        if (newThing != null) 'newThing': newThing,
      };

  static _Line fromJson(Map<String, dynamic> j) => _Line(
        j['text'] as String,
        mine: j['mine'] as bool,
        picks: [
          for (final p in j['picks'] as List? ?? const [])
            Pick(p as Map<String, dynamic>)
        ],
        custom: j['custom'] is Map<String, dynamic>
            ? Custom(j['custom'] as Map<String, dynamic>)
            : null,
        route: j['route'] as String?,
        newThing: j['newThing'] as String?,
      );
}

/// The conversation stays in this browser for a day after the last word,
/// so a guest can look at a page, come back and go on.
// v2: the dragon's lines are kept in English (v1 kept them translated).
const _chatKey = 'helperChat2';
const _chatKeeps = Duration(hours: 24);

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

  /// What was said, as sent to the brain: the dragon's lines in English.
  final _history = <({String text, bool mine})>[];

  /// The dragon's line that is still floating in, word by word.
  String _typing = '';
  List<Pick> _typingPicks = const [];
  Custom? _typingCustom;
  String? _typingRoute;
  String? _typingThing;
  bool _thinking = false;
  int _shownWords = 0;
  Timer? _wordTimer;
  bool _listening = false;

  String get _lang => TranslationService.instance.lang;
  bool get _micReady => _voice.canListen && _prefs.mic.value;

  @override
  void initState() {
    super.initState();
    _restore();
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
  Future<void> _say(String english,
      {List<Pick> picks = const [],
      Custom? custom,
      String? route,
      String? newThing}) async {
    _history.add((text: english, mine: false));
    // Waited for, so the words float in already translated.
    final text = await TranslationService.instance.translate(english);
    if (!mounted) return;
    _wordTimer?.cancel();
    _settleTyping();
    setState(() {
      _typing = english;
      _typingPicks = picks;
      _typingCustom = custom;
      _typingRoute = route;
      _typingThing = newThing;
      _shownWords = 0;
    });
    _save();
    if (_prefs.sound.value) _voice.speak(text, _lang);
    _wordTimer = Timer.periodic(const Duration(milliseconds: 140), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _shownWords++);
      _toBottom();
      if (_shownWords >= t(_typing).split(' ').length) timer.cancel();
    });
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_chatKey);
      if (raw != null) {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        final at = DateTime.fromMillisecondsSinceEpoch(saved['at'] as int);
        if (DateTime.now().difference(at) < _chatKeeps && mounted) {
          setState(() {
            _lines.addAll([
              for (final l in saved['lines'] as List)
                _Line.fromJson(l as Map<String, dynamic>)
            ]);
            _history.addAll([
              for (final h in saved['history'] as List)
                (
                  text: (h as Map<String, dynamic>)['text'] as String,
                  mine: h['mine'] as bool
                )
            ]);
          });
          _toBottom();
          return;
        }
      }
    } catch (_) {
      // A broken save: start a fresh conversation.
    }
    await prefs.remove(_chatKey);
    if (mounted) _say(_greeting);
  }

  Future<void> _save() async {
    final lines = [
      ..._lines,
      if (_typing.isNotEmpty)
        _Line(_typing,
            mine: false,
            picks: _typingPicks,
            custom: _typingCustom,
            route: _typingRoute,
            newThing: _typingThing),
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _chatKey,
        jsonEncode({
          'at': DateTime.now().millisecondsSinceEpoch,
          'lines': [for (final l in lines) l.toJson()],
          'history': [
            for (final h in _history) {'text': h.text, 'mine': h.mine}
          ],
        }));
  }

  /// Starts over: the old conversation is forgotten.
  Future<void> _newChat() async {
    _voice.stopListening();
    _voice.stopSpeaking();
    _wordTimer?.cancel();
    setState(() {
      _lines.clear();
      _history.clear();
      _typing = '';
      _typingPicks = const [];
      _typingCustom = null;
      _typingRoute = null;
      _typingThing = null;
      _thinking = false;
      _listening = false;
    });
    await (await SharedPreferences.getInstance()).remove(_chatKey);
    _say(_greeting);
  }

  /// The floating line becomes an ordinary one.
  void _settleTyping() {
    if (_typing.isNotEmpty) {
      _lines.add(_Line(_typing,
          mine: false,
          picks: _typingPicks,
          custom: _typingCustom,
          route: _typingRoute,
          newThing: _typingThing));
    }
    _typing = '';
    _typingPicks = const [];
    _typingCustom = null;
    _typingRoute = null;
    _typingThing = null;
  }

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _thinking) return;
    _field.clear();
    // Sent by hand while the mic still listens: stop it, or the same
    // words would come again after the pause.
    if (_listening) _voice.stopListening();
    _wordTimer?.cancel();
    _history.add((text: text, mine: true));
    setState(() {
      _settleTyping();
      _lines.add(_Line(text, mine: true));
      _thinking = true;
    });
    _save();
    _toBottom();
    try {
      final reply = await Assistant.instance.ask(_history);
      if (!mounted) return;
      setState(() => _thinking = false);
      await _say(reply.text,
          picks: reply.picks,
          custom: reply.custom,
          route: reply.route,
          newThing: reply.newThing);
    } on AssistantError catch (e) {
      if (!mounted) return;
      setState(() => _thinking = false);
      await _say(e.tooMany
          ? 'So many questions at once! Give me a minute, please, '
              'and ask me again.'
          : 'I can\'t think clearly right now. Please ask me again '
              'in a moment.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _thinking = false);
      await _say('I can\'t think clearly right now. Please ask me again '
          'in a moment.');
    }
  }

  /// The button to the page for something we have never made. The helper
  /// closes, so the page is seen whole.
  Widget _routes(String route, String? thing) {
    // "Puss in Boots: I have an idea". The name is translated on its own,
    // so both buttons call the thing by the same word.
    String named(String label) {
      if (thing == null) return t(label);
      final name = t(thing);
      final title =
          name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
      return '$title: ${t(label)}';
    }

    Widget go(NewWork kind, String label, IconData icon) => Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 24),
          // Filled gold with dark letters, like the pay button: an action.
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                NewWorkScreen.open(nav.context, kind, thing: thing);
              },
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: SP.metalGold,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: SP.asphaltDeep, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: m.Text(named(label),
                          style: SP.body(13.5,
                              color: SP.asphaltDeep, weight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One page takes a picture and an idea in words alike.
        go(route == 'idea' ? NewWork.idea : NewWork.photo,
            route == 'idea' ? 'Describe my idea' : 'Photo, drawing or idea',
            route == 'idea'
                ? Icons.lightbulb_outline
                : Icons.photo_camera_outlined),
      ],
    );
  }

  void _requestSent(String id) {
    _history.add((text: 'I sent the request.', mine: true));
    _say('Thank you very much! Our master has your request $id now '
        'and will write to you within 24 hours.');
  }

  void _listen() {
    if (_listening) {
      // Tapping the mic again means "that's all": send what was said.
      _voice.finishListening();
      return;
    }
    _voice.stopSpeaking();
    setState(() => _listening = true);
    _voice.listen(_lang, onPartial: (text) {
      // The words appear in the field while the guest speaks.
      if (mounted) _field.text = text;
    }, onResult: (text) {
      if (mounted) _send(text);
    }, onEnd: () {
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
    final words = t(_typing).split(' ');
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
                    for (final l in _lines) ...[
                      _bubble(l.mine ? l.text : t(l.text), mine: l.mine),
                      for (final p in l.picks) _OrderCard(pick: p),
                      if (l.custom != null)
                        _RequestCard(custom: l.custom!, onSent: _requestSent),
                      if (l.route != null) _routes(l.route!, l.newThing),
                    ],
                    if (_typing.isNotEmpty) _bubble(floating, mine: false),
                    if (_shownWords >= words.length) ...[
                      for (final p in _typingPicks) _OrderCard(pick: p),
                      if (_typingCustom != null)
                        _RequestCard(
                            custom: _typingCustom!, onSent: _requestSent),
                      if (_typingRoute != null)
                        _routes(_typingRoute!, _typingThing),
                    ],
                    if (_thinking) _bubble('…', mine: false),
                  ],
                ),
              ),
              // Examples are quiet hints, only until the guest says
              // something: they must not outshine the order.
              if (!_lines.any((l) => l.mine)) ...[
                const SizedBox(height: 12),
                Text('For example:',
                    style: SP.body(11.5).copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: 6),
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
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child:
                              Text(e, style: SP.body(11.5, color: SP.textSoft)),
                        ),
                      ),
                  ],
                ),
              ],
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
              const SizedBox(height: 10),
              const YoungDragonNote(),
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
      children: [
        TextButton.icon(
          onPressed: _newChat,
          icon: const Icon(Icons.refresh, color: SP.gold, size: 20),
          label:
              Text('New conversation', style: SP.body(12, color: SP.goldLight)),
        ),
        const Spacer(),
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

/// The order the dragon prepared: what it is, the price from the shop's
/// catalog, and the PayPal button.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.pick});
  final Pick pick;

  @override
  Widget build(BuildContext context) {
    Widget row(String what, double value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                  child: Text(what,
                      style: bold
                          ? SP.title(15, color: SP.goldLight)
                          : SP.body(12.5))),
              m.Text(zl(value),
                  style: bold
                      ? SP.title(16, color: SP.goldLight)
                      : SP.body(13, color: SP.text)),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 10, right: 24),
      padding: const EdgeInsets.all(14),
      decoration: SP.card(SP.emerald),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(pick.title, style: SP.body(12.5, color: SP.text)),
          const SizedBox(height: 6),
          row('The figurine', pick.piece),
          row('Delivery · InPost Paczkomat', pick.delivery),
          const Divider(color: Colors.white24, height: 14),
          row('Total to pay', pick.total, bold: true),
          row('incl. VAT 23%', vatOf(pick.total)),
          const SizedBox(height: 10),
          MadeForYouPay(
            label: 'Pay with PayPal · ${zl(pick.total)}',
            item: pick.item,
          ),
          const SizedBox(height: 6),
          Text('Demo mode: PayPal Sandbox. No real money is charged.',
              textAlign: TextAlign.center,
              style: SP
                  .body(10.5, color: SP.purple)
                  .copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

/// A custom request: what was asked for, an approximate price, and the
/// customer's email for the maker's answer.
class _RequestCard extends StatefulWidget {
  const _RequestCard({required this.custom, required this.onSent});
  final Custom custom;
  final ValueChanged<String> onSent;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  final _email = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  // Kept in the saved conversation, so a sent request stays sent.
  late String? _sentId = widget.custom.json['sentId'] as String?;
  String? _error;

  static final _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$');

  bool get _ready =>
      _consent && _emailShape.hasMatch(_email.text.trim()) && !_busy;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await Assistant.instance
          .sendRequest(widget.custom, _email.text.trim());
      if (!mounted) return;
      widget.custom.json['sentId'] = id;
      setState(() => _sentId = id);
      widget.onSent(id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'The request didn\'t go through. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.custom;
    Widget row(String what, double value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                  child: Text(what,
                      style: bold
                          ? SP.title(15, color: SP.goldLight)
                          : SP.body(12.5))),
              m.Text('≈ ${zl(value)}',
                  style: bold
                      ? SP.title(16, color: SP.goldLight)
                      : SP.body(13, color: SP.text)),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 10, right: 24),
      padding: const EdgeInsets.all(14),
      decoration: SP.card(SP.purple),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Special order', style: SP.title(15, color: SP.goldLight)),
          const SizedBox(height: 4),
          Text(c.title, style: SP.body(12.5, color: SP.text)),
          const SizedBox(height: 6),
          row('The figurine', c.piece),
          row('Delivery · InPost Paczkomat', c.delivery),
          const Divider(color: Colors.white24, height: 14),
          row('Total, approximately', c.total, bold: true),
          if (c.budget != null)
            Text('${t('Your budget')}: ${zl(c.budget!)}', style: SP.body(11.5)),
          const SizedBox(height: 8),
          Text(
            'Our master will check it and confirm the price by email '
            'within 24 hours.',
            style: SP.body(12, color: SP.text),
          ),
          const SizedBox(height: 10),
          if (_sentId != null)
            Text('✓ ${t('Request sent')} · $_sentId',
                style: SP.title(15, color: SP.goldLight))
          else ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              style: SP.body(13, color: SP.text),
              decoration: InputDecoration(
                hintText: t('Your email'),
                hintStyle: SP.body(13),
                filled: true,
                fillColor: SP.asphaltCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _consent = !_consent),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consent,
                    activeColor: SP.gold,
                    checkColor: SP.asphaltDeep,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'I agree that ShapePrompt keeps my email for half '
                        'a year only to answer this request and does not '
                        'give it to anyone.',
                        style: SP.body(11.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Text(_error!, style: SP.body(11.5, color: SP.goldLight)),
            const SizedBox(height: 8),
            Opacity(
              opacity: _ready ? 1 : 0.45,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: _ready ? _send : null,
                  child: Ink(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: SP.metalGold,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Center(
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: SP.asphaltDeep))
                          : Text('Send the request',
                              style: SP.title(16, color: SP.asphaltDeep)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The dragon is honest that it is still learning, and asks guests for
/// their ideas — they go to the shop's own address.
class YoungDragonNote extends StatelessWidget {
  const YoungDragonNote({super.key, this.center = false});
  final bool center;

  static const email = 'hello@craftaxi.com';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment:
            center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            'I am still a young dragon and I learn every day. Your ideas and '
            'wishes help me grow — write to us:',
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: SP.body(11.5).copyWith(fontStyle: FontStyle.italic),
          ),
          InkWell(
            onTap: () => goTo('mailto:$email'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: m.Text(email,
                  style: SP.body(12.5, color: SP.goldLight).copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: SP.goldLight)),
            ),
          ),
        ],
      );
}
