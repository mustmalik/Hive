import 'package:flutter/material.dart';

import '../../application/services/permission_service.dart';
import '../../application/services/settings_service.dart';
import '../../data/services/local_settings_service.dart';
import '../../data/services/photo_manager_permission_service.dart';
import '../../domain/models/photo_permission_status.dart';
import 'home_screen.dart';
import '../theme/hive_colors.dart';
import '../widgets/hive_shell_background.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({
    super.key,
    this.permissionService,
    this.settingsService,
  });

  final PermissionService? permissionService;
  final SettingsService? settingsService;

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  late final PermissionService _permissionService;
  late final SettingsService _settingsService;

  PhotoPermissionStatus? _status;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionService =
        widget.permissionService ?? const PhotoManagerPermissionService();
    _settingsService =
        widget.settingsService ?? LocalSettingsService.standard();
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final status = await _permissionService.getPhotoPermissionStatus();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = status;
    });
  }

  Future<void> _requestPermission() async {
    await _runBusy(() async {
      final status = await _permissionService.requestPhotoPermission();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
      });
    });
  }

  Future<void> _openSettings() async {
    await _permissionService.openPhotoSettings();
  }

  Future<void> _manageLimitedSelection() async {
    await _runBusy(() async {
      final status = await _permissionService.presentLimitedPhotoPicker();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
      });
    });
  }

  Future<void> _continueToHome() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(settingsService: _settingsService),
      ),
    );
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;
    final viewModel = status == null ? null : _PermissionViewModel.from(status);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Access')),
      body: HiveShellBackground(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: status == null
                              ? const _PermissionLoadingCard()
                              : _PermissionHeroCard(viewModel: viewModel!),
                        ),
                        const SizedBox(height: 20),
                        _PrivacyPoint(
                          icon: Icons.memory_rounded,
                          title: 'Local-only processing',
                          body:
                              'Organization happens on this device. No cloud sync is required for the core experience.',
                        ),
                        const SizedBox(height: 12),
                        _PrivacyPoint(
                          icon: Icons.photo_library_outlined,
                          title: 'Originals remain untouched',
                          body:
                              'Cells are virtual folders layered over your library, not changes to the source photos.',
                        ),
                        const SizedBox(height: 12),
                        _PrivacyPoint(
                          icon: viewModel?.supportIcon ?? Icons.tune_rounded,
                          title: viewModel?.supportTitle ?? 'Checking access',
                          body:
                              viewModel?.supportBody ??
                              'HIVE is loading your current Photos permission so the next step stays accurate.',
                        ),
                        const SizedBox(height: 24),
                        Text(
                          viewModel?.footnote ??
                              'HIVE is checking your current photo access before showing the right next step.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: HiveColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              onPressed: _isBusy || viewModel == null
                                  ? null
                                  : switch (status!) {
                                      PhotoPermissionStatus.notRequested =>
                                        _requestPermission,
                                      PhotoPermissionStatus.denied =>
                                        _openSettings,
                                      PhotoPermissionStatus.limited ||
                                      PhotoPermissionStatus.fullAccess =>
                                        _continueToHome,
                                    },
                              child: Text(
                                _isBusy
                                    ? 'Working...'
                                    : viewModel?.primaryActionLabel ??
                                          'Continue',
                              ),
                            ),
                            if (viewModel?.secondaryActionLabel != null) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _isBusy || status == null
                                    ? null
                                    : switch (status) {
                                        PhotoPermissionStatus.notRequested =>
                                          null,
                                        PhotoPermissionStatus.denied =>
                                          _refreshStatus,
                                        PhotoPermissionStatus.limited =>
                                          _manageLimitedSelection,
                                        PhotoPermissionStatus.fullAccess =>
                                          _openSettings,
                                      },
                                child: Text(viewModel!.secondaryActionLabel!),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HiveColors.surfaceElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
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
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  body,
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

class _PermissionHeroCard extends StatelessWidget {
  const _PermissionHeroCard({required this.viewModel});

