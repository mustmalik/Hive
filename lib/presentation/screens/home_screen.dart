import 'package:flutter/material.dart';

import '../../application/models/media_album.dart';
import '../../application/models/scan_scope.dart';
import '../../application/services/folder_detail_service.dart';
import '../../application/models/home_dashboard_snapshot.dart';
import '../../application/services/home_dashboard_service.dart';
import '../../application/services/media_library_service.dart';
import '../../application/services/scan_coordinator.dart';
import '../../application/services/thumbnail_service.dart';
import '../../data/services/persisted_folder_detail_service.dart';
import '../../data/services/persisted_home_dashboard_service.dart';
import '../../data/services/photo_manager_media_library_service.dart';
import '../../data/services/photo_manager_thumbnail_service.dart';
import '../../data/services/real_scan_coordinator.dart';
import '../theme/hive_colors.dart';
import '../widgets/hive_cell_card.dart';
import '../widgets/hive_shell_background.dart';
import 'folder_detail_screen.dart';
import 'scan_progress_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.homeDashboardService,
    this.mediaLibraryService,
    this.createScanCoordinator,
    this.createFolderDetailService,
    this.createThumbnailService,
  });

  final HomeDashboardService? homeDashboardService;
  final MediaLibraryService? mediaLibraryService;
  final ScanCoordinator Function()? createScanCoordinator;
  final FolderDetailService Function()? createFolderDetailService;
  final ThumbnailService Function()? createThumbnailService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeDashboardService _homeDashboardService;
  late final MediaLibraryService _mediaLibraryService;
  late Future<HomeDashboardSnapshot> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _homeDashboardService =
        widget.homeDashboardService ?? PersistedHomeDashboardService.standard();
    _mediaLibraryService =
        widget.mediaLibraryService ?? const PhotoManagerMediaLibraryService();
    _reloadDashboard();
  }

  void _reloadDashboard() {
    _dashboardFuture = _homeDashboardService.loadDashboard();
  }

  Future<void> _openScanProgress(ScanScope scope) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScanProgressScreen(
          scanScope: scope,
          scanCoordinator:
              widget.createScanCoordinator?.call() ??
              RealScanCoordinator.seeded(),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _reloadDashboard();
    });
  }

  Future<void> _chooseScanScope() async {
    final scope = await showModalBottomSheet<ScanScope>(
      context: context,
      backgroundColor: HiveColors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return _ScanScopeSheet(mediaLibraryService: _mediaLibraryService);
      },
    );

    if (!mounted || scope == null) {
      return;
    }

    await _openScanProgress(scope);
  }

  Future<void> _openFolderDetail(
    HomeDashboardSnapshot dashboard,
    int index,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FolderDetailScreen(
          cellId: dashboard.visibleCells[index].id,
          cellName: dashboard.visibleCells[index].name,
          folderDetailService:
              widget.createFolderDetailService?.call() ??
              PersistedFolderDetailService.standard(),
          thumbnailService:
              widget.createThumbnailService?.call() ??
              const PhotoManagerThumbnailService(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: HiveShellBackground(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          bottom: false,
          child: FutureBuilder<HomeDashboardSnapshot>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              final dashboard = snapshot.data;

              return SingleChildScrollView(
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
                                  onPressed: _chooseScanScope,
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
                                  color: HiveColors.surface.withValues(
                                    alpha: 0.78,
                                  ),
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
                    const SizedBox(height: 16),
                    _StatsStrip(
                      totalAssets: dashboard?.totalAssetCount,
                      totalCells: dashboard?.totalCellCount,
                      lastScanLabel: _formatLastScanLabel(
                        dashboard?.lastCompletedScanAt,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cells',
                                style: theme.textTheme.headlineSmall,
                              ),
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
                            dashboard == null
                                ? 'Loading'
                                : '${dashboard.visibleCells.length} visible',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: HiveColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (dashboard == null)
                      const _HomeLoadingState()
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth = (constraints.maxWidth - 14) / 2;

                          return Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              for (
                                var index = 0;
                                index < dashboard.visibleCells.length;
                                index++
                              )
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: index.isOdd ? 18 : 0,
                                  ),
                                  child: SizedBox(
                                    width: itemWidth,
                                    child: HiveCellCard(
                                      title: dashboard.visibleCells[index].name,
                                      subtitle:
                                          dashboard.visibleCells[index].summary,
                                      assetCount: dashboard
                                          .visibleCells[index]
                                          .assetCount,
                                      accentColor: _styleFor(
                                        dashboard.visibleCells[index].styleKey,
                                      ).color,
                                      icon: _styleFor(
                                        dashboard.visibleCells[index].styleKey,
                                      ).icon,
                                      featured: dashboard
                                          .visibleCells[index]
                                          .featured,
                                      onTap: () =>
                                          _openFolderDetail(dashboard, index),
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
                        color: HiveColors.surfaceElevated.withValues(
                          alpha: 0.92,
                        ),
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
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 20,
                            ),
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
                                  'This shell is prepared for real asset counts, broader cells, and faster test scans from one chosen scope.',
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
                    const SizedBox(height: 42),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatLastScanLabel(DateTime? lastCompletedScanAt) {
    if (lastCompletedScanAt == null) {
      return 'Not yet';
    }

    final now = DateTime.now();
    final difference = now.difference(lastCompletedScanAt);

    if (difference.inDays == 0) {
      return 'Today';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    return '${difference.inDays}d ago';
  }

  _HomeCellStyle _styleFor(String styleKey) {
    return switch (styleKey) {
      'people' => const _HomeCellStyle(
        color: Color(0xFFE2B06C),
        icon: Icons.people_alt_rounded,
      ),
      'family' => const _HomeCellStyle(
        color: Color(0xFFF1C98B),
        icon: Icons.family_restroom_rounded,
      ),
      'pets' => const _HomeCellStyle(
        color: Color(0xFFE59E4D),
        icon: Icons.pets_rounded,
      ),
      'travel' => const _HomeCellStyle(
        color: Color(0xFFF0C777),
        icon: Icons.flight_takeoff_rounded,
      ),
      'food' => const _HomeCellStyle(
        color: Color(0xFFC88538),
        icon: Icons.restaurant_rounded,
      ),
      'screenshots' => const _HomeCellStyle(
        color: Color(0xFFBCA078),
        icon: Icons.screenshot_monitor_rounded,
      ),
      'tech' => const _HomeCellStyle(
        color: Color(0xFFB98A56),
        icon: Icons.devices_rounded,
      ),
      'documents' => const _HomeCellStyle(
        color: Color(0xFFD1A667),
        icon: Icons.receipt_long_rounded,
      ),
      'sports' => const _HomeCellStyle(
        color: Color(0xFFB8732C),
        icon: Icons.sports_soccer_rounded,
      ),
      'animation' => const _HomeCellStyle(
        color: Color(0xFFC78D4A),
        icon: Icons.theater_comedy_rounded,
      ),
      'unsorted' => const _HomeCellStyle(
        color: Color(0xFF8F6B46),
        icon: Icons.auto_awesome_mosaic_rounded,
      ),
      _ => const _HomeCellStyle(
        color: HiveColors.honey,
        icon: Icons.folder_open_rounded,
      ),
    };
  }
}

class _ScanScopeSheet extends StatelessWidget {
  const _ScanScopeSheet({required this.mediaLibraryService});

  final MediaLibraryService mediaLibraryService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: FutureBuilder<List<MediaAlbum>>(
          future: mediaLibraryService.getAvailableAlbums(),
          builder: (context, snapshot) {
            final albums = snapshot.data ?? const <MediaAlbum>[];

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: HiveColors.outline,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Choose Scan Scope', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  'Pick a smaller slice for fast iteration or scan the whole accessible library.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: HiveColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                _ScopeOptionTile(
                  title: 'All Photos',
                  subtitle: 'Scan the full accessible library.',
                  icon: Icons.photo_library_rounded,
                  onTap: () =>
                      Navigator.of(context).pop(const ScanScope.allPhotos()),
                ),
                const SizedBox(height: 10),
                _ScopeOptionTile(
                  title: 'Limited-Access Photos',
                  subtitle:
                      'Scan the photos currently available to HIVE under limited access.',
                  icon: Icons.verified_user_outlined,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const ScanScope.limitedPhotos()),
                ),
                const SizedBox(height: 18),
                Text(
                  'Albums & Folders',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: HiveColors.honey,
                  ),
                ),
                const SizedBox(height: 10),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (albums.isEmpty)
                  Text(
                    'No smaller albums are available yet. You can still scan all accessible photos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HiveColors.textSecondary,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: albums.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return _ScopeOptionTile(
                          title: album.name,
                          subtitle:
                              '${album.assetCount} assets • ${album.isFolder ? 'Folder' : 'Album'}',
                          icon: album.isFolder
                              ? Icons.folder_open_rounded
                              : Icons.collections_bookmark_rounded,
                          onTap: () => Navigator.of(context).pop(
                            ScanScope.album(
                              albumId: album.id,
                              albumName: album.name,
                              isFolder: album.isFolder,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScopeOptionTile extends StatelessWidget {
  const _ScopeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HiveColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HiveColors.outline),
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: HiveColors.honey.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: HiveColors.honey, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: HiveColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, color: HiveColors.honey),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.totalAssets,
    required this.totalCells,
    required this.lastScanLabel,
  });

  final int? totalAssets;
  final int? totalCells;
  final String lastScanLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HiveColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatsItem(
              label: 'Assets',
              value: totalAssets?.toString() ?? '...',
            ),
          ),
          const _StatsDivider(),
          Expanded(
            child: _StatsItem(
              label: 'Cells',
              value: totalCells?.toString() ?? '...',
            ),
          ),
          const _StatsDivider(),
          Expanded(
            child: _StatsItem(
              label: 'Last Scan',
              value: lastScanLabel,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsItem extends StatelessWidget {
  const _StatsItem({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: HiveColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatsDivider extends StatelessWidget {
  const _StatsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: HiveColors.outline,
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
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

class _HomeCellStyle {
  const _HomeCellStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
