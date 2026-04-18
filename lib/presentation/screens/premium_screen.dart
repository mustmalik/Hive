import 'package:flutter/material.dart';

import '../widgets/placeholder_screen_scaffold.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreenScaffold(
      title: 'Premium',
      description:
          'Plan presentation, upgrade messaging, and premium feature highlights can be added here when monetization work begins.',
      icon: Icons.workspace_premium_outlined,
    );
  }
}
