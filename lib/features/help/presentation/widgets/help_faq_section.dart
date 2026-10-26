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
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B7280),
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
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'help.no_faq_found'.tr(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...filteredItems.map((item) => _buildFaqCard(context, item)),
            const SizedBox(height: 14),
            _buildResponseTimeNote(),
          ],
        );
      },
    );
  }

  Widget _buildFaqCard(BuildContext context, FaqItemModel item) {
    final isExpanded = item.isExpanded;
    final meta = _getFaqCategoryMeta(item.questionKey);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCardContainer),
        border: Border.all(
          color: isExpanded ? const Color(0xFFD1D5DB) : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: meta.bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: meta.borderColor,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        meta.icon,
                        size: 18,
                        color: meta.iconColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.questionKey.tr(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                if (isExpanded)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.answerKey.tr(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF4B5563),
                        height: 1.5,
                        fontWeight: FontWeight.w400,
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

  _FaqCategoryMeta _getFaqCategoryMeta(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('1') || lower.contains('payer') || lower.contains('money')) {
      return const _FaqCategoryMeta(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: Color(0xFFEA580C),
        bgColor: Color(0xFFFFF7ED),
        borderColor: Color(0xFFFFEDD5),
      );
    } else if (lower.contains('2') || lower.contains('remboursement')) {
      return const _FaqCategoryMeta(
        icon: Icons.currency_exchange_rounded,
        iconColor: Color(0xFF059669),
        bgColor: Color(0xFFF0FDF4),
        borderColor: Color(0xFFDCFCE7),
      );
    } else if (lower.contains('3') || lower.contains('annuler')) {
      return const _FaqCategoryMeta(
        icon: Icons.event_busy_outlined,
        iconColor: Color(0xFFDC2626),
        bgColor: Color(0xFFFEF2F2),
        borderColor: Color(0xFFFEE2E2),
      );
    }
    return const _FaqCategoryMeta(
      icon: Icons.help_outline_rounded,
      iconColor: Color(0xFF4B5563),
      bgColor: Color(0xFFF3F4F6),
      borderColor: Color(0xFFE5E7EB),
    );
  }

  Widget _buildResponseTimeNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'help.response_time_note'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqCategoryMeta {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  const _FaqCategoryMeta({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });
}
