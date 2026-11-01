import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/safety/domain/bloc/safety_bloc.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_contacts_section.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_hero_banner.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_settings_section.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_sos_card.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_useful_numbers_section.dart';

/// Dedicated Safety Feature Page following Innov & Impact Africa guidelines:
/// - Architecture: features/safety/
/// - State Management: BLoC (flutter_bloc)
/// - Zero hardcoded colors or constants
/// - Fully responsive to dynamic locale changes
class SafetyPage extends StatelessWidget {
  const SafetyPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Re-evaluates instantly when EasyLocalization locale changes
    final _ = context.locale;

    return BlocProvider<SafetyBloc>(
      create: (context) => SafetyBloc()..add(const SafetyLoadRequested()),
      child: const _SafetyPageView(),
    );
  }
}

class _SafetyPageView extends StatelessWidget {
  const _SafetyPageView();

  @override
  Widget build(BuildContext context) {
    // Ensure reactive language rebuilding
    final _ = context.locale;

    return BlocListener<SafetyBloc, SafetyState>(
      listenWhen: (previous, current) =>
          (current.userFeedbackMessage != null &&
              current.userFeedbackMessage != previous.userFeedbackMessage) ||
          (current.errorMessage != null &&
              current.errorMessage != previous.errorMessage),
      listener: (context, state) {
        if (state.userFeedbackMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'safety.contact_added'.tr(args: [state.userFeedbackMessage!]),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              backgroundColor: AppColors.textPrimary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
            ),
          );
        } else if (state.errorMessage != null) {
          final errorText = state.errorMessage!.startsWith('safety.')
              ? state.errorMessage!.tr()
              : state.errorMessage!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorText,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.safetyScaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    AppConstants.spacingSm,
                    AppConstants.spacingLg,
                    AppConstants.spacingXl,
                  ),
                  child: Column(
                    children: const [
                      SafetyHeroBanner(),
                      SizedBox(height: AppConstants.spacingLg),
                      SafetySosCard(),
                      SizedBox(height: AppConstants.spacingLg),
                      SafetyContactsSection(),
                      SizedBox(height: AppConstants.spacingLg),
                      SafetySettingsSection(),
                      SizedBox(height: AppConstants.spacingLg),
                      SafetyUsefulNumbersSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingUnitLg,
      ),
      child: Row(
        children: [
          Container(
            width: AppConstants.circularButtonSize,
            height: AppConstants.circularButtonSize,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: AppConstants.spacingSm,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  AppConstants.circularButtonSize / 2,
                ),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.arrow_back,
                  size: AppConstants.iconSizeMd,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingUnitXl),
          Text(
            'safety.page_title'.tr(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: AppConstants.fontTitle,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
