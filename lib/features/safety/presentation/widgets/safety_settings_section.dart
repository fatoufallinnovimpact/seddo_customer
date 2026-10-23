import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/safety/domain/bloc/safety_bloc.dart';

class SafetySettingsSection extends StatelessWidget {
  const SafetySettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SafetyBloc, SafetyState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'safety.section_during_rides'.tr(),
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
                  _buildToggleItem(
                    title: 'safety.auto_share_title'.tr(),
                    subtitle: 'safety.auto_share_subtitle'.tr(),
                    value: state.autoShare,
                    onChanged: (val) {
                      context
                          .read<SafetyBloc>()
                          .add(SafetyAutoShareToggled(val));
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.divider,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _buildToggleItem(
                    title: 'safety.pin_code_title'.tr(),
                    subtitle: 'safety.pin_code_subtitle'.tr(),
                    value: state.pinCode,
                    onChanged: (val) {
                      context
                          .read<SafetyBloc>()
                          .add(SafetyPinCodeToggled(val));
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.divider,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _buildToggleItem(
                    title: 'safety.detour_alert_title'.tr(),
                    subtitle: 'safety.detour_alert_subtitle'.tr(),
                    value: state.detourAlert,
                    onChanged: (val) {
                      context
                          .read<SafetyBloc>()
                          .add(SafetyDetourAlertToggled(val));
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToggleItem({
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
}
