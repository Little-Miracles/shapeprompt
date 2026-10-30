import 'dart:typed_data';

import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide Text;

import '../assistant.dart';
import '../catalog.dart';
import '../photo_pick.dart';
import '../pricing.dart';
import '../theme.dart';
import 'portfolio.dart';
import 'terms.dart';
import 'unsent.dart';
import 'work_detail.dart' show PayButton;
import '../tr_text.dart';
import '../translation.dart';

/// "Photo, drawing or idea": the guest shows a picture (the dragon fills
/// in the order card) or just describes the idea in words, checks the card
/// and sends it to the master. The master answers with a price by email.
class PhotoOrderScreen extends StatefulWidget {
  const PhotoOrderScreen({super.key, this.thing});

  /// What the guest asked the dragon for, if they came from the chat.
  final String? thing;

  @override
  State<PhotoOrderScreen> createState() => _PhotoOrderScreenState();
}

class _PhotoOrderScreenState extends State<PhotoOrderScreen>
    with RebuildOnTranslation {
  Uint8List? _photo;
  bool _reading = false;
  bool _filled = false;
  String? _dragonSays; // already in the reader's language
  String? _dragonSaysEn; // a fallback line in English, translated on screen
  int _figures = 1;
  String? _quality;
  List<int> _blurred = const []; // figures whose face or hands are blurred
  bool _blurOk = false; // the guest saw the warning and sends it anyway
  String? _forbidden; // the picture shows what we never make: no card
  String? _complexity;
  bool _brand = false;

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _height = TextEditingController();
  final _color = TextEditingController();
  final _wishes = TextEditingController();
  final _email = TextEditingController();
  String? _material;
  String? _colorChip; // one of the material's colors, or null for the text
  String? _pick; // which figure, when the picture has several
  String _base = 'master';
  String? _copies; // 'allowed' or 'exclusive'
  bool _portfolio = false;
  bool _rights = false;
  bool _consent = false;
  bool _sending = false;
  String? _sentId;
  String? _error;

  static final _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$');

  @override
  void initState() {
    super.initState();
    if (widget.thing != null) _name.text = t(widget.thing!);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _height,
      _color,
      _wishes,
      _email
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Without a picture the words are all our master has, so the
  /// description must say something.
  bool get _ready =>
      (_photo != null || _description.text.trim().length >= 10) &&
      _name.text.trim().isNotEmpty &&
      _emailShape.hasMatch(_email.text.trim()) &&
      (_photo == null || _rights) &&
      (_photo == null || _quality != 'poor' || _blurOk) &&
      _forbidden == null &&
      _copies != null &&
      _portfolio &&
      _consent &&
      !_sending;

  Future<void> _choose() async {
    final photo = await pickPhoto();
    if (photo == null || !mounted) return;
    setState(() {
      _photo = photo;
      _reading = true;
      _filled = false;
      _error = null;
      _dragonSays = null;
      _dragonSaysEn = null;
      // A new picture: the old card goes.
      for (final c in [_description, _height, _color]) {
        c.clear();
      }
      if (widget.thing == null) _name.clear();
      _material = null;
      _colorChip = null;
      _pick = null;
      _complexity = null;
      _brand = false;
      _figures = 1;
      _quality = null;
      _blurred = const [];
      _blurOk = false;
      _forbidden = null;
    });
    try {
      // The dragon writes the card in the guest's own language; every
      // line can be changed.
      final r = await Assistant.instance.readPhoto(
          photo, widget.thing ?? '', TranslationService.instance.lang);
      final c = r.card;
      if (!mounted) return;
      if (r.forbidden != null || c == null) {
        setState(() {
          _forbidden = r.forbidden ?? 'other';
          _dragonSays = r.reply.isEmpty ? null : r.reply;
          _dragonSaysEn = r.reply.isEmpty
              ? 'I can\'t take this picture: our workshop doesn\'t make '
                  'such things. Please read what we never make in the order '
                  'terms.'
              : null;
        });
        return;
      }
      setState(() {
        _dragonSays = r.reply;
        if (widget.thing == null || _name.text.isEmpty) {
          _name.text = c['name'] as String? ?? '';
        }
        _description.text = c['description'] as String? ?? '';
        _height.text = c['heightCm'] == null ? '' : '${c['heightCm']}';
        _material = c['material'] as String?;
        _color.text = c['color'] as String? ?? '';
        _colorChip = _materialColors
            .where((n) => n.toLowerCase() == _color.text.trim().toLowerCase())
            .firstOrNull;
        if (_colorChip != null) _color.clear();
        _complexity = c['complexity'] as String?;
        _brand = c['brand'] == true;
        _figures = (c['figures'] as num?)?.toInt() ?? 1;
        _quality = c['quality'] as String?;
        _blurred = [
          for (final n in (c['blurred'] as List? ?? [])) (n as num).toInt()
        ];
      });
    } on AssistantError catch (e) {
      if (!mounted) return;
      if (e.blocked) {
        setState(() {
          _forbidden = 'blocked';
          _dragonSaysEn = 'We can\'t take orders from you. If you think '
              'this is a mistake, write to hello@craftaxi.com.';
        });
        return;
      }
      setState(() => _dragonSaysEn = e.tooMany
          ? 'I\'m resting for a moment. Please fill in the card yourself, '
              'our master will see everything.'
          : 'I couldn\'t look at the picture just now. Please fill in the '
              'card yourself, our master will see everything.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _dragonSaysEn = ('I couldn\'t look at the picture just '
          'now. Please fill in the card yourself, our master will see '
          'everything.'));
    } finally {
      if (mounted) {
        setState(() {
          _reading = false;
          _filled = true;
        });
      }
    }
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final id = await Assistant.instance.sendPhotoRequest(
          _photo,
          {
            'name': _name.text,
            'description': _description.text,
            'heightCm': int.tryParse(_height.text.trim()),
            'material': _material,
            'color': _colorChip ?? _color.text,
            'complexity': _complexity,
            'brand': _brand,
            'figures': _figures,
            'quality': _quality,
            'blurred': _blurred,
            'blurAccepted': _blurOk,
            'wishes': _wishes.text,
            'pick': _figures > 1 ? (_pick ?? 'not chosen') : '',
            'base': _base,
            'copies': _copies,
          },
          _email.text.trim());
      // Remembered until paid: leaving PayPal must not lose it.
      await Unsent.save(id, _name.text.trim());
      if (mounted) setState(() => _sentId = id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is AssistantError && e.blocked
            ? t('We can\'t take orders from you. If you think this is a '
                'mistake, write to hello@craftaxi.com.')
            : e is AssistantError && e.forbidden
            ? t('We can\'t take this request: our workshop never makes '
                'weapons, drones, explosives and other things listed in the '
                'order terms.')
            : t('The request didn\'t go through. Please try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SPScaffold(
      helper: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        children: [
          const BackRow(),
          Text('Photo, drawing or idea',
              textAlign: TextAlign.center, style: SP.title(24)),
          if (widget.thing != null) ...[
            const SizedBox(height: 8),
            Text(widget.thing!,
                textAlign: TextAlign.center,
                style: SP.title(19, color: SP.goldLight)),
          ],
          const SizedBox(height: 14),
          if (_sentId != null) ..._sent() else ..._form(),
        ],
      ),
    );
  }

  /// One step left: the request reaches our master with the deposit.
  List<Widget> _sent() => [
        const SizedBox(height: 20),
        const Icon(Icons.check_circle_outline, size: 64, color: SP.gold),
        const SizedBox(height: 14),
        m.Text('${t('Request saved')} · $_sentId',
            textAlign: TextAlign.center,
            style: SP.title(20, color: SP.goldLight)),
        const SizedBox(height: 6),
        Text('⚠ Not sent to our master yet',
            textAlign: TextAlign.center,
            style: SP.title(17, color: SP.gold)),
        const SizedBox(height: 10),
        Text(
          'Step 2 of 2: the 15 zł deposit. With it your request goes to '
          'our master, who writes to you within 24 hours with the price. '
          'The deposit counts toward the price; it is returned only if our '
          'master declines before starting work.',
          textAlign: TextAlign.center,
          style: SP.body(14, color: SP.text),
        ),
        const SizedBox(height: 18),
        PayButton(
          label: 'Pay the deposit with PayPal · ${zl(15)}',
          item: {'deposit': _sentId!},
        ),
        const SizedBox(height: 8),
        Text('Not paid within 48 hours, the request is deleted.',
            textAlign: TextAlign.center, style: SP.body(11.5)),
        const SizedBox(height: 4),
        Text('Demo mode: PayPal Sandbox. No real money is charged.',
            textAlign: TextAlign.center,
            style: SP
                .body(11, color: SP.purple)
                .copyWith(fontStyle: FontStyle.italic)),
      ];

  List<Widget> _form() => [
        Text(
          'Show a picture — a photo, or even a drawing by hand — and I will '
          'fill in the order card for you. No picture? Just describe your '
          'idea in words below. Our master will answer within 24 hours.',
          textAlign: TextAlign.center,
          style: SP.body(13.5, color: SP.text),
        ),
        const SizedBox(height: 14),
        const PortfolioButton(),
        const SizedBox(height: 18),
        _picture(),
        const SizedBox(height: 10),
        Text(
          'We are a creative workshop: our master designs and makes things '
          'from your idea. We don\'t print ready-made 3D files, so please '
          'don\'t send STL files.',
          textAlign: TextAlign.center,
          style: SP.body(11.5).copyWith(fontStyle: FontStyle.italic),
        ),
        if (_reading) ...[
          const SizedBox(height: 16),
          const Center(
              child:
                  CircularProgressIndicator(color: SP.gold, strokeWidth: 2.5)),
          const SizedBox(height: 8),
          Text('The dragon is looking at the picture…',
              textAlign: TextAlign.center, style: SP.body(12.5)),
        ],
        if (_filled &&
            (_dragonSays != null || _dragonSaysEn != null)) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SP.asphaltCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SP.gold.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/helper/dragon_head.png', width: 40),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _dragonSays != null
                          ? m.Text(_dragonSays!,
                              style: SP.body(13, color: SP.text))
                          : Text(_dragonSaysEn!,
                              style: SP.body(13, color: SP.text))),
                ],
              ),
            ),
        ],
        if (!_reading && _forbidden == null) ...[
          const SizedBox(height: 18),
          ..._card(),
        ],
        if (_forbidden != null) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => TermsScreen.open(context),
              child: Text('Read the order terms',
                  style: SP.body(13, color: SP.gold, weight: FontWeight.w600)),
            ),
          ),
        ],
      ];

  Widget _picture() {
    final photo = _photo;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _reading ? null : _choose,
      child: Container(
        height: photo == null ? 170 : null,
        decoration: BoxDecoration(
          color: SP.asphaltCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SP.gold.withOpacity(0.6)),
        ),
        child: photo == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined,
                      size: 52, color: SP.gold),
                  const SizedBox(height: 10),
                  Text('Add a picture',
                      style: SP.title(17, color: SP.goldLight)),
                  const SizedBox(height: 4),
                  Text('optional', style: SP.body(12)),
                ],
              )
            : Column(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(19)),
                    child: ColoredBox(
                      color: Colors.white,
                      child: Image.memory(photo,
                          height: 260,
                          width: double.infinity,
                          fit: BoxFit.contain),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('Choose another picture',
                        style: SP.body(12.5, color: SP.goldLight)),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _card() => [
        Text('Order card', style: SP.title(18, color: SP.goldLight)),
        const SizedBox(height: 10),
        _field('What is it', _name),
        _field(
            _photo == null
                ? 'Describe it: shape, details, pose'
                : 'Description',
            _description,
            lines: 4),
        _field('Height, cm (5–25)', _height, number: true),
        _label('Material'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mat in materials.values)
              ChoiceChip(
                label: m.Text(mat.name),
                selected: _material == mat.id,
                onSelected: (_) => setState(() {
                  _material = mat.id;
                  if (!_materialColors.contains(_colorChip)) _colorChip = null;
                }),
                selectedColor: SP.gold,
                backgroundColor: SP.asphaltCard,
                labelStyle: SP.body(12.5,
                    color: _material == mat.id ? SP.asphaltDeep : SP.goldLight),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _label('One color for the figure'),
        if (_materialColors.isNotEmpty) ...[
          _chips({for (final n in _materialColors) n: n}, _colorChip,
              // One color at a time: a chip empties the "another color" line.
              (v) => setState(() {
                    _colorChip = v;
                    _color.clear();
                  })),
          const SizedBox(height: 10),
        ],
        _field(
            _materialColors.isEmpty
                ? 'Color'
                : 'Or another color (our master will check if we have it)',
            _color),
        if (_figures > 1) ...[
          _label('There are $_figures figures. Which one to make?'),
          _chips({
            for (var i = 1; i <= _figures; i++) '$i': '$i',
            'all': 'All of them',
          }, _pick, (v) => setState(() => _pick = v)),
          const SizedBox(height: 12),
        ],
        _label('Base'),
        _chips(const {
          'round': 'On a round base',
          'none': 'No base',
          'master': 'Our master decides',
        }, _base, (v) => setState(() => _base = v)),
        const SizedBox(height: 12),
        if (_quality == 'poor')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _blurred.isEmpty
                  ? 'Some parts of the picture are blurred or hard to see. A '
                      'clearer picture will help our master see the details.'
                  : 'Blurred: figure ${_blurred.join(', ')}. A clearer '
                      'picture will help our master see the face and hands.',
              style: SP.body(12.5, color: SP.goldLight),
            ),
          ),
        if (_quality == 'poor' && _photo != null)
          _check(
              _blurOk,
              (v) => setState(() => _blurOk = v),
              'I see that the picture is not sharp. Our master will model '
              'what can be seen, or ask for another picture.'),
        if (_complexity != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              {
                'simple': 'The dragon thinks: a simple shape.',
                'medium': 'The dragon thinks: a medium amount of detail.',
                'detailed': 'The dragon thinks: many small details.',
              }[_complexity]!,
              style: SP.body(12).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        _field('Your wishes', _wishes, lines: 3),
        if (_brand)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'This looks like a character or logo that belongs to a '
              'company. Our master can\'t print it as it is, but can make '
              'something in a similar spirit.',
              style: SP.body(12.5, color: SP.goldLight),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SP.purple.withOpacity(0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('What to expect',
                  style: SP.title(14, color: SP.gold)),
              const SizedBox(height: 4),
              Text(
                'We print with plastic filament, layer by layer — not with '
                'resin. Small details like wrinkles on a face, fingers or '
                'thin herbs come out simpler than in the picture. Thin parts, '
                'like a spoon, may be printed separately and glued on. For '
                'now a figurine is printed in one color, without painting; '
                'printing in up to four colors is coming soon.',
                style: SP.body(12.5, color: SP.text),
              ),
              const SizedBox(height: 10),
              Text('You see it before it is printed',
                  style: SP.title(14, color: SP.gold)),
              const SizedBox(height: 4),
              Text(
                'You send the request with a 15 zł deposit: it pays for '
                'looking at your request and making the 3D model. Our master '
                'answers within 24 hours with the price, makes the model and '
                'sends you 2–3 pictures of it from different sides, exactly '
                'as it will be printed. You like it — you order the print, '
                'and the deposit counts toward it. You don\'t — you pay '
                'nothing more. The deposit is returned only if our master '
                'declines before starting work.',
                style: SP.body(12.5, color: SP.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => TermsScreen.open(context),
            child: Text('Read the order terms',
                style: SP.body(13, color: SP.gold, weight: FontWeight.w600)),
          ),
        ),
        Text(
            'We don\'t print film, cartoon or game heroes and logos that '
            'belong to companies, weapons, drones or explosives.',
            style: SP.body(11.5).copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: 14),
        _field('Your email', _email, email: true),
        _label('Copies of your figure'),
        _radio('allowed',
            'Our master may sell copies — I get 10% off my next figurine'),
        _radio('exclusive', 'Only for me — exclusive, +25–50% to the price'),
        const SizedBox(height: 4),
        Text(
            'For an exclusive figure, our master names the exact price in '
            'the answer: it depends on the figure.',
            style: SP.body(11.5).copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        if (_photo != null)
          _check(
              _rights,
              (v) => setState(() => _rights = v),
              'This is my own picture, or I have the right to use it for a '
              'figure.'),
        _check(
            _portfolio,
            (v) => setState(() => _portfolio = v),
            'Photos of the finished figure, with the ShapePrompt watermark, '
            'may appear in the portfolio of our master.'),
        _check(
            _consent,
            (v) => setState(() => _consent = v),
            'I agree that ShapePrompt keeps my email and picture for 90 days '
            'only to answer this request and does not give them to anyone.'),
        if (_error != null) ...[
          const SizedBox(height: 6),
          m.Text(_error!, style: SP.body(12, color: SP.goldLight)),
        ],
        const SizedBox(height: 12),
        Opacity(
          opacity: _ready ? 1 : 0.45,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: _ready ? _send : null,
              child: Ink(
                height: 54,
                decoration: BoxDecoration(
                  gradient: SP.metalGold,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: _sending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: SP.asphaltDeep))
                      : Text('Step 1 of 2: save my request',
                          style: SP.title(17, color: SP.asphaltDeep)),
                ),
              ),
            ),
          ),
        ),
      ];

  List<String> get _materialColors =>
      [for (final c in materials[_material]?.colors ?? []) c.name];

  /// One choice out of a few, in the same gold chips as the materials.
  Widget _chips(Map<String, String> options, String? selected,
          ValueChanged<String> onSelected) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in options.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: selected == e.key,
              onSelected: (_) => onSelected(e.key),
              selectedColor: SP.gold,
              backgroundColor: SP.asphaltCard,
              labelStyle: SP.body(12.5,
                  color: selected == e.key ? SP.asphaltDeep : SP.goldLight),
            ),
        ],
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: SP.title(14, color: SP.gold)),
      );

  Widget _field(String label, TextEditingController c,
          {int lines = 1, bool number = false, bool email = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(label),
            TextField(
              controller: c,
              minLines: lines,
              maxLines: lines,
              keyboardType: number
                  ? TextInputType.number
                  : email
                      ? TextInputType.emailAddress
                      : TextInputType.text,
              onChanged: (_) => setState(() {
                // A color written by hand takes the place of the chip.
                if (c == _color && c.text.trim().isNotEmpty) _colorChip = null;
              }),
              style: SP.body(13.5, color: SP.text),
              decoration: InputDecoration(
                filled: true,
                fillColor: SP.asphaltCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _radio(String value, String text) => InkWell(
        onTap: () => setState(() => _copies = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                  _copies == value
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: SP.gold,
                  size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: SP.body(12.5,
                        color: _copies == value ? SP.goldLight : SP.text)),
              ),
            ],
          ),
        ),
      );

  Widget _check(bool value, ValueChanged<bool> onChanged, String text) =>
      InkWell(
        onTap: () => onChanged(!value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              activeColor: SP.gold,
              checkColor: SP.asphaltDeep,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(text, style: SP.body(12)),
              ),
            ),
          ],
        ),
      );
}
