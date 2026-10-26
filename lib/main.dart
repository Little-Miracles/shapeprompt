import 'package:flutter/material.dart';

import 'screens/start.dart';
import 'theme.dart';

void main() => runApp(const ShapePromptApp());

class ShapePromptApp extends StatelessWidget {
  const ShapePromptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShapePrompt',
      debugShowCheckedModeBanner: false,
      theme: SP.theme,
      home: const StartScreen(),
    );
  }
}
