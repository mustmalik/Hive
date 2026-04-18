import 'package:flutter/material.dart';

import '../widgets/placeholder_screen_scaffold.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreenScaffold(
      title: 'Permissions',
      description:
          'Request photo access later while making it clear that HIVE adds a local organization layer and never moves originals.',
      icon: Icons.photo_library_outlined,
    );
  }
}
