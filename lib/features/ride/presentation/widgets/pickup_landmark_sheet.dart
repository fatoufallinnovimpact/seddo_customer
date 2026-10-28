import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Bottom modal sheet for pickup location clarification ("Comment vous trouver ?")
/// Simplified & clean interface:
/// - Clean header (title & subtitle, no overwhelming orange)
/// - Single intuitive text field (opens keyboard on tap, clear button)
/// - No suggestions
/// - "Enregistrer" button & "Annuler"
class PickupLandmarkSheet extends StatefulWidget {
  final String? initialLandmark;

  const PickupLandmarkSheet({
    super.key,
    this.initialLandmark,
  });

  /// Displays the sheet as a modal bottom sheet and returns the entered landmark note.
  static Future<String?> show(
    BuildContext context, {
    String? initialLandmark,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.shadowDarkBlack,
      builder: (ctx) => PickupLandmarkSheet(
        initialLandmark: initialLandmark,
      ),
    );
  }

  @override
  State<PickupLandmarkSheet> createState() => _PickupLandmarkSheetState();
}

class _PickupLandmarkSheetState extends State<PickupLandmarkSheet> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLandmark ?? '');
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSave() {
    final note = _controller.text.trim();
    Navigator.of(context).pop(note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final systemBottom = media.padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusSheet),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowCardBlack,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingUnitLg,
        AppConstants.spacingLg,
        bottomInset > 0
            ? bottomInset + AppConstants.spacingMd
            : systemBottom + AppConstants.spacingMd,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Drag Handle
            Center(
              child: Container(
                width: AppConstants.handleWidth,
                height: AppConstants.handleHeight,
                decoration: BoxDecoration(
                  color: AppColors.dragHandle,
                  borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),

            // 2. Header : Titre & Sous-titre épurés
            Text(
              'ride.how_to_find_you'.tr(),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ride.how_to_find_you_sub'.tr(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // 3. Champ de saisie épuré (fond neutre, bordure discrète)
            Container(
              decoration: BoxDecoration(
                color: AppColors.neutralInputBg,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AppColors.primary
                      : AppColors.neutralInputBorder,
                  width: _focusNode.hasFocus ? 1.5 : 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingUnitXl),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.neutralIconGrey,
                    size: AppConstants.iconSizeMd,
                  ),
                  const SizedBox(width: AppConstants.spacingUnit),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _onSave(),
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ride.pickup_landmark_hint'.tr(),
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.neutralPlaceholder,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppConstants.spacingUnitXl,
                        ),
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.clear();
                        });
                      },
                      child: Container(
                        width: AppConstants.iconSizeLg,
                        height: AppConstants.iconSizeLg,
                        decoration: const BoxDecoration(
                          color: AppColors.neutralInputBorder,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          size: AppConstants.iconSizeSm - 2,
                          color: AppColors.neutralIconGrey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 4. Bouton principal : Enregistrer
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: AppConstants.elevationNone,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusPill,
                    ),
                  ),
                ),
                onPressed: _onSave,
                child: Text(
                  'ride.save'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 5. Bouton secondaire : Annuler
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingLg,
                    vertical: AppConstants.spacingSm,
                  ),
                ),
                child: Text(
                  'ride.cancel'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
