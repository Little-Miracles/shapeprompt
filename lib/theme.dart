import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ShapePrompt palette — taken from the dragon logo.
class SP {
  /// "Wet asphalt": dark grey with a cool blue tint.
  static const asphalt = Color(0xFF1E2226);
  static const asphaltDeep = Color(0xFF14171A);
  static const asphaltCard = Color(0xFF272C31);

  static const goldDeep = Color(0xFF8D6D3D);
  static const gold = Color(0xFFCCA665);
  static const goldLight = Color(0xFFFCED97);

  static const emeraldDeep = Color(0xFF166348);
  static const emerald = Color(0xFF48AD8A);

  static const purpleDeep = Color(0xFF472868);
  static const purple = Color(0xFF8B4AB2);

  static const text = Colors.white;
  static const textSoft = Color(0xFFC9C3B4);

  /// Asphalt with a faint warm glow behind the logo.
  static const background = RadialGradient(
    center: Alignment(0, -0.35),
    radius: 1.1,
    colors: [Color(0xFF2A2E31), asphalt, asphaltDeep],
    stops: [0.0, 0.55, 1.0],
  );

  /// Gold that flows through a highlight, as on the logo's edges.
  static const goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, gold, goldDeep],
  );

  static TextStyle title(double size, {Color color = gold}) =>
      GoogleFonts.marcellus(fontSize: size, color: color, letterSpacing: 0.6);

  static TextStyle body(double size,
          {Color color = textSoft, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.montserrat(fontSize: size, color: color, fontWeight: weight);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: asphalt,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
          surface: asphalt,
        ),
      );
}

/// Full-screen asphalt background, content kept phone-width on wide screens.
class SPScaffold extends StatelessWidget {
  const SPScaffold({super.key, required this.body});
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: SP.background),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
