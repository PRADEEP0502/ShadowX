import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PremiumInputCard extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const PremiumInputCard({
    super.key,
    required this.child,
    this.maxWidth = 400,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.glassBlur,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.glassBorder.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}