import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/onboarding/domain/bloc/onboarding_bloc.dart';
import 'package:seddo/features/onboarding/domain/bloc/onboarding_event.dart';

/// Language selection pill container matching the exact Seddo design:
/// Unified pill capsule with circular flags for France and Senegal.
class LanguageSelectorWidget extends StatelessWidget {
  const LanguageSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLang = context.locale.languageCode;

    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.languageContainerBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(
          color: AppColors.languageContainerBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Français Button
          Expanded(
            child: _LanguageOption(
              title: 'common.french'.tr(),
              flagAsset: 'assets/images/fr.jpg',
              isSelected: currentLang == 'fr',
              onTap: () async {
                if (currentLang != 'fr') {
                  await context.setLocale(const Locale('fr'));
                  if (context.mounted) {
                    context
                        .read<OnboardingBloc>()
                        .add(const OnboardingLanguageChangedEvent('fr'));
                  }
                }
              },
            ),
          ),

          // Wolof Button
          Expanded(
            child: _LanguageOption(
              title: 'common.wolof'.tr(),
              flagAsset: 'assets/images/sn.jpg',
              isSelected: currentLang == 'wo',
              onTap: () async {
                if (currentLang != 'wo') {
                  await context.setLocale(const Locale('wo'));
                  if (context.mounted) {
                    context
                        .read<OnboardingBloc>()
                        .add(const OnboardingLanguageChangedEvent('wo'));
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final String flagAsset;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.flagAsset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white : AppColors.transparent,
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFFFFF9F5),
                    Color(0xFFFFFFFF),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Flag Icon with subtle active ring
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  flagAsset,
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 22,
                    height: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),

            // Language Title in Brand Orange when active
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
