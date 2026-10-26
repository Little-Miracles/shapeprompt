import 'package:flutter/material.dart';

import '../theme.dart';
import 'ready_works.dart';

/// The three ways to order. Paths are wired up one by one.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SPScaffold(
      helper: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        children: [
          const BackRow(),
          const SizedBox(height: 8),
          Text('What would you like?',
              textAlign: TextAlign.center, style: SP.title(24)),
          const SizedBox(height: 28),
          _PathCard(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReadyWorksScreen())),
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
            subtitle:
                'Describe it in words and get 2–3 sketches to start from.',
          ),
        ],
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    this.onTap,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });
  final VoidCallback? onTap;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: SP.card(accent),
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
        ),
      ),
    );
  }
}
