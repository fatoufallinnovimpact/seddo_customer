import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Circular hamburger menu button matching the top-left button in media_1792425793650.png
class CircularMenuButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CircularMenuButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed ?? () {},
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: AppColors.surfaceGrey,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.menu_rounded,
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),
    );
  }
}
