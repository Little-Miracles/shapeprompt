// Writes worker/src/catalog.json — the menu the Worker shows to Gemini and
// the only place it takes prices from. Run after any change to the
// catalog or the costs:  flutter test test/export_catalog_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shapeprompt/catalog.dart';
import 'package:shapeprompt/pricing.dart';

void main() {
  test('export the catalog for the Worker', () {
    final works = [
      for (final w in readyWorks)
        {
          'id': w.id,
          'name': w.name,
          'story': w.story,
          'materials': [
            for (final id in w.materialIds)
              {
                'id': id,
                'name': materials[id]!.name,
                'about': materials[id]!.about,
                'colors': [for (final c in materials[id]!.colors) c.name],
              }
          ],
          'sizes': [
            for (final s in w.sizes) {'label': s.label, 'cm': s.heightCm}
          ],
          'prices': [
            for (final id in w.materialIds)
              for (final s in w.sizes)
                for (final p in packagings)
                  {
                    'material': id,
                    'size': s.label,
                    'box': p.name,
                    'price': quote(
                      size: s,
                      material: materials[id]!,
                      costs: costs,
                      packaging: p,
                      finishingHours: w.finishingHours,
                    ).gross,
                  }
          ],
          // Custom requests: any material, 5–25 cm (the A1 prints up to
          // 25.6 cm).
          'custom': [
            for (final m in materials.values)
              for (var cm = 5; cm <= 25; cm++)
                for (final p in packagings)
                  {
                    'material': m.id,
                    'cm': cm,
                    'box': p.name,
                    'price': quote(
                      size: scaledSize(w, cm.toDouble()),
                      material: m,
                      costs: costs,
                      packaging: p,
                      finishingHours: w.finishingHours,
                    ).gross,
                  }
          ],
        }
    ];
    final catalog = {
      'delivery': costs.parcelLockerGross,
      'boxes': [
        for (final p in packagings) {'name': p.name, 'about': p.about}
      ],
      'moreMaterials': moreMaterialsNote,
      'allMaterials': [
        for (final m in materials.values)
          {
            'id': m.id,
            'name': m.name,
            'about': m.about,
            'colors': [for (final c in m.colors) c.name],
          }
      ],
      'works': works,
    };
    File('worker/src/catalog.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(catalog)}\n');
  });
}
