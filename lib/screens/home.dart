import 'package:flutter/material.dart' hide Text;
import 'package:google_fonts/google_fonts.dart';

import '../models.dart';
import '../theme.dart';
import '../tr_text.dart';
import '../widgets/motion_splash.dart';
import 'helper.dart';
import 'ice_welcome.dart';
import 'ready_works.dart';

/// The three ways to order — the one screen that looks unlike the others:
/// the dragon sits big above the paths, and each path is a jewel card.
/// On the first visit the ice welcome introduces the dragon.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Emerald and amethyst cast like the gold card: the same metal shine,
/// with gold flowing through the highlight.
const _emeraldGold = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF1F6B4E),
    Color(0xFF3E9A76),
    Color(0xFFCFC27E),
    Color(0xFF3A9270),
    Color(0xFF1C5E45),
  ],
  stops: [0.0, 0.3, 0.5, 0.72, 1.0],
);

const _purpleGold = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF4A2A6E),
    Color(0xFF8457AE),
    Color(0xFFD9B98A),
    Color(0xFF7E4FA8),
    Color(0xFF43255F),
  ],
  stops: [0.0, 0.3, 0.5, 0.72, 1.0],
);

const richGold = Color(0xFFE6C77A);

/// Cormorant has Cyrillic, so the titles stay beautiful in every language.
TextStyle homeHeading(double size, {Color color = richGold}) =>
    GoogleFonts.cormorantGaramond(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        height: 1.1);

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // The dragon greets with our logo on its sign, steps away, and on
    // the first visit the ice welcome settles on top.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showMotionSplash(context, const Motion('assets/anim/hello', 48),
          width: 300);
      if (mounted) showIceWelcomeOnce(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SPScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          const BackRow(),
          ShaderMask(
            shaderCallback: (r) => SP.metalGold.createShader(r),
            child: Text('What would you like?',
                textAlign: TextAlign.center,
                style: homeHeading(32, color: Colors.white)),
          ),
          const SizedBox(height: 18),
          const Center(child: HelperButton(size: 112)),
          const SizedBox(height: 10),
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => showIceWelcome(context),
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: const ShapeDecoration(
                    gradient: SP.metalGold,
                    shape: StadiumBorder(
                        side: BorderSide(color: Color(0xFF5E4520), width: 1.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: SP.asphaltDeep),
                      const SizedBox(width: 6),
                      Text('Read & listen again',
                          style: SP.body(12.5,
                              color: SP.asphaltDeep, weight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _PathCard(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReadyWorksScreen())),
            icon: Icons.auto_awesome_mosaic_outlined,
            fill: SP.metalGold,
            edge: const Color(0xFF5E4520),
            title: 'Ready works',
            subtitle: 'Already printed. Pick a color and size.',
          ),
          const _PathCard(
            icon: Icons.photo_camera_outlined,
            fill: _emeraldGold,
            edge: Color(0xFF0F4532),
            title: 'I have a photo or drawing',
            subtitle: 'Upload it and tell me your wishes.',
          ),
          const _PathCard(
            icon: Icons.lightbulb_outline,
            fill: _purpleGold,
            edge: Color(0xFF2E1846),
            title: 'I have an idea',
            subtitle:
                'Describe it in words and get 2–3 sketches to start from.',
          ),
        ],
      ),
    );
  }
}

/// A jewel card: gold, emerald-gold or amethyst-gold metal, dark letters.
class _PathCard extends StatelessWidget {
  const _PathCard({
    this.onTap,
    required this.icon,
    required this.fill,
    required this.edge,
    required this.title,
    required this.subtitle,
  });
  final VoidCallback? onTap;
  final IconData icon;
  final Gradient fill;
  final Color edge;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    const ink = SP.asphaltDeep;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: fill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: edge, width: 1.4),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: ink, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: homeHeading(23, color: ink)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: SP.body(12.5,
                            color: const Color(0xFF1A1610),
                            weight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
