import 'package:flutter/material.dart';

import '../../application/models/asset_mapping_explanation.dart';
import '../../application/models/classification_outcome.dart';
import '../../application/models/folder_detail_item.dart';
import '../../application/models/hive_cell_category.dart';
import '../../application/services/manual_recategorization_service.dart';
import '../../application/services/thumbnail_service.dart';
import '../../data/services/persisted_manual_recategorization_service.dart';
import '../../data/services/photo_manager_thumbnail_service.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/media_asset.dart';
import '../theme/hive_colors.dart';
import '../widgets/hive_shell_background.dart';

class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.item,
    required this.originCellId,
    required this.originCellName,
    this.manualRecategorizationService,
    this.thumbnailService,
  });

  final FolderDetailItem item;
  final String originCellId;
  final String originCellName;
  final ManualRecategorizationService? manualRecategorizationService;
  final ThumbnailService? thumbnailService;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final ManualRecategorizationService _manualRecategorizationService;
  late final ThumbnailService _thumbnailService;
  late FolderDetailItem _item;
  bool _isApplyingMove = false;
  bool _didMutateMembership = false;

  @override
  void initState() {
    super.initState();
    _manualRecategorizationService =
        widget.manualRecategorizationService ??
        PersistedManualRecategorizationService.standard();
    _thumbnailService =
        widget.thumbnailService ?? const PhotoManagerThumbnailService();
    _item = widget.item;
  }

  List<HiveCellCategory> _targetCells() {
    return _manualRecategorizationService.availableTargetCells
        .where((cell) => cell.id != _currentCellId)
        .toList(growable: false);
  }

  String get _currentCellId =>
      _item.mappingExplanation?.cellId ?? widget.originCellId;

  String get _currentCellName =>
      _item.mappingExplanation?.cellName ?? widget.originCellName;

  bool get _isManualOverride =>
      _item.mappingExplanation?.isManualOverride ?? false;

  Future<void> _closeViewer() async {
    Navigator.of(context).pop(_didMutateMembership);
  }

  Future<void> _showExplanationSheet() {
    final theme = Theme.of(context);
    final explanation = _item.mappingExplanation;
    final classificationOutcome = _item.classificationOutcome;

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
            child: SingleChildScrollView(
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
                  Text(
                    'Placement Detail',
                    style: theme.textTheme.headlineSmall,
                  ),
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
                      in explanation?.topLabels ??
                          const <ClassificationLabel>[])
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMoveSheet() async {
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
                  'Save a local correction for ${_item.title}. Future scans will remember this choice.',
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
        assetId: _item.asset.id,
        targetCellId: target.id,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _didMutateMembership = true;
        _item = FolderDetailItem(
          asset: _item.asset,
          title: _item.title,
          subtitle: _item.subtitle,
          classificationOutcome: _item.classificationOutcome,
          mappingExplanation: AssetMappingExplanation(
            cellId: target.id,
            cellName: target.name,
            score: 1.5,
            usedFallback: false,
            topLabels:
                _item.mappingExplanation?.topLabels ??
                _item.classificationOutcome?.labels ??
                const [],
            matchedKeywords: const ['manual override'],
            isManualOverride: true,
          ),
        );
      });

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
    final explanation = _item.mappingExplanation;

    return Scaffold(
      body: HiveShellBackground(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          bottom: false,
          child: CustomScrollView(
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
                          onPressed: _closeViewer,
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
                                'Asset Detail',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: HiveColors.honey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isApplyingMove
                                    ? 'Saving your local correction'
                                    : _item.subtitle,
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
                              color: HiveColors.surface.withValues(alpha: 0.84),
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
                      padding: const EdgeInsets.all(18),
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
                          _PreviewSurface(
                            asset: _item.asset,
                            thumbnailService: _thumbnailService,
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _StatusChip(
                                label: _isManualOverride
                                    ? 'Manual placement'
                                    : 'Auto placement',
                                emphasized: _isManualOverride,
                              ),
                              _StatusChip(
                                label: 'Current Cell · $_currentCellName',
                                emphasized: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _item.title,
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'A local-only view of this Apple Photos asset with quick actions for correcting placement.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: HiveColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionTile(
                            title: 'Move to Cell',
                            subtitle: 'Correct placement and keep it there.',
                            icon: Icons.swap_horiz_rounded,
                            emphasized: true,
                            onTap: _showMoveSheet,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionTile(
                            title: 'Why This Landed Here',
                            subtitle: 'Open labels, signals, and confidence.',
                            icon: Icons.lightbulb_outline_rounded,
                            onTap: _showExplanationSheet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: HiveColors.surfaceElevated.withValues(
                          alpha: 0.92,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: HiveColors.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Placement State',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: HiveColors.honey,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ExplanationRow(
                            label: 'Current Cell',
                            value: _currentCellName,
                          ),
                          _ExplanationRow(
                            label: 'Manual Override',
                            value: _isManualOverride ? 'Yes' : 'No',
                          ),
                          if (explanation != null)
                            _ExplanationRow(
                              label: 'Fallback Used',
                              value: explanation.usedFallback ? 'Yes' : 'No',
                            ),
                          if (explanation != null)
                            _ExplanationRow(
                              label: 'Match Score',
                              value: explanation.score.toStringAsFixed(2),
                            ),
                          if (_item.classificationOutcome != null)
                            _ExplanationRow(
                              label: 'Classification',
                              value: _classificationStatusLabel(
                                _item.classificationOutcome!,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            _isManualOverride
                                ? 'This asset will stay in $_currentCellName on future scans unless you move it again.'
                                : 'HIVE is currently relying on local labels and deterministic mapping to place this asset.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: HiveColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
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

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.asset, required this.thumbnailService});

  final MediaAsset asset;
  final ThumbnailService thumbnailService;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = asset.width > 0 && asset.height > 0
        ? asset.width / asset.height
        : 1.0;

    return AspectRatio(
      aspectRatio: aspectRatio.clamp(0.75, 1.4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: FutureBuilder(
          future: thumbnailService.loadThumbnail(asset: asset, size: 1400),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) {
              return Container(
                color: HiveColors.surfaceMuted,
                child: Center(
                  child: Icon(
                    asset.isVideo
                        ? Icons.play_circle_outline_rounded
                        : Icons.photo_outlined,
                    size: 56,
                    color: HiveColors.honey,
                  ),
                ),
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(bytes, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x4A000000)],
                    ),
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

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

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
            color: emphasized
                ? HiveColors.honey.withValues(alpha: 0.14)
                : HiveColors.surfaceElevated.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: emphasized
                  ? HiveColors.honey.withValues(alpha: 0.24)
                  : HiveColors.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: HiveColors.surface.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: HiveColors.honey, size: 20),
              ),
              const SizedBox(height: 14),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HiveColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: emphasized
            ? HiveColors.honey.withValues(alpha: 0.14)
            : HiveColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? HiveColors.honey.withValues(alpha: 0.22)
              : HiveColors.outline,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: emphasized ? HiveColors.honey : HiveColors.textSecondary,
        ),
      ),
    );
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
