import 'package:flutter/material.dart';

import '../theme.dart';
import 'home.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SPScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const Spacer(),
            Image.asset('assets/logo/logo_start.png', width: 320),
            const SizedBox(height: 18),
            Text(
              'From a photo or an idea\nto a real 3D print.',
              textAlign: TextAlign.center,
              style: SP.title(21, color: SP.goldLight),
            ),
            const SizedBox(height: 10),
            Text(
              'AI helps with the details. A real maker prints it.',
              textAlign: TextAlign.center,
              style: SP.body(12.5, weight: FontWeight.w300)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
            const Spacer(),
            GoldButton(
              label: 'Start',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HomeScreen())),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// A gold pill that slowly glows, like the logo's nozzles catching light.
class GoldButton extends StatefulWidget {
  const GoldButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: SP.gold.withOpacity(0.18 + 0.22 * _glow.value),
              blurRadius: 14 + 14 * _glow.value,
            ),
          ],
        ),
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: widget.onTap,
          child: Ink(
            width: 220,
            height: 56,
            decoration: BoxDecoration(
              gradient: SP.goldGradient,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: SP.title(20, color: SP.asphaltDeep),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
