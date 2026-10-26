import 'package:flutter/material.dart';

import '../theme.dart';

/// The little golden dragon in the corner. Tap → the helper window.
class HelperButton extends StatefulWidget {
  const HelperButton({super.key});

  @override
  State<HelperButton> createState() => _HelperButtonState();
}

class _HelperButtonState extends State<HelperButton>
    with SingleTickerProviderStateMixin {
  // A slow bob up and down, so the dragon looks alive.
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -4 * _bob.value),
        child: child,
      ),
      child: Tooltip(
        message: 'Your ShapePrompt helper',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showHelper(context),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SP.asphaltDeep,
              border: Border.all(color: SP.gold, width: 1.6),
              boxShadow: [
                BoxShadow(color: SP.gold.withOpacity(0.35), blurRadius: 16),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Image.asset('assets/helper/dragon_head.png'),
          ),
        ),
      ),
    );
  }
}

const _examples = [
  'A shiny dragon as a gift, up to 100 zł',
  'Something for my desk, matte black',
  'Which material is best for a flower pot?',
];

Future<void> showHelper(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _HelperSheet(),
  );
}

class _HelperSheet extends StatelessWidget {
  const _HelperSheet();

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: SP.asphalt,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: SP.gold.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DragonWithSign(),
              const SizedBox(height: 12),
              Text(
                'Hi! I\'m your ShapePrompt helper. Tell me what you\'d like '
                'and your budget — a gift or for home, shiny or matte, which '
                'color. I\'ll pick the work, material and size, and prepare '
                'the order for you. I\'ll do my best to help!',
                style: SP.body(13, color: SP.text),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _examples)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: SP.emerald.withOpacity(0.7)),
                      ),
                      child: Text(e, style: SP.body(12, color: SP.goldLight)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                enabled: false,
                style: SP.body(13, color: SP.text),
                decoration: InputDecoration(
                  hintText: 'Write your wish…',
                  hintStyle: SP.body(13),
                  filled: true,
                  fillColor: SP.asphaltCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The helper learns to talk in the next build step, together '
                'with PayPal ordering.',
                textAlign: TextAlign.center,
                style: SP
                    .body(11, color: SP.purple)
                    .copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dragon holding its sign, with a greeting written on the sign.
class _DragonWithSign extends StatelessWidget {
  const _DragonWithSign();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 230,
        child: AspectRatio(
          aspectRatio: 671 / 700,
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Positioned.fill(
                    child: Image.asset('assets/helper/dragon_sign.png')),
                // The white sign sits at about 52–97% across, 47–72% down.
                Positioned(
                  left: box.maxWidth * 0.53,
                  top: box.maxHeight * 0.48,
                  width: box.maxWidth * 0.43,
                  height: box.maxHeight * 0.23,
                  child: Center(
                    child: Text(
                      'Hi! Let me\nhelp you choose',
                      textAlign: TextAlign.center,
                      style: SP.title(12, color: SP.asphaltDeep),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
