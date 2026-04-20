import 'package:flutter/material.dart';

import '../../application/models/classification_outcome.dart';
import '../../application/models/folder_detail_item.dart';
import '../../application/models/folder_detail_snapshot.dart';
import '../../application/models/hive_cell_category.dart';
import '../../application/services/folder_detail_service.dart';
import '../../application/services/manual_recategorization_service.dart';
import '../../application/services/thumbnail_service.dart';
import '../../data/services/persisted_folder_detail_service.dart';
import '../../data/services/persisted_manual_recategorization_service.dart';
import '../../data/services/photo_manager_thumbnail_service.dart';
import '../../domain/entities/classification_label.dart';
import '../theme/hive_colors.dart';
import '../widgets/hive_shell_background.dart';

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
  bool _isApplyingMove = false;

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

  List<HiveCellCategory> _targetCells() {
    return _manualRecategorizationService.availableTargetCells
        .where((cell) => cell.id != widget.cellId)
        .toList(growable: false);
  }

  Future<void> _showExplanationSheet(FolderDetailItem item) {
    final theme = Theme.of(context);
    final explanation = item.mappingExplanation;
    final classificationOutcome = item.classificationOutcome;
    final targetCells = _targetCells();

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: HiveColors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
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
                Text('Placement Detail', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  explanation == null
                      ? 'HIVE saved this asset locally, but placement detail is still limited for this member.'
                      : explanation.isManualOverride
                      ? 'HIVE is keeping this asset in ${explanation.cellName} because you moved it there manually.'
                      : explanation.usedFallback
                      ? 'HIVE fell back to Unsorted because the current labels were too weak, too broad, or unavailable.'
                      : 'HIVE matched this asset into ${explanation.cellName} using its strongest local labels.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: HiveColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                if (explanation != null) ...[
                  _ExplanationRow(
                    label: 'Mapped Category',
                    value: explanation.cellName,
                  ),
                  _ExplanationRow(
                    label: 'Manual Override',
                    value: explanation.isManualOverride ? 'Yes' : 'No',
                  ),
                  _ExplanationRow(
                    label: 'Fallback Used',
                    value: explanation.usedFallback ? 'Yes' : 'No',
                  ),
                  _ExplanationRow(
                    label: 'Match Score',
                    value: explanation.score.toStringAsFixed(2),
                  ),
                ],
                if (classificationOutcome != null) ...[
                  _ExplanationRow(
                    label: 'Classification Status',
                    value: _classificationStatusLabel(classificationOutcome),
                  ),
                  if (classificationOutcome.failureStage != null)
                    _ExplanationRow(
                      label: 'Failure Stage',
                      value: _classificationFailureStageLabel(
                        classificationOutcome.failureStage!,
                      ),
                    ),
                  if (classificationOutcome.failureCode != null)
                    _ExplanationRow(
                      label: 'Failure Code',
                      value: classificationOutcome.failureCode!,
                    ),
                  _ExplanationRow(
                    label: 'Classification Ran',
                    value: classificationOutcome.classificationRan
                        ? 'Yes'
                        : 'No',
                  ),
                  _ExplanationRow(
                    label: 'Image Prepared',
                    value: classificationOutcome.imagePreparationSucceeded
                        ? 'Yes'
                        : 'No',
                  ),
                  _ExplanationRow(
                    label: 'Vision Returned No Labels',
                    value: classificationOutcome.noLabelsReturned
                        ? 'Yes'
                        : 'No',
                  ),
                  if (classificationOutcome.sourceFormat != null)
                    _ExplanationRow(
                      label: 'Source Format',
                      value: classificationOutcome.sourceFormat!,
                    ),
                  if (classificationOutcome.preparedFormat != null)
                    _ExplanationRow(
                      label: 'Prepared Format',
                      value: classificationOutcome.preparedFormat!,
                    ),
                  if (classificationOutcome.modelIdentifier != null)
                    _ExplanationRow(
                      label: 'Model',
                      value: classificationOutcome.modelIdentifier!,
                    ),
                  if (classificationOutcome.failureReason != null &&
                      classificationOutcome.failureReason!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        classificationOutcome.failureReason!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: HiveColors.textSecondary,
                        ),
                      ),
                    ),
                ],
                if (explanation != null &&
                    explanation.matchedKeywords.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Matched Terms',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: HiveColors.honey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final keyword in explanation.matchedKeywords)
                        _KeywordChip(label: keyword),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Top Labels',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: HiveColors.honey,
                  ),
                ),
                const SizedBox(height: 10),
                if (explanation == null || explanation.topLabels.isEmpty)
                  Text(
                    classificationOutcome == null
                        ? 'No classification detail is available for this asset yet.'
                        : _topLabelsEmptyCopy(classificationOutcome),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HiveColors.textSecondary,
                    ),
                  ),
                for (final label
                    in explanation?.topLabels ?? const <ClassificationLabel>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label.displayName,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          label.confidence.toStringAsFixed(2),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: HiveColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (targetCells.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _showMoveSheet(item);
                      },
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Move to Cell'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMoveSheet(FolderDetailItem item) async {
    final targetCells = _targetCells();
    final target = await showModalBottomSheet<HiveCellCategory>(
      context: context,
      backgroundColor: HiveColors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
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
                Text('Move to Cell', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  'Save a local correction for ${item.title}. Future scans will remember this choice.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: HiveColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: targetCells.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final category = targetCells[index];
                      return _MoveTargetTile(
                        category: category,
                        onTap: () => Navigator.of(context).pop(category),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || target == null) {
      return;
    }

    setState(() {
      _isApplyingMove = true;
    });

    try {
      await _manualRecategorizationService.moveAssetToCell(
        assetId: item.asset.id,
        targetCellId: target.id,
      );
      if (!mounted) {
        return;
      }

      _refreshSnapshot();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Moved to ${target.name}. Future scans will keep it there.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingMove = false;
        });
      }
    }
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
                                        : _isApplyingMove
                                        ? 'Updating local membership'
                                        : '${detail.totalCount} assets in this cell',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: HiveColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isApplyingMove)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: HiveColors.surface.withValues(
                                    alpha: 0.84,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: HiveColors.outline),
                                ),
                                child: const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
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
                                      label: 'Source',
                                      value: 'Local',
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
                                    'Real scan-backed assets grouped into this HIVE cell.',
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
                          onTap: _isApplyingMove
                              ? null
                              : () =>
                                    _showExplanationSheet(detail.items[index]),
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

  String _classificationStatusLabel(ClassificationOutcome outcome) {
    return switch (outcome.status) {
      ClassificationOutcomeStatus.succeeded => 'Succeeded',
      ClassificationOutcomeStatus.noLabelsReturned =>
        'Vision returned no labels',
      ClassificationOutcomeStatus.imagePreparationFailed =>
        'Image preparation failed',
      ClassificationOutcomeStatus.requestFailed => 'Request failed',
      ClassificationOutcomeStatus.unsupportedAsset => 'Unsupported asset type',
    };
  }

  String _topLabelsEmptyCopy(ClassificationOutcome outcome) {
    return switch (outcome.status) {
      ClassificationOutcomeStatus.succeeded =>
        'Classification completed without any saved labels.',
      ClassificationOutcomeStatus.noLabelsReturned =>
        'Classification ran, but Vision returned no labels above the current threshold.',
      ClassificationOutcomeStatus.imagePreparationFailed =>
        'Classification could not start because image preparation failed.',
      ClassificationOutcomeStatus.requestFailed =>
        'Classification did not finish for this asset.',
      ClassificationOutcomeStatus.unsupportedAsset =>
        'This asset type is not currently classifiable on device.',
    };
  }

  String _classificationFailureStageLabel(String value) {
    return switch (value) {
      'load_image_data' => 'Failed to load image data',
      'create_uiimage' => 'Failed to create UIImage',
      'normalize_image' => 'Failed to normalize image',
      'create_bitmap' => 'Failed to create CGImage / bitmap',
      'vision_request_creation' => 'Vision request creation failed',
      'vision_execution' => 'Vision execution failed',
      _ => value,
    };
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
    this.onTap,
  });

  final FolderDetailItem item;
  final ThumbnailService thumbnailService;
  final VoidCallback? onTap;

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
                      if (explanation != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          explanation.isManualOverride
                              ? 'Manual placement'
                              : 'Why here',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: HiveColors.honey,
                          ),
                        ),
                      ] else if (classificationOutcome != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _classificationBadgeText(classificationOutcome),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: HiveColors.textSecondary,
                          ),
                        ),
                      ],
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
      ClassificationOutcomeStatus.succeeded => 'Labels captured',
      ClassificationOutcomeStatus.noLabelsReturned => 'No labels returned',
      ClassificationOutcomeStatus.imagePreparationFailed =>
        'Image prep needs review',
      ClassificationOutcomeStatus.requestFailed => 'Classification paused',
      ClassificationOutcomeStatus.unsupportedAsset => 'Not classifiable',
    };
  }
}

class _MoveTargetTile extends StatelessWidget {
  const _MoveTargetTile({required this.category, required this.onTap});

  final HiveCellCategory category;
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
                child: const Icon(
                  Icons.hive_outlined,
                  color: HiveColors.honey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      category.description,
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

class _ExplanationRow extends StatelessWidget {
  const _ExplanationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: HiveColors.textSecondary,
              ),
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: HiveColors.honey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HiveColors.honey.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: HiveColors.honey),
      ),
    );
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
