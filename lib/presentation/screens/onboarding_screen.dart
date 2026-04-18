import 'package:flutter/material.dart';

import '../widgets/placeholder_screen_scaffold.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreenScaffold(
      title: 'Onboarding',
      description:
          'Introduce the HIVE approach, explain cells, and set expectations before any real setup flow is added.',
      icon: Icons.auto_awesome_rounded,
    );
  }
}
