import 'package:flutter/material.dart';

import 'onboarding_screen.dart';
import '../theme/hive_colors.dart';
import '../widgets/hive_shell_background.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: HiveShellBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        const _HiveMark(),
                        const SizedBox(height: 28),
                        Text(
                          'HIVE',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayMedium?.copyWith(
                            letterSpacing: -1.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Smart cells for the moments you already keep.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: HiveColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A local-first layer for organizing your Apple Photos library without moving originals.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: HiveColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: HiveColors.surface.withValues(alpha: 0.84),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: HiveColors.outline),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Private by design. Local organization only.',
                                  style: TextStyle(
                                    color: HiveColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const OnboardingScreen(),
                              ),
                            );
                          },
                          child: const Text('Get Started'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Designed for a calm, premium setup flow.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: HiveColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HiveMark extends StatelessWidget {
  const _HiveMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 112,
        width: 112,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HiveColors.amberGlow, HiveColors.honeyDeep],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33F4B860),
              blurRadius: 36,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HiveColors.background.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(
            child: Icon(
              Icons.grid_view_rounded,
              size: 38,
              color: HiveColors.honey,
            ),
          ),
        ),
      ),
    );
  }
}
