import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/safety/data/models/safety_contact_model.dart';
import 'package:seddo/features/safety/domain/bloc/safety_bloc.dart';
import 'package:seddo/features/safety/presentation/widgets/dashed_rrect_painter.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_add_contact_dialog.dart';

class SafetyContactsSection extends StatelessWidget {
  const SafetyContactsSection({super.key});

  (Color bg, Color text) _getAvatarColors(int index) {
    switch (index % 3) {
      case 0:
        return (AppColors.contactAvatarPeachBg, AppColors.contactAvatarPeachText);
      case 1:
        return (AppColors.contactAvatarBlueBg, AppColors.contactAvatarBlueText);
      case 2:
      default:
        return (AppColors.contactAvatarYellowBg, AppColors.contactAvatarYellowText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SafetyBloc, SafetyState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'safety.section_contacts'.tr(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: AppConstants.searchLetterSpacing,
                  ),
                ),
                Row(
                  children: [
                    if (state.isUpdatingContacts) ...[
                      const SizedBox(
                        width: AppConstants.iconSizeSm,
                        height: AppConstants.iconSizeSm,
                        child: CircularProgressIndicator(
                          strokeWidth: AppConstants.strokeWidthBorder,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                    ],
                    Text(
                      '${state.contacts.length}/${AppConstants.maxEmergencyContacts}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingUnitLg),
            if (state.status == SafetyStatus.loading && state.contacts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppConstants.spacingLg),
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: AppConstants.strokeWidthBorder,
                  ),
                ),
              )
            else if (state.contacts.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: AppConstants.spacingUnit),
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusCardContainer),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: AppConstants.spacingUnit,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'safety.empty_contacts'.tr(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: AppConstants.fontMd,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              ...state.contacts.map(
                (contact) => _buildContactCard(
                  context,
                  contact,
                  state.isUpdatingContacts,
                ),
              ),
            if (state.canAddContact)
              _buildAddContactButton(context, state.isUpdatingContacts)
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spacingSm,
                ),
                child: Center(
                  child: Text(
                    'safety.limit_reached'.tr(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: AppConstants.fontSm,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    SafetyContactModel contact,
    bool isUpdating,
  ) {
    final colors = _getAvatarColors(contact.avatarThemeIndex);
    final relationDisplay = contact.relationship.startsWith('safety.')
        ? contact.relationship.tr()
        : contact.relationship;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingUnit),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCardContainer),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: AppConstants.spacingUnit,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingUnitXl,
      ),
      child: Row(
        children: [
          Container(
            width: AppConstants.avatarInitialsSize,
            height: AppConstants.avatarInitialsSize,
            decoration: BoxDecoration(
              color: colors.$1,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                contact.initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: AppConstants.fontBase,
                  fontWeight: FontWeight.w800,
                  color: colors.$2,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingUnitXl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: AppConstants.fontBase,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXxs),
                Text(
                  relationDisplay.isNotEmpty
                      ? '$relationDisplay · ${contact.phone}'
                      : contact.phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: AppConstants.iconSizeMd,
              color: AppColors.textSecondary,
            ),
            onPressed: isUpdating
                ? null
                : () {
                    context
                        .read<SafetyBloc>()
                        .add(SafetyContactRemoved(contact.id));
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildAddContactButton(BuildContext context, bool isUpdating) {
    return CustomPaint(
      painter: const DashedRRectPainter(
        color: AppColors.dashedBorderGrey,
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.dashedRadius),
          onTap: isUpdating
              ? null
              : () {
                  SafetyAddContactDialog.show(
                    context,
                    onSave: (newContact) {
                      context
                          .read<SafetyBloc>()
                          .add(SafetyContactAdded(newContact));
                    },
                  );
                },
          child: Container(
            width: double.infinity,
            height: AppConstants.heightDashedButton,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add,
                  size: AppConstants.iconSizeDefault,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'safety.add_contact'.tr(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: AppConstants.fontMd,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
