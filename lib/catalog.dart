import 'dart:ui' show Color;

import 'models.dart';

/// My Materials. Spool prices are typical Polish shop prices (Oct 2026)
/// until the maker adds their own receipts.
const materials = <String, FilamentMaterial>{
  'pla_basic': FilamentMaterial(
    id: 'pla_basic',
    name: 'PLA Basic',
    about: 'The everyday choice. Matte, good detail, the most affordable.',
    spoolPriceGross: 70,
    colors: [
      FilamentColor('Gold', Color(0xFFE4BD68)),
      FilamentColor('Bronze', Color(0xFF847D48)),
      FilamentColor('Black', Color(0xFF1B1B1B)),
      FilamentColor('White', Color(0xFFF2F0EA)),
      FilamentColor('Red', Color(0xFFC12E1F)),
    ],
  ),
  'pla_silk': FilamentMaterial(
    id: 'pla_silk',
    name: 'PLA Silk',
    about: 'A silky metallic shine — made for gold and bronze figurines.',
    spoolPriceGross: 105,
    density: 1.32,
    colors: [
      FilamentColor('Gold', Color(0xFFD9A93F)),
      FilamentColor('Silver', Color(0xFFC3C6CB)),
      FilamentColor('Copper', Color(0xFFB8673A)),
    ],
  ),
  'petg': FilamentMaterial(
    id: 'petg',
    name: 'PETG',
    about: 'Strong and water-resistant: for flower pots and things '
        'used outdoors.',
    spoolPriceGross: 105,
    density: 1.27,
    colors: [
      FilamentColor('Black', Color(0xFF1B1B1B)),
      FilamentColor('White', Color(0xFFF2F0EA)),
      FilamentColor('Clear', Color(0x99DDE8EE)),
    ],
  ),
};

/// Shown under the material choice.
const moreMaterialsNote = 'These are the main materials. Many more are '
    'available on request — flexible rubber-like TPU, translucent, '
    'glow-in-the-dark and others.';

const costs = CostSettings();

/// Box prices are approximate Allegro prices (Oct 2026), net.
const packagings = <Packaging>[
  Packaging(
    name: 'Simple box',
    about: 'A sturdy cardboard box with soft padding. Included in the price.',
    smallNet: 3,
    largeNet: 5,
  ),
  Packaging(
    name: 'Gift box',
    about: 'A gift box with a lid and tissue paper, ready to give.',
    smallNet: 10,
    largeNet: 15,
  ),
];

/// Ready works — pieces the maker has already modeled and printed.
/// Grams and hours must come from Bambu Studio (fromSlicer: true).
const readyWorks = <ReadyWork>[
  ReadyWork(
    id: 'dragon',
    name: 'Golden Dragon',
    story: 'Born as a picture, turned into a 3D model, '
        'printed on a home printer. The dragon from the ShapePrompt logo.',
    image: 'assets/works/dragon.jpg',
    modelImage: 'assets/works/dragon_model.png',
    model: 'assets/works/dragon.glb',
    motion: Motion('assets/anim/dragon', 36),
    materialIds: ['pla_basic', 'pla_silk'],
    finishingHours: 1,
    sizes: [
      // TODO(Nataliia): grams and hours from Bambu Studio.
      PrintSize(label: 'Small', heightCm: 10, grams: 40, printHours: 3.5),
      PrintSize(label: 'Large', heightCm: 20, grams: 180, printHours: 14),
    ],
  ),
  ReadyWork(
    id: 'goat',
    name: 'Fire Goat',
    story: 'A spirited goat with flaming mane and tail — '
        'a symbol of the coming year.',
    image: 'assets/works/goat.jpg',
    modelImage: 'assets/works/goat_model.png',
    model: 'assets/works/goat.glb',
    motion: Motion('assets/anim/goat', 36),
    materialIds: ['pla_basic', 'pla_silk'],
    finishingHours: 1,
    sizes: [
      // TODO(Nataliia): grams and hours from Bambu Studio.
      PrintSize(label: 'Small', heightCm: 10, grams: 45, printHours: 4),
      PrintSize(label: 'Large', heightCm: 20, grams: 200, printHours: 15),
    ],
  ),
];
