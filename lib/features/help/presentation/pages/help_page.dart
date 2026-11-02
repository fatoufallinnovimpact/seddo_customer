import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/help/domain/bloc/help_bloc.dart';
import 'package:seddo/features/help/presentation/widgets/help_action_buttons.dart';
import 'package:seddo/features/help/presentation/widgets/help_claims_card.dart';
import 'package:seddo/features/help/presentation/widgets/help_faq_section.dart';

/// Dedicated Help Center Page following Innov & Impact Africa guidelines:
/// - Architecture: features/help/
/// - State Management: BLoC (flutter_bloc)
/// - Modern, calm, elegant aesthetic
/// - Replaced search bar with "Mes réclamations" card navigating to claims list
/// - Fully responsive to dynamic locale changes
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;

    return BlocProvider<HelpBloc>(
      create: (context) => HelpBloc()..add(const HelpLoadRequested()),
      child: const _HelpPageView(),
    );
  }
}

class _HelpPageView extends StatelessWidget {
  const _HelpPageView();

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingMd,
                  AppConstants.spacingXs,
                  AppConstants.spacingMd,
                  AppConstants.spacingXl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: AppConstants.spacingLg),
                    const HelpActionButtons(),
                    const SizedBox(height: AppConstants.spacingLg),
                    const HelpClaimsCard(),
                    const SizedBox(height: AppConstants.spacingLg),
                    const HelpFaqSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingXs,
        horizontal: AppConstants.spacingXxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comment pouvons-nous vous aider ?',
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontTitle,
              fontWeight: FontWeight.w800,
              color: AppColors.slateDark,
              letterSpacing: -0.4,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            'Consultez nos réponses rapides ou contactez notre équipe.',
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontSm,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: AppConstants.circularButtonSize,
              height: AppConstants.circularButtonSize,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.grayBorderDivider,
                  width: AppConstants.strokeWidthBorder,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowSubtleBlack,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.slateDark,
                size: AppConstants.iconSizeMd,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingUnitLg),
          Expanded(
            child: Text(
              'help.page_title'.tr(),
              style: GoogleFonts.inter(
                fontSize: AppConstants.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.slateDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
