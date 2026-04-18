import 'package:flutter/material.dart';

import 'home_screen.dart';
import '../theme/hive_colors.dart';
import '../widgets/hive_shell_background.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Access')),
      body: HiveShellBackground(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: HiveColors.surface.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: HiveColors.outline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 64,
                                width: 64,
                                decoration: BoxDecoration(
                                  color: HiveColors.honey.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(
                                  Icons.lock_person_outlined,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Your photos stay private.',
                                style: theme.textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'HIVE only adds a local organization layer. It does not move, rename, or rewrite your Apple Photos assets.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: HiveColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _PrivacyPoint(
                          icon: Icons.memory_rounded,
                          title: 'Local-only processing',
                          body:
                              'Organization happens on this device. No cloud sync is required for the core experience.',
                        ),
                        const SizedBox(height: 12),
                        const _PrivacyPoint(
                          icon: Icons.photo_library_outlined,
                          title: 'Originals remain untouched',
                          body:
                              'Cells are virtual folders layered over your library, not changes to the source photos.',
                        ),
                        const SizedBox(height: 12),
                        const _PrivacyPoint(
                          icon: Icons.tune_rounded,
                          title: 'You stay in control',
                          body:
                              'Permission handling comes next. For now, this is only the UI shell with no real access request yet.',
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'You can continue through the shell now and wire real permissions later.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: HiveColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Back'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const HomeScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Continue'),
                              ),
                            ),
                          ],
                        ),
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

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HiveColors.surfaceElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: HiveColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: HiveColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
