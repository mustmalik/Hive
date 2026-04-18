import 'package:flutter/material.dart';

import '../theme/hive_colors.dart';

class HiveShellBackground extends StatelessWidget {
  const HiveShellBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [HiveColors.backgroundSoft, HiveColors.background],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -70,
            right: -30,
            child: _GlowOrb(size: 220, color: Color(0x1FFFD38A)),
          ),
          const Positioned(
            top: 120,
            left: -80,
            child: _GlowOrb(size: 180, color: Color(0x18F4B860)),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(padding: padding, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}
