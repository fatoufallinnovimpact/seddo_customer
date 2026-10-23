import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
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
          current.userFeedbackMessage != null &&
          current.userFeedbackMessage != previous.userFeedbackMessage,
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
                      SafetyHeroBanner(),
                      SizedBox(height: 18),
                      SafetySosCard(),
                      SizedBox(height: 22),
                      SafetyContactsSection(),
                      SizedBox(height: 22),
                      SafetySettingsSection(),
                      SizedBox(height: 22),
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
            'safety.page_title'.tr(),
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
