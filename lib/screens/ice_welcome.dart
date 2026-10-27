import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide Text;

import '../theme.dart';
import '../tr_text.dart';
import '../translation.dart';
import '../voice.dart';
import 'helper.dart';
import 'home.dart';

/// An old-silver plate under the dragon's words — dark letters on
/// light metal, like the dark letters on the gold cards.
const _silverPlate = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    // Old silver: warmer, a little tarnished, a softer highlight.
    Color(0xFF8E9296),
    Color(0xFFB4B7B9),
    Color(0xFFCDCFCF),
    Color(0xFFADB0B2),
    Color(0xFF85898D),
  ],
  stops: [0.0, 0.3, 0.5, 0.72, 1.0],
);

const _greeting = "Hello, let's get acquainted!";
const _meet = "I'm a little dragon, and I'm here to help.";

/// The dragon speaks for itself. Each line is a whole sentence and goes to
/// the translator on its own: sent as one block, Google loses the "!" and
/// breaks the grammar. Every phrase was checked in uk and pl. '' = a gap,
/// '• ' = a bullet.
const _script = [
  "You can talk and listen, or write and read — it's up to you.",
  '',
  "I'll help you choose your order.",
  "• I'll pick a color and material for you.",
  "• I'll find something that fits your budget.",
  "• If we don't have what you need, I'll pass your request to our "
      "workshop, and you'll get a full answer within 24 hours.",
  "• I'll gladly answer your questions.",
  '',
  'We have ready-made models, and you can order a print from us.',
  'For now we deliver within Poland only, but we plan to expand delivery.',
  '',
  "I know our site well. You can look around the site yourself, but with "
      "me it's faster.",
  "Tell me which page you need, and I'll open it.",
  '',
  'Thank you for visiting us.',
];

/// Shows the ice welcome once, on the first visit.
void showIceWelcomeOnce(BuildContext context) {
  final prefs = HelperPrefs.instance;
  if (prefs.introSeen) return;
  prefs.markIntroSeen();
  showIceWelcome(context);
}

/// The ice welcome — on the first visit and from "Read & listen again".
void showIceWelcome(BuildContext context) {
  showGeneralDialog<HelperStart>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, __, ___) => const _IceWelcome(),
    transitionBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
  ).then((start) {
    Voice.instance.stopSpeaking();
    helperFlash.value++;
    if (start != null && start != HelperStart.look && context.mounted) {
      showHelper(context, start: start);
    }
  });
}

/// Frosted ice over the screen: the page shows through, blurred, and the
/// welcome types itself on top.
class _IceWelcome extends StatefulWidget {
  const _IceWelcome();

  @override
  State<_IceWelcome> createState() => _IceWelcomeState();
}

class _IceWelcomeState extends State<_IceWelcome> {
  static final _english = _script.join('\n');

