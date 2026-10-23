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
            Text(
              'safety.section_contacts'.tr(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            ...state.contacts.map((contact) => _buildContactCard(context, contact)),
            _buildAddContactButton(context),
          ],
        );
      },
    );
  }

  Widget _buildContactCard(BuildContext context, SafetyContactModel contact) {
    final colors = _getAvatarColors(contact.avatarThemeIndex);
    final relationDisplay = contact.relationship.startsWith('safety.')
        ? contact.relationship.tr()
        : contact.relationship;

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.$2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$relationDisplay · ${contact.phone}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
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
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              context
                  .read<SafetyBloc>()
                  .add(SafetyContactRemoved(contact.id));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddContactButton(BuildContext context) {
    return CustomPaint(
      painter: const DashedRRectPainter(
        color: AppColors.dashedBorderGrey,
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.dashedRadius),
          onTap: () {
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
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  'safety.add_contact'.tr(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
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
