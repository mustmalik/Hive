import 'package:flutter/material.dart';

import '../widgets/placeholder_screen_scaffold.dart';

class FolderDetailScreen extends StatelessWidget {
  const FolderDetailScreen({super.key, this.cellName = 'Folder Detail'});

  final String cellName;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreenScaffold(
      title: cellName,
      description:
          '$cellName is a virtual HIVE cell. Detail views, member photos, and organization tools will appear here once the data layer is wired in.',
      icon: Icons.folder_open_rounded,
    );
  }
}
