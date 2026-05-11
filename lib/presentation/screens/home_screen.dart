import 'package:flutter/material.dart';

import '../../application/models/classification_backend.dart';
import '../../application/models/media_album.dart';
import '../../application/models/scan_scope.dart';
import '../../application/services/asset_preview_service.dart';
import '../../application/services/folder_detail_service.dart';
import '../../application/models/home_dashboard_snapshot.dart';
import '../../application/services/home_dashboard_service.dart';
import '../../application/services/manual_recategorization_service.dart';
import '../../application/services/media_library_service.dart';
import '../../application/services/scan_coordinator.dart';
import '../../application/services/settings_service.dart';
import '../../application/services/thumbnail_service.dart';
import '../../data/services/persisted_folder_detail_service.dart';
import '../../data/services/persisted_home_dashboard_service.dart';
import '../../data/services/persisted_manual_recategorization_service.dart';
import '../../data/services/local_settings_service.dart';
import '../../data/services/photo_manager_asset_preview_service.dart';
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
    this.createManualRecategorizationService,
    this.createThumbnailService,
    this.createAssetPreviewService,
    this.settingsService,
    this.classificationBackend = ClassificationBackend.appleVision,
  });

  final HomeDashboardService? homeDashboardService;
  final MediaLibraryService? mediaLibraryService;
  final ScanCoordinator Function()? createScanCoordinator;
  final FolderDetailService Function()? createFolderDetailService;
  final ManualRecategorizationService Function()?
  createManualRecategorizationService;
  final ThumbnailService Function()? createThumbnailService;
  final AssetPreviewService Function()? createAssetPreviewService;
  final SettingsService? settingsService;
  final ClassificationBackend classificationBackend;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeDashboardService _homeDashboardService;
  late final MediaLibraryService _mediaLibraryService;
  late final SettingsService _settingsService;
  late Future<HomeDashboardSnapshot> _dashboardFuture;
  ScanScope _selectedScanScope = const ScanScope.fullLibrary();
  ScanScope? _rememberedScope;
  PhotoAlbum? _selectedAlbum;
  List<PhotoAlbum> _availableAlbums = const [];
  bool _isLoadingRememberedScope = true;
  bool _isAlbumScopeMode = false;
  bool _isLoadingAlbums = false;
  bool _isStartingScan = false;
  String? _albumsError;
  String? _scopeMessage;

  @override
  void initState() {
    super.initState();
    _homeDashboardService =
        widget.homeDashboardService ?? PersistedHomeDashboardService.standard();
    _mediaLibraryService =
        widget.mediaLibraryService ?? const PhotoManagerMediaLibraryService();
    _settingsService =
        widget.settingsService ?? LocalSettingsService.standard();
    _reloadDashboard();
    _loadRememberedScope();
  }

  void _reloadDashboard() {
    _dashboardFuture = _homeDashboardService.loadDashboard();
  }

  Future<void> _loadRememberedScope() async {
    final settings = await _settingsService.loadSettings();
    if (!mounted) {
      return;
    }

    setState(() {
      _rememberedScope = settings.lastUsedScanScope;
      _isLoadingRememberedScope = false;
    });
  }

  Future<void> _rememberScope(ScanScope scope) async {
    final current = await _settingsService.loadSettings();
    await _settingsService.saveSettings(
      current.copyWith(lastUsedScanScope: scope),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _rememberedScope = scope;
    });
  }

  Future<void> _openScanProgress(ScanScope scope) async {
    final navigator = Navigator.of(context);
    await _rememberScope(scope);
    if (!mounted) {
      return;
    }
    final nextAction = await navigator.push<ScanProgressNextAction>(
      MaterialPageRoute<ScanProgressNextAction>(
        builder: (_) => ScanProgressScreen(
          scanScope: scope,
          scanCoordinator:
              widget.createScanCoordinator?.call() ??
              RealScanCoordinator.seeded(
                classificationBackend: widget.classificationBackend,
              ),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _reloadDashboard();
    });

    if (nextAction == ScanProgressNextAction.changeScope && mounted) {
      await _chooseScanScope();
    }
  }

  Future<void> _startSelectedScan() async {
    if (_isStartingScan) {
      return;
    }

    final blockedReason = _scanBlockReason();
    if (blockedReason != null) {
      setState(() {
        _scopeMessage = blockedReason;
      });
      return;
    }

    final scope = _selectedScanScope;
    if (scope.isAlbumSelection) {
      setState(() {
        _isStartingScan = true;
        _scopeMessage = null;
      });

      final count = await _resolveSelectedAlbumCount(scope);
      if (!mounted) {
        return;
      }

      if (count <= 0) {
        setState(() {
          _isStartingScan = false;
          _scopeMessage = 'This album appears to be empty.';
        });
        return;
      }

      setState(() {
        _isStartingScan = false;
      });
    }

    await _openScanProgress(scope);
  }

  Future<void> _chooseScanScope() async {
    final action = await showModalBottomSheet<_ScopePickerAction>(
      context: context,
      backgroundColor: HiveColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return const _ScopeModeSheet();
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _ScopePickerAction.fullLibrary:
        _selectFullLibraryScope();
      case _ScopePickerAction.album:
        await _selectAlbumScope();
    }
  }

  void _selectFullLibraryScope() {
    setState(() {
      _selectedScanScope = const ScanScope.fullLibrary();
      _selectedAlbum = null;
      _isAlbumScopeMode = false;
      _scopeMessage = null;
      _albumsError = null;
    });
  }

  Future<void> _selectAlbumScope() async {
    setState(() {
      _isAlbumScopeMode = true;
      _scopeMessage = null;
    });

    await _showAlbumPicker();
  }

  void _selectRememberedScope() {
    final rememberedScope = _rememberedScope;
    if (rememberedScope == null) {
      return;
    }

    setState(() {
      _selectedScanScope = rememberedScope;
      _isAlbumScopeMode = rememberedScope.isAlbumSelection;
      _selectedAlbum = null;
      _scopeMessage = null;
      _albumsError = null;
    });
  }

  Future<void> _showAlbumPicker() async {
    final loaded = await _ensureAlbumsLoaded();
    if (!mounted || !loaded) {
      return;
    }

    final selectedAlbum = await showModalBottomSheet<PhotoAlbum>(
      context: context,
      backgroundColor: HiveColors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return _AlbumPickerSheet(
          albums: _availableAlbums,
          selectedAlbumId: _selectedAlbum?.id ?? _selectedScanScope.albumId,
        );
      },
    );

    if (!mounted || selectedAlbum == null) {
      if (_selectedScanScope.isAlbumSelection) {
        return;
      }

      setState(() {
        _scopeMessage = 'Select an album first.';
      });
      return;
    }

    _applyAlbumSelection(selectedAlbum);
  }

  Future<bool> _ensureAlbumsLoaded() async {
    if (_availableAlbums.isNotEmpty) {
      return true;
    }

    setState(() {
      _isLoadingAlbums = true;
      _albumsError = null;
    });

    try {
      final albums = await _mediaLibraryService.fetchAlbums(limit: 200);
      if (!mounted) {
        return false;
      }

      setState(() {
        _availableAlbums = albums;
        _isLoadingAlbums = false;
      });
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _isLoadingAlbums = false;
        _albumsError = 'Unable to load albums right now.';
        _scopeMessage = _albumsError;
      });
      return false;
    }
  }

  void _applyAlbumSelection(PhotoAlbum album) {
    setState(() {
      _selectedAlbum = album;
      _isAlbumScopeMode = true;
      _selectedScanScope = ScanScope.album(
        albumId: album.id,
        albumTitle: album.title,
        isFolder: album.isFolder,
      );
      _scopeMessage = album.assetCount <= 0
          ? 'This album appears to be empty.'
          : null;
      _albumsError = null;
    });
  }

  String? _scanBlockReason() {
    if (!_isAlbumScopeMode) {
      return null;
    }

    if (!_selectedScanScope.isAlbumSelection) {
      return 'Select an album first.';
    }

    final selectedAlbum = _selectedAlbum;
    if (selectedAlbum != null && selectedAlbum.assetCount <= 0) {
      return 'This album appears to be empty.';
    }

    return null;
  }

  Future<int> _resolveSelectedAlbumCount(ScanScope scope) async {
    try {
      return _mediaLibraryService.getEstimatedAssetCount(scope: scope);
    } catch (_) {
      return 0;
    }
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
          classificationBackend: widget.classificationBackend,
          folderDetailService:
              widget.createFolderDetailService?.call() ??
              PersistedFolderDetailService.standard(),
          manualRecategorizationService:
              widget.createManualRecategorizationService?.call() ??
              PersistedManualRecategorizationService.standard(),
          thumbnailService:
              widget.createThumbnailService?.call() ??
              const PhotoManagerThumbnailService(),
          assetPreviewService:
              widget.createAssetPreviewService?.call() ??
              const PhotoManagerAssetPreviewService(),
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
                                  onPressed: _isStartingScan
                                      ? null
                                      : _startSelectedScan,
                                  icon: const Icon(Icons.hive_outlined),
                                  label: Text(
                                    _isStartingScan
                                        ? 'Checking Scope'
                                        : 'Start Scan',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 52,
                                child: OutlinedButton(
                                  onPressed: _chooseScanScope,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _ScanScopeControl(
                            selectedScope: _selectedScanScope,
                            selectedAlbum: _selectedAlbum,
                            isAlbumScopeMode: _isAlbumScopeMode,
                            isLoadingAlbums: _isLoadingAlbums,
                            message: _scopeMessage,
                            error: _albumsError,
                            onSelectFullLibrary: _selectFullLibraryScope,
                            onSelectAlbum: _selectAlbumScope,
                            onChangeAlbum: _showAlbumPicker,
                          ),
                          const SizedBox(height: 14),
                          _RememberedScopeBanner(
                            rememberedScope: _rememberedScope,
                            isLoading: _isLoadingRememberedScope,
                            onUseLast: _rememberedScope == null
                                ? null
                                : _selectRememberedScope,
                            onChange: _chooseScanScope,
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
                    else if (!dashboard.hasCompletedScan)
                      _HomeEmptyState(
                        title: 'Your first HIVE scan starts here',
                        description:
                            'Run one local-only pass to turn your accessible library into smart virtual cells without moving a single original asset.',
                        actionLabel: 'Start Your First Scan',
                        onAction: _startSelectedScan,
                        secondaryLabel: 'Choose Scope',
                        onSecondary: _chooseScanScope,
                        icon: Icons.hive_outlined,
                      )
                    else if (!dashboard.hasMeaningfulCells)
                      _HomeEmptyState(
                        title:
                            'This scan finished, but the cells need a stronger pass',
                        description:
                            'Try a tighter scope, rerun the same slice, or use manual corrections to sharpen the next result.',
                        actionLabel: 'Rescan',
                        onAction: _startSelectedScan,
                        secondaryLabel: 'Change Scope',
                        onSecondary: _chooseScanScope,
                        icon: Icons.auto_awesome_mosaic_rounded,
                      )
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
                    _HomeFooterCard(
                      title: dashboard == null
                          ? 'Preparing your gallery surface'
                          : dashboard.hasCompletedScan
                          ? 'Ready for another clean pass'
                          : 'Ready for your first result',
                      description: dashboard == null
                          ? 'HIVE is loading your latest local snapshot.'
                          : dashboard.hasCompletedScan
                          ? 'You can review results, rerun the same scope, or tighten the next scan for a cleaner set of cells.'
                          : 'Once the first scan finishes, HIVE will surface your strongest local-only cells here.',
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
      'places' => const _HomeCellStyle(
        color: Color(0xFFD6B36C),
        icon: Icons.landscape_rounded,
      ),
      'food' => const _HomeCellStyle(
        color: Color(0xFFC88538),
        icon: Icons.restaurant_rounded,
      ),
      'videos' => const _HomeCellStyle(
        color: Color(0xFFD69A58),
        icon: Icons.videocam_rounded,
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

enum _ScopePickerAction { fullLibrary, album }

class _ScanScopeControl extends StatelessWidget {
  const _ScanScopeControl({
    required this.selectedScope,
    required this.selectedAlbum,
    required this.isAlbumScopeMode,
    required this.isLoadingAlbums,
    required this.onSelectFullLibrary,
    required this.onSelectAlbum,
    required this.onChangeAlbum,
    this.message,
    this.error,
  });

  final ScanScope selectedScope;
  final PhotoAlbum? selectedAlbum;
  final bool isAlbumScopeMode;
  final bool isLoadingAlbums;
  final String? message;
  final String? error;
  final VoidCallback onSelectFullLibrary;
  final VoidCallback onSelectAlbum;
  final VoidCallback onChangeAlbum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedAlbum = this.selectedAlbum;
    final hasSelectedAlbum = isAlbumScopeMode && selectedScope.isAlbumSelection;
    final statusLabel = !isAlbumScopeMode
        ? 'Scope: Full library'
        : hasSelectedAlbum
        ? selectedAlbum == null
              ? 'Scope: ${selectedScope.albumTitle ?? selectedScope.label}'
              : 'Scope: ${selectedAlbum.title} (${selectedAlbum.assetCount})'
        : 'Scope: Select an album first';
    final helperMessage = error ?? message;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HiveColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan scope',
            style: theme.textTheme.labelLarge?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ScopeToggleButton(
                  title: 'Full library',
                  selected: !isAlbumScopeMode,
                  onTap: onSelectFullLibrary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScopeToggleButton(
                  title: 'By album',
                  selected: isAlbumScopeMode,
                  onTap: onSelectAlbum,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasSelectedAlbum || !isAlbumScopeMode
                  ? HiveColors.textPrimary
                  : HiveColors.textSecondary,
            ),
          ),
          if (isLoadingAlbums) ...[
            const SizedBox(height: 6),
            Text(
              'Loading albums…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: HiveColors.textSecondary,
              ),
            ),
          ],
          if (helperMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              helperMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: error == null ? HiveColors.textSecondary : Colors.red,
              ),
            ),
          ],
          if (hasSelectedAlbum) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onChangeAlbum,
              child: const Text('Change album'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScopeToggleButton extends StatelessWidget {
  const _ScopeToggleButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 18,
      ),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? HiveColors.honey : HiveColors.textPrimary,
        side: BorderSide(
          color: selected ? HiveColors.honey : HiveColors.outline,
        ),
        textStyle: theme.textTheme.labelLarge,
      ),
    );
  }
}

class _ScopeModeSheet extends StatelessWidget {
  const _ScopeModeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
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
              'Pick the whole accessible library or select one album for a targeted debug pass.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: HiveColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _ScopeOptionTile(
              title: 'Full library',
              subtitle: 'Scan the full accessible library.',
              icon: Icons.photo_library_rounded,
              onTap: () =>
                  Navigator.of(context).pop(_ScopePickerAction.fullLibrary),
            ),
            const SizedBox(height: 10),
            _ScopeOptionTile(
              title: 'By album',
              subtitle: 'Pick one album for a smaller targeted scan.',
              icon: Icons.collections_bookmark_rounded,
              onTap: () => Navigator.of(context).pop(_ScopePickerAction.album),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumPickerSheet extends StatelessWidget {
  const _AlbumPickerSheet({required this.albums, this.selectedAlbumId});

  final List<PhotoAlbum> albums;
  final String? selectedAlbumId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
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
            Text('Select Album', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Choose one album for this scan. Thumbnails and multi-select can wait for a later pass.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: HiveColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            if (albums.isEmpty)
              Text(
                'No albums are available yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: HiveColors.textSecondary,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: albums.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    return _AlbumOptionTile(
                      album: album,
                      selected: album.id == selectedAlbumId,
                      onTap: () => Navigator.of(context).pop(album),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlbumOptionTile extends StatelessWidget {
  const _AlbumOptionTile({
    required this.album,
    required this.selected,
    required this.onTap,
  });

  final PhotoAlbum album;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeLabel = album.isSmartAlbum
        ? 'Smart'
        : album.isUserAlbum
        ? null
        : 'System';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? HiveColors.honey.withValues(alpha: 0.14)
                : HiveColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? HiveColors.honey.withValues(alpha: 0.32)
                  : HiveColors.outline,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.collections_bookmark_rounded,
                color: HiveColors.honey,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(album.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      _formatAlbumAssetCount(album.assetCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: HiveColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: HiveColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: HiveColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatAlbumAssetCount(int count) {
    if (count == 1) {
      return '1 asset';
    }

    return '$count assets';
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

class _RememberedScopeBanner extends StatelessWidget {
  const _RememberedScopeBanner({
    required this.rememberedScope,
    required this.isLoading,
    required this.onChange,
    this.onUseLast,
  });

  final ScanScope? rememberedScope;
  final bool isLoading;
  final VoidCallback onChange;
  final VoidCallback? onUseLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 8),
          Text(
            'Restoring your last scan scope',
            style: theme.textTheme.bodySmall?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
        ],
      );
    }

    if (rememberedScope == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune_rounded, size: 16, color: HiveColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            'Choose a smaller scope once, and HIVE will remember it for faster rescans.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: onChange, child: const Text('Choose')),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HiveColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: HiveColors.honey.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: HiveColors.honey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last scope',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: HiveColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rememberedScope!.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: HiveColors.honey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (onUseLast != null)
                TextButton(onPressed: onUseLast, child: const Text('Use')),
              TextButton(onPressed: onChange, child: const Text('Change')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.icon,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String description;
  final String actionLabel;
  final IconData icon;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: HiveColors.surfaceElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: HiveColors.honey.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: HiveColors.honey, size: 24),
          ),
          const SizedBox(height: 18),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeFooterCard extends StatelessWidget {
  const _HomeFooterCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
