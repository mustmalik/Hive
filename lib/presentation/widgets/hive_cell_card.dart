import 'package:flutter/material.dart';

import '../theme/hive_colors.dart';

class HiveCellCard extends StatelessWidget {
  const HiveCellCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.assetCount,
    required this.accentColor,
    required this.icon,
    required this.onTap,
    this.featured = false,
  });

  final String title;
  final String subtitle;
  final int assetCount;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: featured ? 0.3 : 0.22),
                HiveColors.surfaceElevated,
              ],
            ),
            border: Border.all(color: accentColor.withValues(alpha: 0.34)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 22,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, featured ? 22 : 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, size: 22, color: accentColor),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: HiveColors.background.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$assetCount',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: HiveColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: featured ? 54 : 38),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: featured ? 22 : 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: HiveColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Open Cell',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accentColor,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
