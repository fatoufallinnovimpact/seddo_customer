import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Reusable multi-select feedback tags chip group
class FeedbackTagsSelectorWidget extends StatelessWidget {
  final List<String> availableTags;
  final Set<String> selectedTags;
  final ValueChanged<String> onTagToggled;

  const FeedbackTagsSelectorWidget({
    super.key,
    required this.availableTags,
    required this.selectedTags,
    required this.onTagToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 10,
      children: availableTags.map((tag) {
        final isSelected = selectedTags.contains(tag);
        return GestureDetector(
          onTap: () => onTagToggled(tag),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.tagChipSelectedBg
                  : AppColors.tagChipBg,
              borderRadius: BorderRadius.circular(
                AppConstants.radiusPill,
              ),
            ),
            child: Text(
              tag,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.tagChipSelectedText
                    : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
