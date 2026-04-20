import 'package:flutter/material.dart';

import '../../application/models/classification_outcome.dart';
import '../../application/models/folder_detail_item.dart';
import '../../application/models/folder_detail_snapshot.dart';
import '../../application/services/folder_detail_service.dart';
import '../../application/services/manual_recategorization_service.dart';
import '../../application/services/thumbnail_service.dart';
import '../../data/services/persisted_folder_detail_service.dart';
import '../../data/services/persisted_manual_recategorization_service.dart';
import '../../data/services/photo_manager_thumbnail_service.dart';
import '../theme/hive_colors.dart';
import '../widgets/hive_shell_background.dart';
import 'photo_viewer_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  const FolderDetailScreen({
    super.key,
    required this.cellId,
    required this.cellName,
    this.folderDetailService,
    this.manualRecategorizationService,
    this.thumbnailService,
  });

  final String cellId;
  final String cellName;
  final FolderDetailService? folderDetailService;
  final ManualRecategorizationService? manualRecategorizationService;
  final ThumbnailService? thumbnailService;

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  late final FolderDetailService _folderDetailService;
  late final ManualRecategorizationService _manualRecategorizationService;
  late final ThumbnailService _thumbnailService;
  late Future<FolderDetailSnapshot?> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _folderDetailService =
        widget.folderDetailService ?? PersistedFolderDetailService.standard();
    _manualRecategorizationService =
        widget.manualRecategorizationService ??
        PersistedManualRecategorizationService.standard();
    _thumbnailService =
        widget.thumbnailService ?? const PhotoManagerThumbnailService();
    _snapshotFuture = _loadSnapshot();
  }

  Future<FolderDetailSnapshot?> _loadSnapshot() {
    return _folderDetailService.loadCell(widget.cellId);
  }

  void _refreshSnapshot() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  Future<void> _openAssetDetail(FolderDetailItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PhotoViewerScreen(
          item: item,
          originCellId: widget.cellId,
          originCellName: widget.cellName,
          manualRecategorizationService: _manualRecategorizationService,
          thumbnailService: _thumbnailService,
        ),
      ),
    );

    if (!mounted || changed != true) {
      return;
    }

    _refreshSnapshot();
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
          child: FutureBuilder<FolderDetailSnapshot?>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              final detail = snapshot.data;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: IconButton.styleFrom(
                                backgroundColor: HiveColors.surface.withValues(
                                  alpha: 0.84,
                                ),
                                foregroundColor: HiveColors.textPrimary,
                              ),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detail?.cellName ?? widget.cellName,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: HiveColors.honey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    detail == null
                                        ? 'Loading cell members'
                                        : '${detail.totalCount} assets in this cell',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: HiveColors.textSecondary,
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
                                  color: HiveColors.honey.withValues(
                                    alpha: 0.13,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Virtual Cell',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: HiveColors.honey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                detail?.cellName ?? widget.cellName,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                detail?.description ??
                                    'Loading your latest local scan result for this cell.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: HiveColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DetailStatCard(
                                      label: 'Members',
                                      value: detail == null
                                          ? '...'
                                          : '${detail.totalCount}',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: _DetailStatCard(
                                      label: 'Viewer',
                                      value: 'Ready',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Members',
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap any asset to open its larger HIVE detail view with quick actions.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: HiveColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                  if (snapshot.connectionState != ConnectionState.done)
                    const SliverToBoxAdapter(child: _FolderLoadingGrid())
                  else if (detail == null || detail.items.isEmpty)
                    const SliverToBoxAdapter(child: _EmptyCellState())
                  else
                    SliverGrid(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _FolderAssetCard(
                          item: detail.items[index],
                          thumbnailService: _thumbnailService,
                          onTap: () => _openAssetDetail(detail.items[index]),
                        );
                      }, childCount: detail.items.length),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.78,
                          ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailStatCard extends StatelessWidget {
  const _DetailStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: HiveColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _FolderAssetCard extends StatelessWidget {
  const _FolderAssetCard({
    required this.item,
    required this.thumbnailService,
    required this.onTap,
  });

  final FolderDetailItem item;
  final ThumbnailService thumbnailService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final explanation = item.mappingExplanation;
    final classificationOutcome = item.classificationOutcome;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: HiveColors.surfaceElevated.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: HiveColors.outline),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FutureBuilder(
                    future: thumbnailService.loadThumbnail(
                      asset: item.asset,
                      size: 320,
                    ),
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return Container(
                          color: HiveColors.surfaceMuted,
                          child: Center(
                            child: Icon(
                              item.asset.isVideo
                                  ? Icons.play_circle_outline_rounded
                                  : Icons.photo_outlined,
                              size: 34,
                              color: HiveColors.honey,
                            ),
                          ),
                        );
                      }

                      return Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (explanation != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: explanation.usedFallback
                                ? HiveColors.surfaceMuted
                                : HiveColors.honey.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: explanation.usedFallback
                                  ? HiveColors.outline
                                  : HiveColors.honey.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            explanation.isManualOverride
                                ? 'Moved manually'
                                : explanation.usedFallback
                                ? 'Mapped to Unsorted'
                                : 'Mapped to ${explanation.cellName}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  explanation.usedFallback &&
                                      !explanation.isManualOverride
                                  ? HiveColors.textSecondary
                                  : HiveColors.honey,
                            ),
                          ),
                        ),
                      if (explanation != null) const SizedBox(height: 10),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: HiveColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        explanation?.isManualOverride == true
                            ? 'Manual placement'
                            : classificationOutcome != null
                            ? _classificationBadgeText(classificationOutcome)
                            : 'Open viewer',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: HiveColors.honey,
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

  String _classificationBadgeText(ClassificationOutcome outcome) {
    return switch (outcome.status) {
      ClassificationOutcomeStatus.succeeded => 'Open viewer',
      ClassificationOutcomeStatus.noLabelsReturned => 'No labels returned',
      ClassificationOutcomeStatus.imagePreparationFailed =>
        'Image prep needs review',
      ClassificationOutcomeStatus.requestFailed => 'Classification paused',
      ClassificationOutcomeStatus.unsupportedAsset => 'Not classifiable',
    };
  }
}

class _FolderLoadingGrid extends StatelessWidget {
  const _FolderLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: HiveColors.surfaceElevated.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: HiveColors.outline),
          ),
        );
      },
    );
  }
}

class _EmptyCellState extends StatelessWidget {
  const _EmptyCellState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HiveColors.surfaceElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 36,
            color: HiveColors.honey,
          ),
          const SizedBox(height: 12),
          Text('No saved members yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Run a fresh scan to populate this cell with local-only HIVE membership results.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
