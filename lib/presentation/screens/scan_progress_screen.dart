import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/models/scan_scope.dart';
import '../../application/services/scan_coordinator.dart';
import '../../data/services/real_scan_coordinator.dart';
import '../../domain/entities/scan_run.dart';
import '../theme/hive_colors.dart';
import '../widgets/hive_shell_background.dart';

enum ScanProgressNextAction { viewResults, changeScope }

class ScanProgressScreen extends StatefulWidget {
  const ScanProgressScreen({
    super.key,
    this.scanCoordinator,
    this.scanScope = const ScanScope.allPhotos(),
  });

  final ScanCoordinator? scanCoordinator;
  final ScanScope scanScope;

  @override
  State<ScanProgressScreen> createState() => _ScanProgressScreenState();
}

class _ScanProgressScreenState extends State<ScanProgressScreen> {
  late final ScanCoordinator _scanCoordinator;
  ScanRun? _run;
  StreamSubscription<ScanRun>? _subscription;
  bool _isRestarting = false;

  @override
  void initState() {
    super.initState();
    _scanCoordinator = widget.scanCoordinator ?? RealScanCoordinator.seeded();
    _subscription = _scanCoordinator.watchActiveRun().listen((run) {
      if (!mounted) {
        return;
      }

      setState(() {
        _run = run;
        _isRestarting = false;
      });
    });
    _start();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final latest = await _scanCoordinator.getLatestRun();
    if (latest != null && latest.isRunning) {
      setState(() {
        _run = latest;
      });
      return;
    }

    final startedRun = await _scanCoordinator.startFullScan(
      scope: widget.scanScope,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _run = startedRun;
    });
  }

  Future<void> _restartScan() async {
    setState(() {
      _isRestarting = true;
    });

    final startedRun = await _scanCoordinator.startFullScan(
      scope: widget.scanScope,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _run = startedRun;
    });
  }

  Future<void> _cancelAndClose() async {
    await _scanCoordinator.cancelActiveRun();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleBack() async {
    final run = _run;
    if (run == null || run.isTerminal) {
      Navigator.of(context).pop(ScanProgressNextAction.viewResults);
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HiveColors.surfaceElevated,
          title: const Text('Leave scan?'),
          content: const Text(
            'Leaving will stop the current scan before HIVE finishes shaping your cells.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    if (shouldLeave == true && mounted) {
      await _cancelAndClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final run = _run;
    final progress = run?.progress ?? 0;
    final isRunning = (run?.isRunning ?? true) || _isRestarting;
    final statusTitle = _statusTitle(run);
    final headline = _headline(run);
    final supportingCopy = _supportingCopy(run);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handleBack();
      },
      child: Scaffold(
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
                      IconButton(
                        onPressed: _handleBack,
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
                              'Scan Progress',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: HiveColors.honey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              run?.currentStageLabel ??
                                  (_isRestarting
                                      ? 'Starting a fresh pass'
                                      : 'Preparing your library'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: HiveColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isRunning)
                        TextButton(
                          onPressed: _cancelAndClose,
                          child: const Text('Cancel'),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(ScanProgressNextAction.viewResults),
                          child: const Text('View Results'),
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
                        colors: [Color(0xFF372515), Color(0xFF201914)],
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
                            color: HiveColors.honey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusTitle,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: HiveColors.honey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Scope • ${widget.scanScope.label}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: HiveColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(headline, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        Text(
                          supportingCopy,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: HiveColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _ProgressBar(progress: progress),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${(progress * 100).round()}%',
                              style: theme.textTheme.titleLarge,
                            ),
                            const Spacer(),
                            Text(
                              '${run?.classifiedAssetCount ?? 0} of ${run?.discoveredAssetCount ?? 0}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: HiveColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _ScanStatCard(
                          label: 'Scanned',
                          value: '${run?.classifiedAssetCount ?? 0}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ScanStatCard(
                          label: 'Total',
                          value: '${run?.discoveredAssetCount ?? 0}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ScanStatCard(
                          label: 'Cells',
                          value: '${run?.generatedCellCount ?? 0}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (run == null || run.isRunning || _isRestarting) ...[
                    _CurrentItemCard(run: run, isRestarting: _isRestarting),
                    const SizedBox(height: 18),
                    _LatestCellCard(run: run),
                  ] else ...[
                    _CompletionSummaryCard(
                      run: run,
                      scopeLabel: widget.scanScope.label,
                    ),
                    const SizedBox(height: 18),
                    _CompletionActionsCard(
                      run: run,
                      onViewResults: () => Navigator.of(
                        context,
                      ).pop(ScanProgressNextAction.viewResults),
                      onRescan: _restartScan,
                      onChangeScope: () => Navigator.of(
                        context,
                      ).pop(ScanProgressNextAction.changeScope),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (isRunning)
                    OutlinedButton.icon(
                      onPressed: _cancelAndClose,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Stop Scan'),
                    ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusTitle(ScanRun? run) {
    if (_isRestarting) {
      return 'Restarting scan';
    }
    if (run == null) {
      return 'Preparing scan';
    }
    return switch (run.status) {
      ScanRunStatus.completed => 'Scan complete',
      ScanRunStatus.canceled => 'Scan canceled',
      ScanRunStatus.failed => 'Scan paused',
      ScanRunStatus.queued => 'Preparing scan',
      ScanRunStatus.running => 'Scanning your library',
    };
  }

  String _headline(ScanRun? run) {
    if (_isRestarting || run == null || run.isRunning) {
      return 'Building the next layer of your gallery.';
    }

    return switch (run.status) {
      ScanRunStatus.completed => 'Your cells are ready to review.',
      ScanRunStatus.canceled =>
        'This pass stopped before HIVE finished shaping your cells.',
      ScanRunStatus.failed => 'This scan hit a local issue before completion.',
      ScanRunStatus.queued ||
      ScanRunStatus.running => 'Building the next layer of your gallery.',
    };
  }

  String _supportingCopy(ScanRun? run) {
    if (_isRestarting || run == null || run.isRunning) {
      return 'HIVE is reading local photo metadata and shaping placeholder cells without moving or renaming anything in Apple Photos.';
    }

    return switch (run.status) {
      ScanRunStatus.completed =>
        'This local-only pass finished cleanly. You can review the results, rerun the same scope, or switch to a smaller slice for faster iteration.',
      ScanRunStatus.canceled =>
        'Nothing in Apple Photos was changed. You can resume with the same scope or switch to a different slice when you are ready.',
      ScanRunStatus.failed =>
        'HIVE kept everything local-only and non-destructive. You can retry this scope or change scope for a lighter pass.',
      ScanRunStatus.queued || ScanRunStatus.running =>
        'HIVE is reading local photo metadata and shaping placeholder cells without moving or renaming anything in Apple Photos.',
    };
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);

    return Container(
      height: 14,
      width: double.infinity,
      decoration: BoxDecoration(
        color: HiveColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [HiveColors.honey, HiveColors.amberGlow],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33F4B860),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanStatCard extends StatelessWidget {
  const _ScanStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _CurrentItemCard extends StatelessWidget {
  const _CurrentItemCard({required this.run, required this.isRestarting});

  final ScanRun? run;
  final bool isRestarting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HiveColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 88,
            width: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A321C), Color(0xFF241C16)],
              ),
            ),
            child: const Icon(
              Icons.photo_library_rounded,
              size: 34,
              color: HiveColors.honey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current item',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: HiveColors.honey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  run?.currentItemTitle ??
                      (isRestarting
                          ? 'Restarting this scope…'
                          : 'Connecting to library…'),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  isRestarting
                      ? 'HIVE is starting a fresh pass through the same local scope.'
                      : 'Refreshing metadata and preparing the next virtual cell suggestion.',
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

class _LatestCellCard extends StatelessWidget {
  const _LatestCellCard({required this.run});

  final ScanRun? run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: HiveColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.hive_outlined, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest detected cell',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  run?.latestDetectedCellName ??
                      'Waiting for the first grouping…',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: HiveColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This updates live as HIVE turns local image signals into virtual cells.',
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

class _CompletionSummaryCard extends StatelessWidget {
  const _CompletionSummaryCard({required this.run, required this.scopeLabel});

  final ScanRun run;
  final String scopeLabel;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completion Summary',
            style: theme.textTheme.titleLarge?.copyWith(
              color: HiveColors.honey,
            ),
          ),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Scope', value: scopeLabel),
          _SummaryRow(
            label: 'Scanned assets',
            value: '${run.classifiedAssetCount}',
          ),
          _SummaryRow(
            label: 'Generated cells',
            value: '${run.generatedCellCount}',
          ),
          _SummaryRow(
            label: 'Latest grouped cell',
            value: run.latestDetectedCellName ?? 'Unsorted',
          ),
          const SizedBox(height: 8),
          Text(
            run.status == ScanRunStatus.completed
                ? 'This pass finished cleanly and is ready for review on Home.'
                : run.status == ScanRunStatus.canceled
                ? 'The scan stopped early, but everything stayed local-only and untouched in Apple Photos.'
                : 'A local issue interrupted this pass before HIVE could finish shaping results.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionActionsCard extends StatelessWidget {
  const _CompletionActionsCard({
    required this.run,
    required this.onViewResults,
    required this.onRescan,
    required this.onChangeScope,
  });

  final ScanRun run;
  final VoidCallback onViewResults;
  final VoidCallback onRescan;
  final VoidCallback onChangeScope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowViewResults = run.status == ScanRunStatus.completed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HiveColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next actions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Keep momentum going with one clean next step.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          if (allowViewResults)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onViewResults,
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('View Results'),
              ),
            ),
          if (allowViewResults) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRescan,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Rescan'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onChangeScope,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Change Scope'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

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
