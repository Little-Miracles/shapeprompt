import 'dart:math' show pow;

import 'models.dart';

/// The whole price comes from here — AI never names a price.
Quote quote({
  required PrintSize size,
  required FilamentMaterial material,
  required CostSettings costs,
  required Packaging packaging,
  double finishingHours = 0,
}) {
  final grams = size.grams * material.density / plaDensity;
  final filament = grams * (1 + costs.wasteShare) * material.pricePerGramNet;
  final printerTime = size.printHours *
      (costs.printerKw * costs.electricityPerKwh + costs.wearPerHour);
  final labor = (finishingHours + costs.prepHours) * costs.laborPerHour;
  final box = packaging.costFor(size);
  final base = filament + printerTime + labor + box;
  final risk = base * costs.failRiskShare;
  final margin = (base + risk) * costs.marginShare;
  // PayPal takes its fee from what the customer pays.
  final payment = (base + risk + margin) * vatRate * costs.paymentShare +
      costs.paymentFixed;
  return Quote(
    filament: _round(filament),
    printerTime: _round(printerTime),
    labor: _round(labor),
    box: _round(box),
    risk: _round(risk),
    margin: _round(margin),
    payment: _round(payment),
  );
}

double _round(double v) => (v * 100).roundToDouble() / 100;

String zl(double v) =>
    v == v.roundToDouble() ? '${v.toInt()} zł' : '${v.toStringAsFixed(2)} zł';

/// The VAT inside a gross price (23/123 of it), as a Polish receipt shows.
double vatOf(double gross) => _round(gross - gross / vatRate);

/// A ready work in a height it isn't sold in, for a custom request: grams
/// grow with the volume (cube of the height), print time a bit slower.
/// Scaled from the nearest size the maker has sliced. Approximate.
PrintSize scaledSize(ReadyWork work, double heightCm) {
  final ref = work.sizes.reduce((a, b) =>
      (a.heightCm - heightCm).abs() <= (b.heightCm - heightCm).abs() ? a : b);
  final k = heightCm / ref.heightCm;
  return PrintSize(
    label: '${heightCm.round()} cm',
    heightCm: heightCm,
    grams: ref.grams * k * k * k,
    printHours: ref.printHours * pow(k, 2.5),
  );
}
