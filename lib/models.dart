import 'dart:ui' show Color;

/// A filament the maker prints with. Price depends mostly on the material,
/// not on the color; cheaper ones often come in fewer colors.
class FilamentMaterial {
  const FilamentMaterial({
    required this.id,
    required this.name,
    required this.about,
    required this.spoolPriceGross,
    required this.colors,
    this.spoolGrams = 1000,
    this.density = 1.24,
  });

  final String id;
  final String name;
  final String about;

  /// Shop price with VAT, as on the receipt (zł).
  final double spoolPriceGross;
  final double spoolGrams;

  /// g/cm³ — the same model weighs more in a denser material.
  final double density;
  final List<FilamentColor> colors;

  /// The maker is a VAT payer, so her cost is the net price.
  double get pricePerGramNet => spoolPriceGross / vatRate / spoolGrams;
}

class FilamentColor {
  const FilamentColor(this.name, this.value);
  final String name;
  final Color value;
}

const vatRate = 1.23;

/// Reference density: grams in PrintSize are sliced in PLA.
const plaDensity = 1.24;

/// One fixed size of a ready work, with numbers read from the maker's slicer.
class PrintSize {
  const PrintSize({
    required this.label,
    required this.heightCm,
    required this.grams,
    required this.printHours,
    this.fromSlicer = false,
  });

  final String label;
  final double heightCm;

  /// Grams in PLA, from Bambu Studio.
  final double grams;
  final double printHours;

  /// False while the numbers are placeholders, not yet taken from
  /// Bambu Studio.
  final bool fromSlicer;
}

/// A few seconds of a figure coming alive: numbered frames 01.webp, 02.webp…
/// played by the app itself (an animated image would stand still in some
/// browsers).
class Motion {
  const Motion(this.folder, this.frames, {this.fps = 12, this.alive});
  final String folder;
  final int frames;
  final int fps;

  /// For a single still picture the app animates itself: for this long.
  final Duration? alive;

  Duration get length => alive ?? Duration(milliseconds: 1000 * frames ~/ fps);

  List<String> get paths => [
        for (var i = 1; i <= frames; i++)
          '$folder/${i.toString().padLeft(2, '0')}.webp'
      ];
}

class ReadyWork {
  const ReadyWork({
    required this.id,
    required this.name,
    required this.story,
    required this.image,
    required this.modelImage,
    required this.model,
    this.motion,
    required this.materialIds,
    required this.sizes,
    this.finishingHours = 0.5,
  });

  final String id;
  final String name;
  final String story;
  final String image;
  final String modelImage;

  /// The 3D model the customer can rotate (compressed .glb).
  final String model;

  /// A few seconds of the piece coming alive, shown when its page opens.
  final Motion? motion;
  final List<String> materialIds;
  final List<PrintSize> sizes;

  /// Removing supports and cleaning up after the print.
  final double finishingHours;
}

/// The maker's own costs and rates, net of VAT. Edited later in My Workshop.
class CostSettings {
  const CostSettings({
    this.electricityPerKwh = 0.85,
    this.printerKw = 0.1,
    this.wearPerHour = 0.5,
    this.wasteShare = 0.10,
    this.laborPerHour = 40,
    this.box = 3,
    this.failRiskShare = 0.10,
    this.marginShare = 0.20,
    this.parcelLockerGross = 17.99,
  });

  final double electricityPerKwh; // zł net
  final double printerKw;
  final double wearPerHour; // zł
  final double wasteShare; // supports and purge
  final double laborPerHour; // zł
  final double box; // zł net
  final double failRiskShare;
  final double marginShare;

  /// InPost parcel locker, shown to the customer as a separate line.
  final double parcelLockerGross;
}

/// The maker's breakdown (net). The customer sees only [gross].
class Quote {
  const Quote({
    required this.filament,
    required this.printerTime,
    required this.labor,
    required this.box,
    required this.risk,
    required this.margin,
  });

  final double filament;
  final double printerTime;
  final double labor;
  final double box;
  final double risk;
  final double margin;

  double get cost => filament + printerTime + labor + box;
  double get net => cost + risk + margin;
  double get vat => gross - net;

  /// What the customer pays for the piece, VAT included, rounded up to
  /// a whole złoty.
  double get gross => (net * vatRate).ceilToDouble();
}
