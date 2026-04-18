import 'package:flutter/material.dart';

import '../../application/services/permission_service.dart';
import 'permission_screen.dart';
import '../theme/hive_colors.dart';
import '../widgets/hive_shell_background.dart';
import '../widgets/onboarding_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.permissionService});

  final PermissionService? permissionService;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    _OnboardingContent(
      eyebrow: 'Your Gallery, Refined',
      title: 'Sort life into cells, not duplicate folders.',
      body:
          'Create smart, visual groupings that make your camera roll feel intentional and easy to revisit.',
      icon: Icons.hive_outlined,
    ),
    _OnboardingContent(
      eyebrow: 'Originals Stay Put',
      title: 'HIVE never moves or renames Apple Photos assets.',
      body:
          'Your library stays exactly where it is. HIVE adds a calm local layer on top for organization only.',
      icon: Icons.photo_library_outlined,
    ),
    _OnboardingContent(
      eyebrow: 'Built for Focus',
      title: 'Find the photos that matter without losing the full library.',
      body:
          'Move through curated cells, keep context, and return to important moments faster.',
      icon: Icons.view_stream_rounded,
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPermission() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PermissionScreen(permissionService: widget.permissionService),
      ),
    );
  }

  Future<void> _nextStep() async {
    if (_currentPage == _pages.length - 1) {
      _goToPermission();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Introduction'),
        actions: [
          TextButton(onPressed: _goToPermission, child: const Text('Skip')),
          const SizedBox(width: 8),
        ],
      ),
      body: HiveShellBackground(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (value) {
                  setState(() {
                    _currentPage = value;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];

                  return _OnboardingPage(content: page);
                },
              ),
            ),
            const SizedBox(height: 20),
            OnboardingPageIndicator(
              count: _pages.length,
              currentIndex: _currentPage,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: HiveColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: HiveColors.outline),
              ),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: const Text('Back'),
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        'Swipe or tap to continue',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: HiveColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Privacy & Access'
                            : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.content});

  final _OnboardingContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3E2C18), Color(0xFF221A15)],
                    ),
                    border: Border.all(color: HiveColors.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 72,
                        width: 72,
                        decoration: BoxDecoration(
                          color: HiveColors.honey.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: HiveColors.honey.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Icon(
                          content.icon,
                          color: HiveColors.honey,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 92),
                      Text(
                        content.eyebrow,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: HiveColors.honey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(content.title, style: theme.textTheme.headlineLarge),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  content.body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: HiveColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: HiveColors.surfaceElevated.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: HiveColors.outline),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Local-first design keeps your original Apple Photos library untouched.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
}
