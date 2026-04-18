import 'package:flutter/material.dart';

import '../widgets/placeholder_screen_scaffold.dart';

class FolderDetailScreen extends StatelessWidget {
  const FolderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreenScaffold(
      title: 'Folder Detail',
      description:
          'Virtual cell details, member photos, and organization tools will appear here once the data and domain layers are introduced.',
      icon: Icons.folder_open_rounded,
    );
  }
}
