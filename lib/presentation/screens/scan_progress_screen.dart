import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/models/scan_scope.dart';
import '../../application/services/scan_coordinator.dart';
import '../../domain/entities/scan_run.dart';
import '../../data/services/real_scan_coordinator.dart';
import '../theme/hive_colors.dart';
import '../widgets/hive_shell_background.dart';

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

  Future<void> _cancelAndClose() async {
    await _scanCoordinator.cancelActiveRun();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleBack() async {
    final run = _run;
    if (run == null || run.isTerminal) {
      Navigator.of(context).pop();
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
    final isRunning = run?.isRunning ?? true;
    final statusTitle = run == null
        ? 'Preparing scan'
        : run.status == ScanRunStatus.completed
        ? 'Scan complete'
        : run.status == ScanRunStatus.canceled
        ? 'Scan canceled'
        : 'Scanning your library';

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
                                  'Preparing your library',
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
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
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
                        Text(
                          isRunning
                              ? 'Building the next layer of your gallery.'
                              : 'Your first scan shell is ready for the next step.',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'HIVE is reading local photo metadata and shaping placeholder cells without moving or renaming anything in Apple Photos.',
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
                  Container(
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
                                    'Connecting to library…',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isRunning
                                    ? 'Refreshing metadata and preparing the next virtual cell suggestion.'
                                    : 'The current placeholder pass is complete and ready to hand off to a future real coordinator.',
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
                  const SizedBox(height: 18),
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
                                style: theme.textTheme.titleLarge,
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
                                'This is a believable placeholder signal for the future scan pipeline and can later be replaced with real coordinator output.',
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
