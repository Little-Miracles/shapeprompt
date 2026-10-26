import 'package:flutter/material.dart';

import '../theme.dart';

/// The three ways to order. Paths are wired up in the next build steps.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SPScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new, color: SP.gold),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 8),
          Text('What would you like?',
              textAlign: TextAlign.center, style: SP.title(24)),
          const SizedBox(height: 28),
          const _PathCard(
            icon: Icons.auto_awesome_mosaic_outlined,
            accent: SP.gold,
            title: 'Ready works',
            subtitle: 'Pieces I have already printed. Pick a color and size.',
          ),
          const _PathCard(
            icon: Icons.photo_camera_outlined,
            accent: SP.emerald,
            title: 'I have a picture',
            subtitle: 'Upload a photo or drawing and tell me your wishes.',
          ),
          const _PathCard(
            icon: Icons.lightbulb_outline,
            accent: SP.purple,
            title: 'I have an idea',
            subtitle: 'Describe it in words and get 2–3 sketches to start from.',
          ),
        ],
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SP.asphaltCard, SP.asphaltDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.55), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SP.title(18, color: SP.goldLight)),
                const SizedBox(height: 4),
                Text(subtitle, style: SP.body(12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
