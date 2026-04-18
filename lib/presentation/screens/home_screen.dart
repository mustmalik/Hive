import 'package:flutter/material.dart';

import '../theme/hive_colors.dart';
import '../widgets/hive_cell_card.dart';
import '../widgets/hive_shell_background.dart';
import 'folder_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _cells = [
    _MockHiveCell(
      name: 'Pets',
      assetCount: 128,
      accentColor: Color(0xFFE59E4D),
      icon: Icons.pets_rounded,
      note: 'Warm moments and familiar faces',
      featured: true,
    ),
    _MockHiveCell(
      name: 'Travel',
      assetCount: 84,
      accentColor: Color(0xFFF0C777),
      icon: Icons.flight_takeoff_rounded,
      note: 'Trips, weekends, and new places',
    ),
    _MockHiveCell(
      name: 'Food',
      assetCount: 62,
      accentColor: Color(0xFFC88538),
      icon: Icons.restaurant_rounded,
      note: 'Plates worth saving',
    ),
    _MockHiveCell(
      name: 'Basketball',
      assetCount: 41,
      accentColor: Color(0xFFB8732C),
      icon: Icons.sports_basketball_rounded,
      note: 'Game nights and court-side shots',
      featured: true,
    ),
    _MockHiveCell(
      name: 'Unsorted',
      assetCount: 214,
      accentColor: Color(0xFF8F6B46),
      icon: Icons.auto_awesome_mosaic_rounded,
      note: 'The next clean-up pass',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: HiveShellBackground(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    const _HomeBrandMark(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HIVE',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: HiveColors.honey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'A local-first home for your gallery',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: HiveColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: HiveColors.surface.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: HiveColors.outline),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 16,
                            color: HiveColors.honey,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Local Only',
                            style: TextStyle(
                              color: HiveColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF382616), Color(0xFF201914)],
                    ),
                    border: Border.all(color: HiveColors.outline),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 24,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: HiveColors.honey.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: HiveColors.honey.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          'Gallery Home',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: HiveColors.honey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Your cells are ready when the next scan is.',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Build a calmer layer on top of your library without touching a single original Apple Photos asset.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: HiveColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Scan pipeline foundation is ready. Real scan execution comes next.',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.hive_outlined),
                              label: const Text('Start Scan'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: HiveColors.surface.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: HiveColors.outline),
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    final cardWidth = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 3;

                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatCard(
                          width: cardWidth,
                          label: 'Total Assets',
                          value: '529',
                        ),
                        _StatCard(
                          width: cardWidth,
                          label: 'Total Cells',
                          value: '12',
                        ),
                        _StatCard(
                          width: cardWidth,
                          label: 'Last Scan',
                          value: 'Today',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cells', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            'A premium preview of your next organization layer.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: HiveColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: HiveColors.surface.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: HiveColors.outline),
                      ),
                      child: Text(
                        '${_cells.length} visible',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: HiveColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 14) / 2;

                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (var index = 0; index < _cells.length; index++)
                          Padding(
                            padding: EdgeInsets.only(top: index.isOdd ? 18 : 0),
                            child: SizedBox(
                              width: itemWidth,
                              child: HiveCellCard(
                                title: _cells[index].name,
                                subtitle: _cells[index].note,
                                assetCount: _cells[index].assetCount,
                                accentColor: _cells[index].accentColor,
                                icon: _cells[index].icon,
                                featured: _cells[index].featured,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => FolderDetailScreen(
                                        cellName: _cells[index].name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: HiveColors.surfaceElevated.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(26),
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
                        child: const Icon(Icons.auto_awesome_rounded, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ready for the scan foundation',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This shell is prepared for real asset counts, generated cells, and scan history as soon as the pipeline gets wired in.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: HiveColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _HomeBrandMark extends StatelessWidget {
  const _HomeBrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HiveColors.amberGlow, HiveColors.honeyDeep],
        ),
      ),
      child: Center(
        child: Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: HiveColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            size: 18,
            color: HiveColors.honey,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: HiveColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _MockHiveCell {
  const _MockHiveCell({
    required this.name,
    required this.assetCount,
    required this.accentColor,
    required this.icon,
    required this.note,
    this.featured = false,
  });

  final String name;
  final int assetCount;
  final Color accentColor;
  final IconData icon;
  final String note;
  final bool featured;
}