  String _text = '';
  int _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start(first: true);
  }

  /// Translates the welcome line by line into the chosen language, types
  /// it out and, if the sound is on, reads it aloud. Runs again when the
  /// language changes.
  Future<void> _start({bool first = false}) async {
    _timer?.cancel();
    Voice.instance.stopSpeaking();
    _text = '';
    _shown = 0;
    if (!first) setState(() {});
    final tr = TranslationService.instance;
    final lang = tr.lang;
    final out = await Future.wait([
      for (final l in _script)
        l.startsWith('• ')
            ? tr.translate(l.substring(2)).then((t) => '• $t')
            : tr.translate(l),
    ]);
    if (!mounted || lang != tr.lang) return;
    _text = out.join('\n');
    if (HelperPrefs.instance.sound.value) _readAloud();
    _timer = Timer.periodic(const Duration(milliseconds: 12), (t) {
      if (!mounted || _shown >= _text.length) return t.cancel();
      setState(() => _shown++);
    });
  }

  Future<void> _readAloud() async {
    final tr = TranslationService.instance;
    final lang = tr.lang;
    final hello =
        await Future.wait([tr.translate(_greeting), tr.translate(_meet)]);
    if (!mounted || lang != tr.lang || _text.isEmpty) return;
    // Bullets read as pauses, not as "bullet".
    Voice.instance
        .speak('${hello.join(' ')}\n${_text.replaceAll('• ', '')}', lang);
  }

  /// 🔊 / 🔇 — the same switch as in the dragon's window: off stops the
  /// voice at once, on reads the welcome from the start.
  void _toggleSound() {
    final sound = HelperPrefs.instance.sound;
    sound.value = !sound.value;
    if (sound.value) {
      _readAloud();
    } else {
      Voice.instance.stopSpeaking();
    }
    setState(() {});
  }

  void _pick(String code) {
    TranslationService.instance.setLang(code);
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The same Cormorant as the home screen titles, light and in silver:
    // the welcome belongs to this screen, like the dragon.
    final body = homeHeading(18, color: SP.asphaltDeep)
        .copyWith(fontWeight: FontWeight.w600, height: 1.3);
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  // Ice over dark asphalt: a cold tint, brighter at the top
                  // edge, dark enough underneath for white letters.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFDDEEFF).withOpacity(0.16),
                      SP.asphaltDeep.withOpacity(0.55),
                    ],
                  ),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.45), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.35), blurRadius: 30),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _languages(),
                    const SizedBox(height: 10),
                    Image.asset('assets/helper/dragon_head.png', height: 60),
                    const SizedBox(height: 6),
                    ShaderMask(
                      shaderCallback: (r) => SP.metalGold.createShader(r),
                      child: Text(_greeting,
                          textAlign: TextAlign.center,
                          style: homeHeading(28, color: Colors.white)),
                    ),
                    Text(_meet,
                        textAlign: TextAlign.center, style: homeHeading(20)),
                    const SizedBox(height: 12),
                    // Keeps its full height from the start, so the text
                    // doesn't jump while it types itself; scrolls on
                    // small phones.
                    Container(
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.42),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        gradient: _silverPlate,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF5F6366), width: 1.2),
                      ),
                      child: SingleChildScrollView(
                        child: Stack(
                          children: [
                            Opacity(
                              opacity: 0,
                              child: m.Text(_text.isEmpty ? _english : _text,
                                  style: body),
                            ),
                            m.Text(_text.substring(0, _shown), style: body),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (Voice.instance.canListen) ...[
                          Expanded(
                            child: _IceButton(
                              icon: Icons.mic,
                              label: 'Talk',
                              onTap: () =>
                                  Navigator.pop(context, HelperStart.talk),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _IceButton(
                            icon: Icons.edit,
                            label: 'Write',
                            onTap: () =>
                                Navigator.pop(context, HelperStart.type),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, HelperStart.look),
                      child: Text('Not now',
                          style: SP.body(13.5, color: richGold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Language first, so the welcome is read in your own. Letters, not
  /// flags: the browser draws flag emoji as plain boxes.
  Widget _languages() {
    final current = TranslationService.instance.lang;
    // Wraps on narrow phones instead of running off the edge.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: [
        for (final (code, _, name) in TranslationService.languages)
          Tooltip(
            message: name,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _pick(code),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: code == current ? SP.metalGold : null,
                  border: Border.all(color: richGold.withOpacity(0.6)),
                ),
                child: m.Text(
                  code == 'uk' ? 'UA' : code.toUpperCase(),
                  style: homeHeading(16,
                      color: code == current ? SP.asphaltDeep : richGold),
                ),
              ),
            ),
          ),
        if (Voice.instance.canSpeak) _soundButton(),
      ],
    );
  }

  Widget _soundButton() {
    final on = HelperPrefs.instance.sound.value;
    return Tooltip(
      message: t(on ? 'Sound on' : 'Sound off — just read'),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _toggleSound,
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: on ? SP.metalGold : null,
            border: Border.all(color: richGold.withOpacity(0.6)),
          ),
          child: Icon(on ? Icons.volume_up : Icons.volume_off,
              size: 20, color: on ? SP.asphaltDeep : richGold),
        ),
      ),
    );
  }
}

/// Metallic gold, like the "Ready works" card.
class _IceButton extends StatelessWidget {
  const _IceButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        // Its own Material: otherwise the gold ink paints underneath the
        // ice tint and looks dull.
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Ink(
            height: 50,
            decoration: const ShapeDecoration(
              gradient: SP.metalGold,
              shape: StadiumBorder(
                  side: BorderSide(color: Color(0xFF5E4520), width: 1.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: SP.asphaltDeep, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: homeHeading(21, color: SP.asphaltDeep)),
                ),
              ],
            ),
          ),
        ),
      );
}
