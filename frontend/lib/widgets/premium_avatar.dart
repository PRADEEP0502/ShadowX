import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PremiumAvatar extends StatelessWidget {
  final String? username;
  final bool isOnline;
  final double radius;
  final VoidCallback? onTap;

  const PremiumAvatar({
    super.key,
    this.username,
    this.isOnline = false,
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.primaryGradient;
    final initials = (username?.isNotEmpty ?? false)
        ? username![0].toUpperCase()
        : '?';

    return Stack(
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => gradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white,
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: radius * 0.45,
              height: radius * 0.45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.onlineGreen,
                border: Border.all(
                  color: AppColors.amoledBlack,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onlineGreen.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}