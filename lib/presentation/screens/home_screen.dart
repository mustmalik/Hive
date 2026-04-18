import 'package:flutter/material.dart';

import '../widgets/placeholder_screen_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreenScaffold(
      title: 'Home',
      description:
          'This will become the main overview of cells, recent activity, and quick entry points into the gallery organization experience.',
      icon: Icons.home_rounded,
    );
  }
}
