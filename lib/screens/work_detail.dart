import 'package:flutter/material.dart';

import '../catalog.dart';
import '../models.dart';
import '../pricing.dart';
import '../theme.dart';
import '../widgets/model_view.dart';

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

  void _pickMaterial(FilamentMaterial m) => setState(() {
        _material = m;
        // Keep the color if this material has it, otherwise take the first.
        _color = m.colors.firstWhere((c) => c.name == _color.name,
            orElse: () => m.colors.first);
      });

  @override
  Widget build(BuildContext context) {
    final w = widget.work;
    final piece = quote(
      size: _size,
      material: _material,
      costs: costs,
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
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: SP.card(SP.emerald),
            child: Column(
              children: [
                _PriceRow(
                    '${w.name} · ${_size.label}\n'
                    '${_material.name}, ${_color.name}',
                    piece),
                _PriceRow('Delivery · InPost parcel locker', delivery),
                const Divider(color: Colors.white24, height: 18),
                _PriceRow('Total to pay', total, bold: true),
                // As in Polish shops: the gross price first, then what part
                // of it is VAT.
                _PriceRow('incl. VAT 23%', vatOf(total), small: true),
                _PriceRow('Net', total - vatOf(total), small: true),
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
          Opacity(
            opacity: 0.5,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: SP.goldGradient,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text('Pay with PayPal · ${zl(total)}',
                  style: SP.title(17, color: SP.asphaltDeep)),
            ),
          ),
          const SizedBox(height: 8),
          Text('PayPal payment is the next build step.',
              textAlign: TextAlign.center, style: SP.body(11)),
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
