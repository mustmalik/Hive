import 'package:flutter/material.dart';

import '../theme/hive_colors.dart';

class PlaceholderScreenScaffold extends StatelessWidget {
  const PlaceholderScreenScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.showAppBar = true,
    this.footer,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool showAppBar;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HiveColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: HiveColors.outline),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 64,
                        width: 64,
                        decoration: const BoxDecoration(
                          color: HiveColors.surface,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, size: 30, color: HiveColors.honey),
                      ),
                      const SizedBox(height: 24),
                      Text(title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 12),
                      Text(
                        description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: HiveColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 24),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
