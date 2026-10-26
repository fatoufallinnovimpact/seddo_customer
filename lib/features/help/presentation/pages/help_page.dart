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
/// - Modern, calm, elegant aesthetic (easy on the eyes)
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
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    const HelpActionButtons(),
                    const SizedBox(height: 18),
                    const HelpSearchBar(),
                    const SizedBox(height: 24),
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
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comment pouvons-nous vous aider ?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
              letterSpacing: -0.4,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Consultez nos réponses rapides ou contactez notre équipe.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
        ],
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
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
          Expanded(
            child: Text(
              'help.page_title'.tr(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
