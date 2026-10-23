import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/privacy/domain/bloc/privacy_bloc.dart';
import 'package:seddo/features/privacy/presentation/widgets/privacy_dialogs.dart';

class PrivacyMyDataSection extends StatelessWidget {
  const PrivacyMyDataSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'privacy.section_my_data'.tr(),
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
              _buildActionRow(
                context: context,
                title: 'privacy.download_data_title'.tr(),
                subtitle: 'privacy.download_data_subtitle'.tr(),
                onTap: () {
                  PrivacyDialogs.showDownloadData(
                    context,
                    onConfirm: () {
                      context
                          .read<PrivacyBloc>()
                          .add(const PrivacyDataDownloadRequested());
                    },
                  );
                },
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider,
                indent: 16,
                endIndent: 16,
              ),
              _buildActionRow(
                context: context,
                title: 'privacy.clear_history_title'.tr(),
                subtitle: 'privacy.clear_history_subtitle'.tr(),
                onTap: () {
                  PrivacyDialogs.showClearHistory(
                    context,
                    onConfirm: () {
                      context
                          .read<PrivacyBloc>()
                          .add(const PrivacyClearHistoryRequested());
                    },
                  );
                },
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider,
                indent: 16,
                endIndent: 16,
              ),
              _buildActionRow(
                context: context,
                title: 'privacy.delete_account_title'.tr(),
                subtitle: 'privacy.delete_account_subtitle'.tr(),
                isDestructive: true,
                onTap: () {
                  PrivacyDialogs.showDeleteAccount(
                    context,
                    onConfirm: () {
                      context
                          .read<PrivacyBloc>()
                          .add(const PrivacyDeleteAccountRequested());
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildFooterLinks(context),
      ],
    );
  }

  Widget _buildActionRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusCardContainer),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              if (isDestructive) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.privacyDeleteLightBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: AppColors.privacyDeleteRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDestructive
                            ? AppColors.privacyDeleteRed
                            : AppColors.textPrimary,
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
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDestructive
                    ? AppColors.privacyDeleteRed
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLinks(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              PrivacyDialogs.showLegalDoc(
                context,
                titleKey: 'privacy.policy_title',
                contentKey: 'privacy.policy_content',
              );
            },
            child: Text(
              'privacy.privacy_policy'.tr(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '·',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              PrivacyDialogs.showLegalDoc(
                context,
                titleKey: 'privacy.terms_title',
                contentKey: 'privacy.terms_content',
              );
            },
            child: Text(
              'privacy.terms_of_service'.tr(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