  final _PermissionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: ValueKey(viewModel.status),
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: HiveColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: HiveColors.honey.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(viewModel.icon, size: 30),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: HiveColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  viewModel.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: viewModel.labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(viewModel.title, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(
            viewModel.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionLoadingCard extends StatelessWidget {
  const _PermissionLoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('permission-loading'),
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: HiveColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: HiveColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: HiveColors.honey.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Checking your current access...',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'HIVE is reading the current Photos permission so it can show the right next step.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: HiveColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionViewModel {
  const _PermissionViewModel({
    required this.status,
    required this.label,
    required this.labelColor,
    required this.icon,
    required this.title,
    required this.body,
    required this.supportIcon,
    required this.supportTitle,
    required this.supportBody,
    required this.footnote,
    required this.primaryActionLabel,
    this.secondaryActionLabel,
  });

  final PhotoPermissionStatus status;
  final String label;
  final Color labelColor;
  final IconData icon;
  final String title;
  final String body;
  final IconData supportIcon;
  final String supportTitle;
  final String supportBody;
  final String footnote;
  final String primaryActionLabel;
  final String? secondaryActionLabel;

  factory _PermissionViewModel.from(PhotoPermissionStatus status) {
    return switch (status) {
      PhotoPermissionStatus.notRequested => const _PermissionViewModel(
        status: PhotoPermissionStatus.notRequested,
        label: 'Not Requested',
        labelColor: HiveColors.honey,
        icon: Icons.photo_library_outlined,
        title: 'Let HIVE organize locally.',
        body:
            'Grant photo access so HIVE can build cells on this device while leaving every original photo exactly where it is.',
        supportIcon: Icons.waving_hand_rounded,
        supportTitle: 'First request',
        supportBody:
            'The next step opens Apple’s Photos prompt. You stay in control and can adjust access later.',
        footnote:
            'HIVE only creates a local organizational layer. It never moves or renames original Apple Photos assets.',
        primaryActionLabel: 'Allow Photo Access',
      ),
      PhotoPermissionStatus.denied => const _PermissionViewModel(
        status: PhotoPermissionStatus.denied,
        label: 'Access Off',
        labelColor: Color(0xFFFFB4A8),
        icon: Icons.lock_outline_rounded,
        title: 'Photos access is currently off.',
        body:
            'HIVE can’t organize your library until Photos access is enabled again in Settings.',
        supportIcon: Icons.settings_outlined,
        supportTitle: 'Denied access',
        supportBody:
            'Open Settings to allow HIVE to read your library locally. Once access is back, this screen will update automatically.',
        footnote:
            'If you prefer, you can grant limited access instead of the full library and still continue into HIVE.',
        primaryActionLabel: 'Open Settings',
        secondaryActionLabel: 'Refresh Status',
      ),
      PhotoPermissionStatus.limited => const _PermissionViewModel(
        status: PhotoPermissionStatus.limited,
        label: 'Limited Access',
        labelColor: HiveColors.amberGlow,
        icon: Icons.filter_none_rounded,
        title: 'HIVE has access to selected photos.',
        body:
            'Limited access works well for a focused start. Only the photos you selected will appear in cells for now.',
        supportIcon: Icons.add_photo_alternate_outlined,
        supportTitle: 'Limited access',
        supportBody:
            'You can continue now or choose more photos from Apple’s limited access picker without giving full library access.',
        footnote:
            'HIVE will only organize the photos Apple currently shares with the app until you expand that selection.',
        primaryActionLabel: 'Continue to HIVE',
        secondaryActionLabel: 'Manage Selection',
      ),
      PhotoPermissionStatus.fullAccess => const _PermissionViewModel(
        status: PhotoPermissionStatus.fullAccess,
        label: 'Full Access',
        labelColor: HiveColors.honey,
        icon: Icons.check_circle_outline_rounded,
        title: 'HIVE is ready for your full library.',
        body:
            'Photo access is enabled, so HIVE can organize your library locally while leaving the originals untouched.',
        supportIcon: Icons.verified_user_outlined,
        supportTitle: 'Full access',
        supportBody:
            'Everything stays on-device for now. This only unlocks the permission layer, not scanning or indexing.',
        footnote:
            'You can change Photos access in Settings at any time without affecting the original Apple Photos library.',
        primaryActionLabel: 'Continue to HIVE',
        secondaryActionLabel: 'Open Settings',
      ),
    };
  }
}
