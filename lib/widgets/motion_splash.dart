import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// A few seconds of a figure coming alive over the page, then it fades
/// away by itself and the page is left as usual. A tap skips it.
///
/// [solid] covers the page with asphalt — needed over the 3D viewer,
/// which the browser draws above anything see-through. Otherwise the page
/// shows through clear ice (blur, no tint).
Future<void> showMotionSplash(BuildContext context, Motion motion,
    {double width = 340, bool solid = false}) async {
  // Every frame is loaded first, so the figure moves without blinking.
  await Future.wait(
      [for (final p in motion.paths) precacheImage(AssetImage(p), context)]);
  if (!context.mounted) return;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (_, __, ___) =>
        _MotionSplash(motion: motion, width: width, solid: solid),
    transitionBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class _MotionSplash extends StatefulWidget {
  const _MotionSplash(
      {required this.motion, required this.width, required this.solid});
  final Motion motion;
  final double width;
  final bool solid;

  @override
  State<_MotionSplash> createState() => _MotionSplashState();
}

class _MotionSplashState extends State<_MotionSplash>
    with SingleTickerProviderStateMixin {
  late final List<String> _paths = widget.motion.paths;
  int _frame = 0;
  Timer? _timer;

  /// A single picture is brought to life by the app itself: it pops up,
  /// sways gently and a gold shine runs across it.
  late final AnimationController _alive =
      AnimationController(vsync: this, duration: widget.motion.length);

  @override
  void initState() {
    super.initState();
    if (_paths.length == 1) {
      _alive.forward().whenComplete(_close);
      return;
    }
    _timer =
        Timer.periodic(Duration(milliseconds: 1000 ~/ widget.motion.fps), (t) {
      if (_frame + 1 >= _paths.length) {
        // Holds the last pose for a breath, then fades away.
        t.cancel();
        _timer = Timer(const Duration(milliseconds: 400), _close);
      } else {
        setState(() => _frame++);
      }
    });
  }

  void _close() {
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alive.dispose();
    super.dispose();
  }

  Widget _brought(Widget image) => AnimatedBuilder(
        animation: _alive,
        child: image,
        builder: (context, child) {
          final t = _alive.value;
          // 0–18%: pops up from below with a small spring.
          final pop = Curves.easeOutBack.transform((t / 0.18).clamp(0.0, 1.0));
          final sway = math.sin(t * math.pi * 3) * 0.045;
          final bob = math.sin(t * math.pi * 4) * 6;
          // The shine crosses twice, from top left to bottom right.
          final shine = (t * 2) % 1.0 * 2.4 - 0.7;
          return Transform.translate(
            offset: Offset(0, (1 - pop) * 80 + bob),
            child: Transform.rotate(
              angle: sway,
              child: Transform.scale(
                scale: 0.6 + 0.4 * pop,
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.transparent,
                      const Color(0xFFFFF3C4).withOpacity(0.55),
                      Colors.transparent,
                    ],
                    stops: [
                      (shine - 0.12).clamp(0.0, 1.0),
                      shine.clamp(0.0, 1.0),
                      (shine + 0.12).clamp(0.0, 1.0),
                    ],
                  ).createShader(r),
                  child: child,
                ),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final image =
        Image.asset(_paths[_frame], width: widget.width, gaplessPlayback: true);
    final figure = Center(child: _paths.length == 1 ? _brought(image) : image);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: widget.solid
          ? DecoratedBox(
              decoration: const BoxDecoration(gradient: SP.background),
              child: figure)
          : BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: figure),
    );
  }
}
