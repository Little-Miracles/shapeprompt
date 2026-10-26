import 'package:flutter_test/flutter_test.dart';
import 'package:shapeprompt/main.dart';

void main() {
  testWidgets('Start screen shows the Start button', (tester) async {
    await tester.pumpWidget(const ShapePromptApp());
    expect(find.text('Start'), findsOneWidget);
  });
}
