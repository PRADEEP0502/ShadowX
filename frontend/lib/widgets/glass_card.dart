import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final Color borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.blur = 14,
    this.borderColor = const Color(0xFF2EE59D),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: borderRadius,
            border: Border.all(color: borderColor.withOpacity(0.22), width: 1),
          ),
          child: DefaultTextStyle.merge(
            style:
                theme.textTheme.bodyMedium ??
                const TextStyle(color: Colors.white70),
            child: child,
          ),
        ),
      ),
    );
  }
}
