import 'package:flutter/material.dart' hide Text;

import '../catalog.dart';
import '../models.dart';
import '../pricing.dart';
import '../theme.dart';
import 'work_detail.dart';
import '../tr_text.dart';

class ReadyWorksScreen extends StatelessWidget {
  const ReadyWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SPScaffold(
      helper: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        children: [
          const BackRow(),
          Text('Ready works', textAlign: TextAlign.center, style: SP.title(24)),
          const SizedBox(height: 6),
          Text(
            'Pieces I have already modeled and printed.',
            textAlign: TextAlign.center,
            style: SP.body(12.5, weight: FontWeight.w300),
          ),
          const SizedBox(height: 24),
          for (final w in readyWorks) _WorkTile(work: w),
        ],
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.work});
  final ReadyWork work;

  @override
  Widget build(BuildContext context) {
    // The cheapest way to have this piece, named in full so the customer
    // finds the same price on its page.
    final options = [
      for (final id in work.materialIds)
        for (final s in work.sizes)
          (
            price: quote(
              size: s,
              material: materials[id]!,
              costs: costs,
              packaging: packagings.first,
              finishingHours: work.finishingHours,
            ).gross,
            what: '${s.label} · ${_cm(s.heightCm)} cm · ${materials[id]!.name}',
          ),
    ];
    final from = options.reduce((a, b) => a.price <= b.price ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => WorkDetailScreen(work: work))),
        child: Ink(
          decoration: SP.card(SP.gold),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(19)),
                child: Stack(
                  children: [
                    ColoredBox(
                      color: Colors.white,
                      child: Image.asset(work.image,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.contain),
                    ),
                    const Positioned(right: 8, bottom: 8, child: Watermark()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(work.name,
                              style: SP.title(19, color: SP.goldLight)),
                        ),
                        Text('from ${zl(from.price)}',
                            style: SP.body(13, color: SP.gold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${from.what} · incl. VAT, without delivery',
                        style: SP.body(11.5)),
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

String _cm(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
