import 'package:flutter/material.dart';

import '../widgets/placeholder_screen_scaffold.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreenScaffold(
      title: 'Privacy',
      description:
          'Privacy messaging will reinforce that HIVE organizes locally and does not move, rename, or overwrite Apple Photos assets.',
      icon: Icons.privacy_tip_outlined,
    );
  }
}
