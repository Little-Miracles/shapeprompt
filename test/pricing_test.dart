import 'package:flutter_test/flutter_test.dart';
import 'package:shapeprompt/models.dart';
import 'package:shapeprompt/pricing.dart';

void main() {
  const pla = FilamentMaterial(
      id: 'pla', name: 'PLA', about: '', spoolPriceGross: 123, colors: []);
  const size =
      PrintSize(label: 'Large', heightCm: 20, grams: 180, printHours: 14);
  const costs = CostSettings();

  test('every part of the price comes from the maker\'s numbers', () {
    final q = quote(size: size, material: pla, costs: costs, finishingHours: 1);
    // 180 g + 10% supports × 0.10 zł/g net (123 zł spool with VAT)
    expect(q.filament, 19.8);
    // 14 h × (0.1 kW × 0.85 zł + 0.5 zł wear)
    expect(q.printerTime, 8.19);
    expect(q.labor, 40);
    expect(q.box, 3);
    expect(q.risk, closeTo(7.10, 0.01));
    expect(q.margin, closeTo(15.62, 0.01));
    // net 93.71 × 1.23 = 115.26 → rounded up to a whole złoty
    expect(q.gross, 116);
  });

  test('a denser, pricier material makes a pricier print', () {
    const silk = FilamentMaterial(
        id: 'silk',
        name: 'Silk',
        about: '',
        spoolPriceGross: 150,
        density: 1.32,
        colors: []);
    final a = quote(size: size, material: pla, costs: costs).gross;
    final b = quote(size: size, material: silk, costs: costs).gross;
    expect(b, greaterThan(a));
  });

  test('VAT inside a gross price', () {
    // 97.99 zł gross → 18.32 zł VAT, 79.67 zł net
    expect(vatOf(97.99), 18.32);
  });
}
