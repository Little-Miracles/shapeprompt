import 'package:flutter/material.dart' hide Text;

import '../catalog.dart';
import '../models.dart';
import '../pricing.dart';
import '../theme.dart';
import '../tr_text.dart';
import 'portfolio.dart';
import 'work_detail.dart' show PayButton;

/// 3D files to print at home: the master's own designs as STL. Paid with
/// PayPal, downloaded right after the payment.
class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SPScaffold(
      helper: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        children: [
          const BackRow(),
          Text('3D files', textAlign: TextAlign.center, style: SP.title(24)),
          const SizedBox(height: 6),
          Text(
            'Have a 3D printer? Print it yourself: STL files designed by '
            'our master. Download right after the payment.',
            textAlign: TextAlign.center,
            style: SP.body(12.5, weight: FontWeight.w300),
          ),
          const SizedBox(height: 8),
          Text(
            'Most pictures are previews of the 3D model; a real photo means '
            'our master has printed it. Every file is ready to print: on '
            'your own printer, or at any 3D printing service near you.',
            textAlign: TextAlign.center,
            style: SP.body(11.5).copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 14),
          const PortfolioButton(),
          const SizedBox(height: 22),
          for (final f in digitalFiles) _FileTile(file: f),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file});
  final DigitalFile file;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => FileDetailScreen(file: file))),
        child: Ink(
          decoration: SP.card(SP.purple),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Picture(file: file, height: 170),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(file.name,
                              style: SP.title(19, color: SP.goldLight)),
                        ),
                        Text(zl(file.priceGross),
                            style: SP.body(13, color: SP.gold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('STL · ${file.sizeMm} · incl. VAT',
                        style: SP.body(11.5)),
                    const SizedBox(height: 2),
                    Text(
                        file.printed
                            ? 'Photo of the print'
                            : 'Preview of the 3D model',
                        style: SP.body(11).copyWith(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.file, required this.height});
  final DigitalFile file;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
        child: Stack(
          children: [
            ColoredBox(
              color: Colors.white,
              child: Image.asset(file.image,
                  height: height, width: double.infinity, fit: BoxFit.contain),
            ),
            const Positioned(right: 8, bottom: 8, child: Watermark()),
          ],
        ),
      );
}

class FileDetailScreen extends StatefulWidget {
  const FileDetailScreen({super.key, required this.file});
  final DigitalFile file;

  @override
  State<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends State<FileDetailScreen> {
  bool _license = false;

  /// EU law: digital content loses the 14-day return once the download
  /// starts — only if the buyer agrees to that before paying.
  bool _noReturn = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final ready = _license && _noReturn;
    return SPScaffold(
      helper: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        children: [
          const BackRow(),
          Text(f.name, textAlign: TextAlign.center, style: SP.title(24)),
          const SizedBox(height: 16),
          Container(
            decoration: SP.card(SP.purple),
            child: _Picture(file: f, height: 260),
          ),
          const SizedBox(height: 14),
          Text(f.about, style: SP.body(13, color: SP.text)),
          const SizedBox(height: 16),
          _part('Size', f.sizeMm),
          _part('How it was made', f.madeWith),
          _part('Printing tips', f.printTip),
          _part('License', fileLicense),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: SP.card(SP.emerald),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text('${f.name} · STL file',
                            style: SP.body(13, color: SP.text))),
                    Text(zl(f.priceGross),
                        style: SP.body(13,
                            color: SP.goldLight, weight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('incl. VAT 23%: ${zl(vatOf(f.priceGross))} · no delivery',
                    style: SP.body(11)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _check(_license, (v) => setState(() => _license = v),
              'I agree to the license: the file is for my personal use only.'),
          _check(
              _noReturn,
              (v) => setState(() => _noReturn = v),
              'I want the download to start right after the payment, and I '
              'understand that I then lose the 14-day right to cancel.'),
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: !ready,
            child: Opacity(
              opacity: ready ? 1 : 0.45,
              child: PayButton(
                label: 'Pay with PayPal · ${zl(f.priceGross)}',
                item: {'file': f.id},
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
              'After the payment you get a download link. It works for '
              '7 days.',
              textAlign: TextAlign.center,
              style: SP.body(11.5)),
          const SizedBox(height: 4),
          Text('Demo mode: PayPal Sandbox. No real money is charged.',
              textAlign: TextAlign.center,
              style: SP
                  .body(11, color: SP.purple)
                  .copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _part(String head, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(head, style: SP.title(14, color: SP.gold)),
            const SizedBox(height: 3),
            Text(text, style: SP.body(12.5)),
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
