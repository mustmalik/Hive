import 'package:flutter/material.dart';

import '../widgets/placeholder_screen_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreenScaffold(
      title: 'Settings',
      description:
          'Preferences, app behavior, and account-level controls will be organized here once the foundational flows are in place.',
      icon: Icons.settings_outlined,
    );
  }
}
