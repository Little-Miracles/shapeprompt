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

/// What every file is sold under: printing for yourself only.
const fileLicense = 'Personal use only: print it for yourself and as a '
    'gift. Reselling or sharing the file, and selling prints of it, is '
    'not allowed.';

/// The master's own designs, made in Tinkercad from simple shapes and
/// sliced in Bambu Studio. Prices include VAT.
const digitalFiles = <DigitalFile>[
  DigitalFile(
    id: 'fruit_stand',
    name: 'Three-Tier Fruit Stand',
    about: 'Three plates with scalloped edges on one stem, for fruit, '
        'sweets or cupcakes. The flowers on the plates are drawn by hand.',
    image: 'assets/files/stand.jpg',
    sizeMm: '220 × 220 × 228 mm',
    priceGross: 10,
    madeWith: 'Tinkercad: cylinders for the plates and the stem, the '
        'flowers drawn freehand with the Sketch tool, all aligned on one '
        'axis.',
    printTip: 'PLA, 0.2 mm layers. Needs a bed of at least 220 × 220 mm, '
        'or scale it down in the slicer. Supports under the plates.',
  ),
  DigitalFile(
    id: 'coder_box',
    name: 'Box for a Programmer',
    about: 'A box with a lid and a secret: one side says THE ANSWER IS '
        'WITHIN, the other carries a message in hex code that only a '
        'programmer can read. A gift for someone who writes code.',
    image: 'assets/files/box.jpg',
    sizeMm: '238 × 190 × 103 mm (box and lid together)',
    priceGross: 10,
    madeWith: 'Tinkercad: boxes hollowed out for the box and the lid, the '
        'words made of letter shapes.',
    printTip: 'PLA, 0.2 mm layers. Print the box and the lid side by side, '
        'no supports.',
  ),
  DigitalFile(
    id: 'crystal_vase',
    name: 'Crystal Bowl',
    about: 'Facets outside, a smooth round bowl inside — like a cut '
        'crystal. For keys, jewelry, sweets or a small plant.',
    image: 'assets/files/crystal.jpg',
    sizeMm: '167 × 168 × 83 mm',
    priceGross: 5,
    madeWith: 'Tinkercad: a faceted shape hollowed out by a sphere, on a '
        'round foot.',
    printTip: 'PLA or PETG, 0.2 mm layers. Supports under the outer '
        'facets.',
  ),
  DigitalFile(
    id: 'round_bowl',
    name: 'Round Bowl',
    about: 'A smooth, simple bowl for the table or the shelf.',
    image: 'assets/files/bowl.jpg',
    sizeMm: '180 × 180 × 84 mm',
    priceGross: 5,
    madeWith: 'Tinkercad: a sphere hollowed out by a second sphere.',
    printTip: 'PLA or PETG, 0.2 mm layers. Prints without supports.',
  ),
  DigitalFile(
    id: 'grass_holder',
    name: 'Cat Grass Stand',
    about: 'Our master grew herbs in an indoor mini garden — and cat grass '
        'for the cat. This stand is made to the size of one seed pod: take '
        'the cat grass out of the garden, put it in the stand and give it '
        'to the cat without harming the herbs, then put it back. With a '
        'little water inside, the grass can even travel with you.',
    image: 'assets/files/holder.jpg',
    printed: true,
    sizeMm: '100 × 220 × 145 mm',
    priceGross: 5,
    madeWith: 'Tinkercad: boxes joined and hollowed out, measured to fit '
        'a mini garden seed pod.',
    printTip: 'Printed in PLA. For water inside, PETG is better. '
        '0.2 mm layers, no supports.',
  ),
];

/// The master's portfolio: a showcase of what has been made. It grows as
/// new works are printed and photographed.
final portfolio = <PortfolioPiece>[
  for (final w in readyWorks)
    PortfolioPiece(
      title: w.name,
      image: w.image,
      purpose: w.story,
      madeWith: 'A picture made with AI, turned into a 3D model in Bambu '
          'Lab MakerLab, repaired and sliced in Bambu Studio.',
      details: 'Printed on a Bambu Lab A1 in PLA.',
      printed: true,
    ),
  for (final f in digitalFiles)
    PortfolioPiece(
      title: f.name,
      image: f.image,
      purpose: f.about,
      madeWith: f.madeWith,
      details: '${f.sizeMm}. ${f.printTip}',
      printed: f.printed,
    ),
];
