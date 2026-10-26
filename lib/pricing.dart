import 'models.dart';

/// The whole price comes from here — AI never names a price.
Quote quote({
  required PrintSize size,
  required FilamentMaterial material,
  required CostSettings costs,
  double finishingHours = 0,
}) {
  final grams = size.grams * material.density / plaDensity;
  final filament = grams * (1 + costs.wasteShare) * material.pricePerGramNet;
  final printerTime = size.printHours *
      (costs.printerKw * costs.electricityPerKwh + costs.wearPerHour);
  final labor = finishingHours * costs.laborPerHour;
  final base = filament + printerTime + labor + costs.box;
  final risk = base * costs.failRiskShare;
  final margin = (base + risk) * costs.marginShare;
  return Quote(
    filament: _round(filament),
    printerTime: _round(printerTime),
    labor: _round(labor),
    box: _round(costs.box),
    risk: _round(risk),
    margin: _round(margin),
  );
}

double _round(double v) => (v * 100).roundToDouble() / 100;

String zl(double v) =>
    v == v.roundToDouble() ? '${v.toInt()} zł' : '${v.toStringAsFixed(2)} zł';

/// The VAT inside a gross price (23/123 of it), as a Polish receipt shows.
double vatOf(double gross) => _round(gross - gross / vatRate);
