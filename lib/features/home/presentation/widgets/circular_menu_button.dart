import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Circular hamburger menu button matching the top-left button in media_1792425793650.png
class CircularMenuButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CircularMenuButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: Ink(
          width: AppConstants.circularAvatarSize,
          height: AppConstants.circularAvatarSize,
          decoration: const BoxDecoration(
            color: AppColors.surfaceGrey,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.menu_rounded,
              color: AppColors.textPrimary,
              size: AppConstants.radiusTwentyFour,
            ),
          ),
        ),
      ),
    );
  }
}
