import 'package:flutter/material.dart';

class NeonCover extends StatelessWidget {
  const NeonCover({
    required this.accent,
    required this.child,
    this.borderRadius = 10,
    this.glowRadius = 14,
    super.key,
  });

  final Color accent;
  final Widget child;
  final double borderRadius;
  final double glowRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.52),
            blurRadius: glowRadius,
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: glowRadius * 2,
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.13),
            blurRadius: 6,
            spreadRadius: -2,
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}
