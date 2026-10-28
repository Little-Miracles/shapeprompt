import 'package:flutter_test/flutter_test.dart';
import 'package:shapeprompt/models.dart';
import 'package:shapeprompt/pricing.dart';

void main() {
  const pla = FilamentMaterial(
      id: 'pla', name: 'PLA', about: '', spoolPriceGross: 123, colors: []);
  const size =
      PrintSize(label: 'Large', heightCm: 20, grams: 180, printHours: 14);
  const costs = CostSettings();
  const box = Packaging(name: 'Box', about: '', smallNet: 3, largeNet: 5);

  test('every part of the price comes from the maker\'s numbers', () {
    final q = quote(
        size: size,
        material: pla,
        costs: costs,
        packaging: box,
        finishingHours: 1);
    // 180 g + 10% supports × 0.10 zł/g net (123 zł spool with VAT)
    expect(q.filament, 19.8);
    // 14 h × (0.1 kW × 0.85 zł + 1700 zł printer / 1.23 / 5000 h + 0.10 upkeep)
    expect(q.printerTime, 6.46);
    // (1 h finishing + 0.25 h preparing) × 40 zł
    expect(q.labor, 50);
    // a 20 cm figure goes in the large box
    expect(q.box, 5);
    expect(q.risk, closeTo(8.13, 0.01));
    expect(q.margin, closeTo(17.88, 0.01));
    // 2.9% of 131.93 zł + 1.35 zł
    expect(q.payment, closeTo(5.18, 0.01));
    // net 112.44 × 1.23 = 138.30 → rounded up to a whole złoty
    expect(q.gross, 139);
  });

  test('a denser, pricier material makes a pricier print', () {
    const silk = FilamentMaterial(
        id: 'silk',
        name: 'Silk',
        about: '',
        spoolPriceGross: 150,
        density: 1.32,
        colors: []);
    final a =
        quote(size: size, material: pla, costs: costs, packaging: box).gross;
    final b =
        quote(size: size, material: silk, costs: costs, packaging: box).gross;
    expect(b, greaterThan(a));
  });

  test('VAT inside a gross price', () {
    // 97.99 zł gross → 18.32 zł VAT, 79.67 zł net
    expect(vatOf(97.99), 18.32);
  });

  test('a custom height scales from the nearest sliced size', () {
    const work = ReadyWork(
      id: 'w',
      name: 'W',
      story: '',
      image: '',
      modelImage: '',
      model: '',
      materialIds: [],
      sizes: [
        PrintSize(label: 'Small', heightCm: 10, grams: 40, printHours: 4),
        PrintSize(label: 'Large', heightCm: 20, grams: 180, printHours: 14),
      ],
    );
    // 12 cm is nearer to 10 cm: 40 g × 1.2³
    expect(scaledSize(work, 12).grams, closeTo(69.12, 0.01));
    // 20 cm is the Large size itself
    expect(scaledSize(work, 20).printHours, 14);
  });
}
