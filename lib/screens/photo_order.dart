import 'dart:typed_data';

import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide Text;

import '../assistant.dart';
import '../catalog.dart';
import '../photo_pick.dart';
import '../theme.dart';
import '../tr_text.dart';
import '../translation.dart';

/// "I have a photo or drawing": the guest shows a picture, the dragon fills
/// in the order card, the guest checks it and sends it to the master with
/// the picture attached. The master answers with a price by email.
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
  String? _complexity;
  bool _brand = false;

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _height = TextEditingController();
  final _color = TextEditingController();
  final _wishes = TextEditingController();
  final _email = TextEditingController();
  String? _material;
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
    for (final c in [_name, _description, _height, _color, _wishes, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ready =>
      _photo != null &&
      _name.text.trim().isNotEmpty &&
      _emailShape.hasMatch(_email.text.trim()) &&
      _rights &&
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
      _complexity = null;
      _brand = false;
      _figures = 1;
      _quality = null;
    });
    try {
      // The dragon writes the card in the guest's own language; every
      // line can be changed.
      final r = await Assistant.instance.readPhoto(
          photo, widget.thing ?? '', TranslationService.instance.lang);
      final c = r.card;
      if (!mounted) return;
      setState(() {
        _dragonSays = r.reply;
        if (widget.thing == null || _name.text.isEmpty) {
          _name.text = c['name'] as String? ?? '';
        }
        _description.text = c['description'] as String? ?? '';
        _height.text = c['heightCm'] == null ? '' : '${c['heightCm']}';
        _color.text = c['color'] as String? ?? '';
        _material = c['material'] as String?;
        _complexity = c['complexity'] as String?;
        _brand = c['brand'] == true;
        _figures = (c['figures'] as num?)?.toInt() ?? 1;
        _quality = c['quality'] as String?;
      });
    } on AssistantError catch (e) {
      if (!mounted) return;
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
          _photo!,
          {
            'name': _name.text,
            'description': _description.text,
            'heightCm': int.tryParse(_height.text.trim()),
            'material': _material,
            'color': _color.text,
            'complexity': _complexity,
            'brand': _brand,
            'figures': _figures,
            'quality': _quality,
            'wishes': _wishes.text,
          },
          _email.text.trim());
      if (mounted) setState(() => _sentId = id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = t('The request didn\'t go through. Please try again.');
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
          Text('I have a photo or drawing',
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

  List<Widget> _sent() => [
        const SizedBox(height: 20),
        const Icon(Icons.check_circle_outline, size: 64, color: SP.gold),
        const SizedBox(height: 14),
        m.Text('${t('Request sent')} · $_sentId',
            textAlign: TextAlign.center,
            style: SP.title(20, color: SP.goldLight)),
        const SizedBox(height: 10),
        Text(
          'Thank you very much! Our master has your picture now and will '
          'write to you within 24 hours.',
          textAlign: TextAlign.center,
          style: SP.body(14, color: SP.text),
        ),
      ];

  List<Widget> _form() => [
        Text(
          'Upload your picture, and I will fill in the order card for you. '
          'Our master will answer within 24 hours.',
          textAlign: TextAlign.center,
          style: SP.body(13.5, color: SP.text),
        ),
        const SizedBox(height: 18),
        _picture(),
        if (_reading) ...[
          const SizedBox(height: 16),
          const Center(
              child:
                  CircularProgressIndicator(color: SP.gold, strokeWidth: 2.5)),
          const SizedBox(height: 8),
          Text('The dragon is looking at the picture…',
              textAlign: TextAlign.center, style: SP.body(12.5)),
        ],
        if (_filled) ...[
          if (_dragonSays != null || _dragonSaysEn != null) ...[
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
          const SizedBox(height: 18),
          ..._card(),
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
                  Text('Choose a picture',
                      style: SP.title(17, color: SP.goldLight)),
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
        _field('Description', _description, lines: 3),
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
                onSelected: (_) => setState(() => _material = mat.id),
                selectedColor: SP.gold,
                backgroundColor: SP.asphaltCard,
                labelStyle: SP.body(12.5,
                    color: _material == mat.id ? SP.asphaltDeep : SP.goldLight),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _field('Color', _color),
        if (_figures > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'There are $_figures figures in your picture. Write in your wishes '
              'which figure to make, or whether to make all of them.',
              style: SP.body(12.5, color: SP.goldLight),
            ),
          ),
        if (_quality == 'poor')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'The picture is not very sharp. A clearer photo will help our '
              'master see the details.',
              style: SP.body(12.5, color: SP.goldLight),
            ),
          ),
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
          child: Text(
            'Our master will answer within 24 hours with an approximate '
            'price. If you would like a 3D preview from all sides first, '
            'our master will ask for a prepayment of about 20% of the price '
            '(at least 15 zł). It counts toward the payment.',
            style: SP.body(12.5, color: SP.text),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            'We don\'t print film, cartoon or game heroes and logos that '
            'belong to companies.',
            style: SP.body(11.5).copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: 14),
        _field('Your email', _email, email: true),
        _check(
            _rights,
            (v) => setState(() => _rights = v),
            'This is my own picture, or I have the right to use it for a '
            'figure.'),
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
                      : Text('Send to our master',
                          style: SP.title(17, color: SP.asphaltDeep)),
                ),
              ),
            ),
          ),
        ),
      ];

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
              onChanged: (_) => setState(() {}),
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
