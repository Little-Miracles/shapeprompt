import 'package:flutter/material.dart' hide Text;

import '../catalog.dart';
import '../models.dart';
import '../paypal.dart';
import '../pricing.dart';
import '../theme.dart';
import '../widgets/model_view.dart';
import '../widgets/motion_splash.dart';
import '../tr_text.dart';
import '../translation.dart';
import 'terms.dart';

class WorkDetailScreen extends StatefulWidget {
  const WorkDetailScreen({super.key, required this.work});
  final ReadyWork work;

  @override
  State<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends State<WorkDetailScreen> {
  late FilamentMaterial _material = materials[widget.work.materialIds.first]!;
  late FilamentColor _color = _material.colors.first;
  late PrintSize _size = widget.work.sizes.first;
  Packaging _packaging = packagings.first;

  /// While the piece comes alive the page stays empty, so the 3D viewer
  /// doesn't flash before the cover arrives.
  late bool _intro = widget.work.motion != null;

  @override
  void initState() {
    super.initState();
    final motion = widget.work.motion;
    if (motion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showMotionSplash(context, motion, width: 420, solid: true);
        if (mounted) setState(() => _intro = false);
      });
    }
  }

  void _pickMaterial(FilamentMaterial m) => setState(() {
        _material = m;
        // Keep the color if this material has it, otherwise take the first.
        _color = m.colors.firstWhere((c) => c.name == _color.name,
            orElse: () => m.colors.first);
      });

  @override
  Widget build(BuildContext context) {
    if (_intro) return const SPScaffold(body: SizedBox.shrink());
    final w = widget.work;
    final piece = quote(
      size: _size,
      material: _material,
      costs: costs,
      packaging: _packaging,
      finishingHours: w.finishingHours,
    ).gross;
    final delivery = costs.parcelLockerGross;
    final total = piece + delivery;
    return SPScaffold(
      helper: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        children: [
          const BackRow(),
          Text(w.name, textAlign: TextAlign.center, style: SP.title(24)),
          const SizedBox(height: 16),
          _Showcase(work: w),
          const SizedBox(height: 14),
          Text(w.story, style: SP.body(13)),
          const SizedBox(height: 22),
          const _Label('Material'),
          _Chips(
            options: [for (final id in w.materialIds) materials[id]!.name],
            selected: _material.name,
            onSelect: (name) => _pickMaterial(
                materials.values.firstWhere((m) => m.name == name)),
          ),
          const SizedBox(height: 8),
          Text(_material.about, style: SP.body(12)),
          const SizedBox(height: 18),
          _Label('Color · ${_color.name}'),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final c in _material.colors)
                _Swatch(
                  color: c,
                  selected: c == _color,
                  onTap: () => setState(() => _color = c),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const _Label('Size'),
          _Chips(
            options: [for (final s in w.sizes) _sizeLabel(s)],
            selected: _sizeLabel(_size),
            onSelect: (label) => setState(() =>
                _size = w.sizes.firstWhere((s) => _sizeLabel(s) == label)),
          ),
          const SizedBox(height: 18),
          const _Label('Box'),
          _Chips(
            options: [for (final p in packagings) p.name],
            selected: _packaging.name,
            onSelect: (name) => setState(() => _packaging =
                packagings.firstWhere((p) => p.name == name)),
          ),
          const SizedBox(height: 8),
          Text(_packaging.about, style: SP.body(12)),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: SP.card(SP.emerald),
            child: Column(
              children: [
                _PriceRow(
                    '${w.name}\n'
                    '${_sizeLabel(_size)} · ${_material.name}, ${_color.name}\n'
                    '${_packaging.name}',
                    piece),
                _PriceRow('Delivery · InPost Paczkomat', delivery),
                const Divider(color: Colors.white24, height: 18),
                _PriceRow('Total to pay', total, bold: true),
                // As in Polish shops: the gross price first, then what part
                // of it is VAT.
                _PriceRow('incl. VAT 23%', vatOf(total), small: true),
                const SizedBox(height: 8),
                Text(
                  'All prices include VAT. A VAT invoice is available on '
                  'request. Prints ship within Poland.',
                  style: SP.body(10.5).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(moreMaterialsNote, style: SP.body(11.5)),
          if (!_size.fromSlicer) ...[
            const SizedBox(height: 10),
            Text(
              'Demo numbers: grams and print time will be replaced with '
              'the maker\'s slicer data.',
              style: SP
                  .body(11, color: SP.purple)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 22),
          MadeForYouPay(
            label: 'Pay with PayPal · ${zl(total)}',
            item: {
              'work': w.id,
              'material': _material.id,
              'color': _color.name,
              'size': _size.label,
              'box': _packaging.name,
            },
          ),
          const SizedBox(height: 8),
          Text('Demo mode: PayPal Sandbox. No real money is charged.',
              textAlign: TextAlign.center,
              style: SP
                  .body(11, color: SP.purple)
                  .copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  static String _sizeLabel(PrintSize s) {
    final cm = s.heightCm == s.heightCm.roundToDouble()
        ? '${s.heightCm.toInt()}'
        : '${s.heightCm}';
    return '${s.label} · $cm cm';
  }
}

/// One big frame, two views of the same work: the 3D model to rotate, or
/// the whole idea picture. Both get the full frame, so neither is cropped.
class _Showcase extends StatefulWidget {
  const _Showcase({required this.work});
  final ReadyWork work;

  @override
  State<_Showcase> createState() => _ShowcaseState();
}

class _ShowcaseState extends State<_Showcase> {
  bool _model = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Chips(
          options: const ['3D model', 'Idea'],
          selected: _model ? '3D model' : 'Idea',
          onSelect: (o) => setState(() => _model = o == '3D model'),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1,
            // The idea pictures are drawn on white, the model sits on the
            // dark velvet of the app.
            child: Stack(
              children: [
                Positioned.fill(
                  child: _model
                      ? DecoratedBox(
                          decoration: SP.card(SP.gold),
                          child: ModelView(src: widget.work.model),
                        )
                      : ColoredBox(
                          color: Colors.white,
                          child: Image.asset(widget.work.image,
                              fit: BoxFit.contain),
                        ),
                ),
                if (_model) const Positioned.fill(child: WatermarkPattern()),
                const Positioned(right: 10, bottom: 10, child: Watermark()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _model
              ? 'Drag to turn it around, pinch or scroll to zoom.'
              : 'The picture this piece was born from.',
          style: SP.body(11.5, color: SP.gold),
        ),
        if (_model) ...[
          const SizedBox(height: 4),
          Text(
            'A simplified preview for viewing. Printed and finished by hand.\n'
            'Powered by MakerWorld-Image-to-3D '
            '(https://makerworld.com/makerlab/imageTo3d)',
            textAlign: TextAlign.center,
            style: SP.body(10.5).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: SP.title(15, color: SP.gold)),
      );
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.options,
    required this.selected,
    required this.onSelect,
  });
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final o in options)
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => onSelect(o),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                gradient: o == selected ? SP.goldGradient : null,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: SP.gold.withOpacity(0.6)),
              ),
              child: Text(o,
                  style: SP.body(13,
                      color: o == selected ? SP.asphaltDeep : SP.goldLight,
                      weight: FontWeight.w500)),
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final FilamentColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: color.name,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? SP.goldLight : Colors.white24,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: DecoratedBox(
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color.value),
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(this.what, this.value,
      {this.bold = false, this.small = false});
  final String what;
  final double value;
  final bool bold;
  final bool small;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(what,
                    style: bold
                        ? SP.title(16, color: SP.goldLight)
                        : SP.body(small ? 11.5 : 12.5))),
            Text(zl(value),
                style: bold
                    ? SP.title(18, color: SP.goldLight)
                    : small
                        ? SP.body(11.5)
                        : SP.body(13, color: SP.text)),
          ],
        ),
      );
}

/// Gold PayPal button: creates the order through our Worker and leaves for
/// PayPal; the customer comes back to the "Paid" screen. The dragon's
/// order card uses it too.
/// Every ready work is printed for one person, with their own words on it
/// — the workshop's rule. So it is made to the customer's specification,
/// and the 14-day withdrawal doesn't apply; the page says so plainly
/// before the payment.
class MadeForYouPay extends StatefulWidget {
  const MadeForYouPay({super.key, required this.label, required this.item});
  final String label;
  final Map<String, String> item;

  @override
  State<MadeForYouPay> createState() => _MadeForYouPayState();
}

class _MadeForYouPayState extends State<MadeForYouPay> {
  final _words = TextEditingController();
  String _place = 'under';
  bool _agreed = false;

  static const _places = {
    'under': 'Hidden underneath',
    'front': 'On the front of the base',
  };

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _words.text.trim().isNotEmpty && _agreed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SP.purple.withOpacity(0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Every piece is made for you',
                  style: SP.title(15, color: SP.gold)),
              const SizedBox(height: 4),
              Text(
                'We are a creative workshop, not a warehouse: each piece is '
                'printed only after you order it, with your own words on it. '
                'That is our workshop\'s rule. Your words can be on the front '
                'of the base, or hidden underneath, where only the one who '
                'turns it over will find them — good for a gift.',
                style: SP.body(12.5, color: SP.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Because the piece is made to your specification, the 14-day '
                'right of withdrawal does not apply (Art. 38 point 3 of the '
                'Polish Consumer Rights Act). Please think it over before '
                'ordering. If what you receive doesn\'t match your order or '
                'arrives damaged, your rights for faulty goods stay in force.',
                style: SP.body(12, color: SP.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _Label('Your words'),
        TextField(
          controller: _words,
          maxLength: 30,
          onChanged: (_) => setState(() {}),
          style: SP.body(13.5, color: SP.text),
          decoration: InputDecoration(
            hintText: t('A name, a date, a few warm words'),
            hintStyle: SP.body(12.5),
            filled: true,
            fillColor: SP.asphaltCard,
            counterStyle: SP.body(10.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _Chips(
          options: _places.values.toList(),
          selected: _places[_place]!,
          onSelect: (v) => setState(() =>
              _place = _places.entries.firstWhere((e) => e.value == v).key),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => _agreed = !_agreed),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreed,
                activeColor: SP.gold,
                checkColor: SP.asphaltDeep,
                onChanged: (v) => setState(() => _agreed = v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                      'I understand the piece is made for me and cannot be '
                      'returned within 14 days.',
                      style: SP.body(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IgnorePointer(
          ignoring: !ready,
          child: Opacity(
            opacity: ready ? 1 : 0.45,
            child: PayButton(
              label: widget.label,
              item: {
                ...widget.item,
                'words': _words.text.trim(),
                'place': _place,
                'madeForYou': 'yes',
              },
            ),
          ),
        ),
      ],
    );
  }
}

class PayButton extends StatefulWidget {
  const PayButton({super.key, required this.label, required this.item});
  final String label;
  final Map<String, String> item;

  @override
  State<PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<PayButton> {
  bool _busy = false;

  Future<void> _pay() async {
    if (!await PayConsent.ask(context) || !mounted) return;
    setState(() => _busy = true);
    try {
      await PayPal.checkout(widget.item);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PayPal is not available right now. '
              'Please try again in a moment.')));
    }
  }

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: _busy ? null : _pay,
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              gradient: SP.metalGold,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: SP.asphaltDeep))
                  : Text(widget.label,
                      style: SP.title(17, color: SP.asphaltDeep)),
            ),
          ),
        ),
      );
}
