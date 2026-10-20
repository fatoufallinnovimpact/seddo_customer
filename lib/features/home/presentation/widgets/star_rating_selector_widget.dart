import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Interactive 5-star rating selector widget
class StarRatingSelectorWidget extends StatelessWidget {
  final int selectedStars;
  final ValueChanged<int> onStarSelected;
  final double starSize;

  const StarRatingSelectorWidget({
    super.key,
    required this.selectedStars,
    required this.onStarSelected,
    this.starSize = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isSelected = starIndex <= selectedStars;

        return GestureDetector(
          onTap: () => onStarSelected(starIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Icon(
              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
              size: starSize,
              color: isSelected ? AppColors.starGold : AppColors.cardBorder,
            ),
          ),
        );
      }),
    );
  }
}
