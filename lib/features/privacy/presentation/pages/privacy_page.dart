import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/privacy/domain/bloc/privacy_bloc.dart';
import 'package:seddo/features/privacy/presentation/widgets/privacy_data_usage_section.dart';
import 'package:seddo/features/privacy/presentation/widgets/privacy_hero_banner.dart';
import 'package:seddo/features/privacy/presentation/widgets/privacy_my_data_section.dart';
import 'package:seddo/features/privacy/presentation/widgets/privacy_position_section.dart';

/// Dedicated Privacy & Data Management Page following Innov & Impact Africa guidelines:
/// - Architecture: features/privacy/
/// - State Management: BLoC (flutter_bloc)
/// - Zero hardcoded colors or constants
/// - Fully responsive to dynamic locale changes
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Re-evaluates instantly when EasyLocalization locale changes
    final _ = context.locale;

    return BlocProvider<PrivacyBloc>(
      create: (context) => PrivacyBloc()..add(const PrivacyLoadRequested()),
      child: const _PrivacyPageView(),
    );
  }
}

class _PrivacyPageView extends StatelessWidget {
  const _PrivacyPageView();

  @override
  Widget build(BuildContext context) {
    // Ensure reactive language rebuilding
    final _ = context.locale;

    return BlocListener<PrivacyBloc, PrivacyState>(
      listenWhen: (previous, current) =>
          current.feedbackMessageKey != null &&
          current.feedbackMessageKey != previous.feedbackMessageKey,
      listener: (context, state) {
        if (state.feedbackMessageKey != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.feedbackMessageKey!.tr(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              backgroundColor: AppColors.textPrimary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                  child: Column(
                    children: const [
                      PrivacyHeroBanner(),
                      SizedBox(height: 18),
                      PrivacyPositionSection(),
                      SizedBox(height: 22),
                      PrivacyDataUsageSection(),
                      SizedBox(height: 22),
                      PrivacyMyDataSection(),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(21),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'privacy.page_title'.tr(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
