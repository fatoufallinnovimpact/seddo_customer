import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/safety/data/models/safety_contact_model.dart';

class SafetyAddContactDialog extends StatefulWidget {
  final ValueChanged<SafetyContactModel> onSave;

  const SafetyAddContactDialog({
    super.key,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<SafetyContactModel> onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => SafetyAddContactDialog(onSave: onSave),
    );
  }

  @override
  State<SafetyAddContactDialog> createState() => _SafetyAddContactDialogState();
}

class _SafetyAddContactDialogState extends State<SafetyAddContactDialog> {
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _inlineError;

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final relation = _relationController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.length < 2) {
      setState(() {
        _inlineError = 'safety.validation_name'.tr();
      });
      return;
    }

    if (phone.length < 9) {
      setState(() {
        _inlineError = 'safety.validation_phone'.tr();
      });
      return;
    }

    final newContact = SafetyContactModel(
      id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      relationship: relation.isNotEmpty ? relation : 'safety.relation_friend',
      phone: phone,
      avatarThemeIndex: 2,
    );

    widget.onSave(newContact);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusCardContainer),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingLg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: AppConstants.handleWidth,
              height: AppConstants.handleHeight,
              decoration: BoxDecoration(
                color: AppColors.dashedBorderGrey,
                borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            'safety.add_contact_title'.tr(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: AppConstants.fontXl,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            'safety.add_contact_desc'.tr(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: AppConstants.fontSm,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              _inlineError!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: AppConstants.fontSm,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spacingUnitXl),
          _buildField(
            label: 'safety.name_label'.tr(),
            hint: 'safety.name_hint'.tr(),
            controller: _nameController,
            icon: Icons.person_outline,
          ),
          const SizedBox(height: AppConstants.spacingUnitLg),
          _buildField(
            label: 'safety.relationship_label'.tr(),
            hint: 'safety.relationship_hint'.tr(),
            controller: _relationController,
            icon: Icons.people_outline,
          ),
          const SizedBox(height: AppConstants.spacingUnitLg),
          _buildField(
            label: 'safety.phone_label'.tr(),
            hint: '77 123 45 67',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppConstants.spacingTwenty),
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                elevation: AppConstants.elevationNone,
              ),
              child: Text(
                'safety.save_contact'.tr(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: AppConstants.fontBase,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: AppConstants.fontSm,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        Container(
          height: AppConstants.circularPickerSize,
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingUnitXl,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppConstants.iconSizeMd,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppConstants.spacingUnit),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: AppConstants.fontMd,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: hint,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: AppConstants.fontSm,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
