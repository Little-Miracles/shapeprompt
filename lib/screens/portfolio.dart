import 'package:flutter/material.dart' hide Text;

import '../catalog.dart';
import '../models.dart';
import '../theme.dart';
import '../tr_text.dart';

/// The master's portfolio: every piece in a gold frame, its story behind
/// "Read". A showcase — new works are added as they are printed.
class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  static void open(BuildContext context) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const PortfolioScreen()));

  @override
  Widget build(BuildContext context) {
    return SPScaffold(
      helper: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        children: [
          const BackRow(),
          Text('Portfolio of our master',
              textAlign: TextAlign.center, style: SP.title(24)),
          const SizedBox(height: 6),
          Text(
            'A showcase of what our master has made. New works are added '
            'as they are printed and photographed.',
            textAlign: TextAlign.center,
            style: SP.body(12.5, weight: FontWeight.w300),
          ),
          const SizedBox(height: 24),
          for (final p in portfolio) _Frame(piece: p),
        ],
      ),
    );
  }
}

class _Frame extends StatefulWidget {
  const _Frame({required this.piece});
  final PortfolioPiece piece;

  @override
  State<_Frame> createState() => _FrameState();
}

class _FrameState extends State<_Frame> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.piece;
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A picture frame: dark gold outside, a thin light gold fillet,
          // a pale mat around the picture.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: SP.metalGold,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F3EA),
                border: Border.all(color: SP.goldLight, width: 1.5),
              ),
              child: Stack(
                children: [
                  Image.asset(p.image,
                      height: 230, width: double.infinity, fit: BoxFit.contain),
                  const Positioned(right: 0, bottom: 0, child: Watermark()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(p.title, style: SP.title(19, color: SP.goldLight)),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _open = !_open),
                icon: Icon(
                    _open ? Icons.expand_less : Icons.menu_book_outlined,
                    color: SP.gold,
                    size: 20),
                label: Text(_open ? 'Close' : 'Read',
                    style: SP.body(13, color: SP.gold, weight: FontWeight.w600)),
              ),
            ],
          ),
          Text(p.printed ? 'Photo of the print' : 'Preview of the 3D model',
              style: SP.body(11).copyWith(fontStyle: FontStyle.italic)),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _part('What it is for', p.purpose),
                        _part('How it was made', p.madeWith),
                        _part('Details', p.details),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _part(String head, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(head, style: SP.title(14, color: SP.gold)),
            const SizedBox(height: 3),
            Text(text, style: SP.body(12.5, color: SP.text)),
          ],
        ),
      );
}

/// "Our master's portfolio" — on every path, so a guest can see real work
/// before choosing.
class PortfolioButton extends StatelessWidget {
  const PortfolioButton({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: OutlinedButton.icon(
          onPressed: () => PortfolioScreen.open(context),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: SP.gold.withOpacity(0.7)),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          icon: const Icon(Icons.collections_outlined, color: SP.gold, size: 20),
          label: Text('Portfolio of our master',
              style: SP.body(13, color: SP.goldLight, weight: FontWeight.w600)),
        ),
      );
}
