import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/helper.dart';

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

  /// Dark card with a thin border in one of the logo colors.
  static BoxDecoration card(Color accent) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [asphaltCard, asphaltDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.55), width: 1.2),
      );

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
  const SPScaffold({super.key, required this.body, this.helper = false});
  final Widget body;

  /// Shows the little dragon helper in the corner.
  final bool helper;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: SP.background),
        // Ink (chips, cards) paints on the nearest Material — keep one
        // above the gradient so it is not hidden behind it.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: helper
                    ? Stack(
                        children: [
                          Positioned.fill(child: body),
                          const Positioned(
                              right: 16, bottom: 20, child: HelperButton()),
                        ],
                      )
                    : body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The gold back arrow at the top left of every inner screen.
class BackRow extends StatelessWidget {
  const BackRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_ios_new, color: SP.gold),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}

/// The ShapePrompt mark on every showcase picture: it stays on screenshots.
class Watermark extends StatelessWidget {
  const Watermark({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.85,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(
            color: SP.asphaltDeep.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(child: Image.asset('assets/logo/mark.png', width: 24)),
              const SizedBox(width: 6),
              Text('ShapePrompt', style: SP.title(12, color: SP.goldLight)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "ShapePrompt" written across the picture at an angle, faint enough to
/// see the piece through it — it shows on every screenshot.
class WatermarkPattern extends StatelessWidget {
  const WatermarkPattern({super.key});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _PatternPainter()));
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: 'ShapePrompt',
        style: SP.title(15, color: SP.gold.withOpacity(0.16)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.5);
    final reach = size.longestSide;
    var row = 0;
    for (var y = -reach; y < reach; y += 56, row++) {
      final shift = row.isEven ? 0.0 : 70.0;
      for (var x = -reach - shift; x < reach; x += 140) {
        text.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
