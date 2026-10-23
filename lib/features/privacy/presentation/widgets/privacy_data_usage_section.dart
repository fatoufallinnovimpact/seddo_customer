import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/privacy/domain/bloc/privacy_bloc.dart';

class PrivacyDataUsageSection extends StatelessWidget {
  const PrivacyDataUsageSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrivacyBloc, PrivacyState>(
      builder: (context, state) {
        final settings = state.settings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'privacy.section_data_usage'.tr(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusCardContainer),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildToggleRow(
                    title: 'privacy.personalized_suggestions_title'.tr(),
                    subtitle: 'privacy.personalized_suggestions_subtitle'.tr(),
                    value: settings.personalizedSuggestions,
                    onChanged: (val) {
                      context
                          .read<PrivacyBloc>()
                          .add(PrivacyPersonalizedSuggestionsToggled(val));
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.divider,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _buildToggleRow(
                    title: 'privacy.offers_promotions_title'.tr(),
                    subtitle: 'privacy.offers_promotions_subtitle'.tr(),
                    value: settings.offersPromotions,
                    onChanged: (val) {
                      context
                          .read<PrivacyBloc>()
                          .add(PrivacyOffersPromotionsToggled(val));
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.divider,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _buildToggleRow(
                    title: 'privacy.usage_statistics_title'.tr(),
                    subtitle: 'privacy.usage_statistics_subtitle'.tr(),
                    value: settings.usageStatistics,
                    onChanged: (val) {
                      context
                          .read<PrivacyBloc>()
                          .add(PrivacyUsageStatisticsToggled(val));
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.divider,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _buildBadgeRow(
                    title: 'privacy.contacts_access_title'.tr(),
                    subtitle: 'privacy.contacts_access_subtitle'.tr(),
                    badgeLabel: settings.contactsAccess
                        ? 'privacy.status_enabled'.tr()
                        : 'privacy.status_disabled'.tr(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeRow({
    required String title,
    required String subtitle,
    required String badgeLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.greyContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
