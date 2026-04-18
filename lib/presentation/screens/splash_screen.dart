import 'package:flutter/material.dart';

import '../theme/hive_colors.dart';
import '../widgets/placeholder_screen_scaffold.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreenScaffold(
      title: 'HIVE',
      description:
          'Organize your gallery into smart cells without changing your Apple Photos library.',
      icon: Icons.grid_view_rounded,
      showAppBar: false,
      footer: _SplashFooter(),
    );
  }
}

class _SplashFooter extends StatelessWidget {
  const _SplashFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HiveColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Premium iOS-first foundation',
        style: TextStyle(
          color: HiveColors.honey,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
