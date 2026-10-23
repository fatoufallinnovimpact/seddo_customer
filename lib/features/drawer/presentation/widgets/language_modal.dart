import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Modal bottom sheet for language selection matching the Crone project design:
/// - Slides up from the bottom
/// - Drag handle and header with title and close icon
/// - Country flag image, language label and custom circular checkmark radio selector
/// - Instant reactive locale change via EasyLocalization
class LanguageModal extends StatefulWidget {
  const LanguageModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _LanguageModalContent(parentContext: context),
    );
  }

  @override
  State<LanguageModal> createState() => _LanguageModalState();
}

class _LanguageModalState extends State<LanguageModal> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _LanguageModalContent extends StatefulWidget {
  final BuildContext parentContext;

  const _LanguageModalContent({required this.parentContext});

  @override
  State<_LanguageModalContent> createState() => _LanguageModalContentState();
}

class _LanguageModalContentState extends State<_LanguageModalContent> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.parentContext.locale.languageCode;
  }

  Future<void> _select(String code) async {
    setState(() => _selected = code);
    final targetLocale = Locale(code);
    if (widget.parentContext.mounted) {
      try {
        await widget.parentContext.setLocale(targetLocale);
      } catch (_) {}
    }
    if (mounted) {
      try {
        await context.setLocale(targetLocale);
      } catch (_) {}
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusDialog)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingTwenty,
        AppConstants.spacingUnitXl,
        AppConstants.spacingTwenty,
        bottomPadding + AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: AppConstants.handleWidth,
              height: AppConstants.handleHeight,
              decoration: BoxDecoration(
                color: AppColors.grayBorderDivider,
                borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Header: Title and Close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'language_modal.title'.tr(),
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spacingXs),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textPrimary,
                    size: AppConstants.iconSizeLg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingTwenty),

          // Français card
          _LanguageCard(
            flagPath: 'assets/images/fr.jpg',
            label: 'language_modal.french'.tr(),
            isSelected: _selected == 'fr',
            onTap: () => _select('fr'),
          ),
          const SizedBox(height: AppConstants.spacingUnitLg),

          // Wolof card
          _LanguageCard(
            flagPath: 'assets/images/sn.jpg',
            label: 'language_modal.wolof'.tr(),
            isSelected: _selected == 'wo',
            onTap: () => _select('wo'),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String flagPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.flagPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingUnitXl,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.transparent,
            width: 2.0,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusSix),
              child: Image.asset(
                flagPath,
                width: 32,
                height: 22,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 32,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.grayBorderDivider,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSix),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.flag,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingUnitXl),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: AppConstants.spacingLg,
              height: AppConstants.spacingLg,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : AppColors.transparent,
                border: isSelected
                    ? null
                    : Border.all(
                        color: AppColors.grayBorderMedium,
                        width: 2.2,
                      ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: AppColors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
