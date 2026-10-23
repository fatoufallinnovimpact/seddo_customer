import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/help/data/models/faq_item_model.dart';
import 'package:seddo/features/help/domain/bloc/help_bloc.dart';

class HelpFaqSection extends StatelessWidget {
  const HelpFaqSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HelpBloc, HelpState>(
      builder: (context, state) {
        final query = state.searchQuery.toLowerCase();
        final filteredItems = state.faqItems.where((item) {
          if (query.isEmpty) return true;
          final q = item.questionKey.tr().toLowerCase();
          final a = item.answerKey.tr().toLowerCase();
          return q.contains(query) || a.contains(query);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'help.section_faq'.tr(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            if (filteredItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusCardContainer),
                ),
                alignment: Alignment.center,
                child: Text(
                  'help.no_faq_found'.tr(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...filteredItems.map((item) => _buildFaqCard(context, item)),
            const SizedBox(height: 16),
            _buildResponseTimeNote(),
          ],
        );
      },
    );
  }

  Widget _buildFaqCard(BuildContext context, FaqItemModel item) {
    final isExpanded = item.isExpanded;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCardContainer),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(AppConstants.radiusCardContainer),
          onTap: () {
            context.read<HelpBloc>().add(HelpFaqToggled(item.id));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        item.questionKey.tr(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.helpChevronGrey,
                      ),
                    ),
                  ],
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      item.answerKey.tr(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.helpFaqTextGrey,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponseTimeNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline,
            size: 14,
            color: AppColors.helpResponseTimeGrey,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'help.response_time_note'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.helpResponseTimeGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
