import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/help/domain/bloc/help_bloc.dart';
import 'package:seddo/features/help/presentation/widgets/help_action_buttons.dart';
import 'package:seddo/features/help/presentation/widgets/help_faq_section.dart';
import 'package:seddo/features/help/presentation/widgets/help_search_bar.dart';

/// Dedicated Help Center Page following Innov & Impact Africa guidelines:
/// - Architecture: features/help/
/// - State Management: BLoC (flutter_bloc)
/// - Zero hardcoded colors or constants
/// - Fully responsive to dynamic locale changes
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Re-evaluates instantly when EasyLocalization locale changes
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
    // Ensure reactive language rebuilding
    final _ = context.locale;

    return Scaffold(
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
                    HelpActionButtons(),
                    SizedBox(height: 18),
                    HelpSearchBar(),
                    SizedBox(height: 24),
                    HelpFaqSection(),
                  ],
                ),
              ),
            ),
          ],
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
            'help.page_title'.tr(),
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
