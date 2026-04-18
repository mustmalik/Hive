import 'package:flutter/material.dart';

import '../widgets/placeholder_screen_scaffold.dart';

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreenScaffold(
      title: 'Photo Viewer',
      description:
          'A focused viewing experience for photos inside a cell will live here without affecting the original Apple Photos asset.',
      icon: Icons.image_outlined,
    );
  }
}
