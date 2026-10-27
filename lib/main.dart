import 'package:flutter/material.dart';

import 'screens/helper.dart';
import 'screens/paid.dart';
import 'screens/start.dart';
import 'theme.dart';
import 'translation.dart';
import 'web_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TranslationService.instance.load();
  await HelperPrefs.instance.load();
  runApp(const ShapePromptApp());
}

/// Back from PayPal (?paypal=return&token=…) opens the "Paid" screen;
/// otherwise the app starts as usual.
Widget _first() {
  final q = Uri.base.queryParameters;
  final paypal = q['paypal'];
  if (paypal == null) return const StartScreen();
  clearQuery();
  return PaidScreen(orderId: q['token'], cancelled: paypal == 'cancel');
}

class ShapePromptApp extends StatelessWidget {
  const ShapePromptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShapePrompt',
      debugShowCheckedModeBanner: false,
      theme: SP.theme,
      home: _first(),
    );
  }
}
