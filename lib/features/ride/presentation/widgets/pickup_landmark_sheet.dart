import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Bottom modal sheet for pickup location clarification ("Comment vous trouver ?")
/// Matches the reference UI design mockup:
/// - Header: Location pin in orange squircle + "Comment vous trouver ?" + "Aide le chauffeur à vous repérer vite."
/// - Orange-bordered input field with navigation arrow icon and clear button
/// - "Suggestions rapides" section with 4 quick landmark chips (Devant l'entrée, Au rond-point, Près de la station, Près de la pharmacie)
/// - Orange primary action button with navigation icon "Enregistrer"
/// - "Annuler" text button
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

  final List<_QuickSuggestionItem> _suggestions = [
    _QuickSuggestionItem(
      icon: Icons.home_rounded,
      translationKey: 'ride.suggestion_front_entrance',
      defaultLabel: "Devant l'entrée",
    ),
    _QuickSuggestionItem(
      icon: Icons.location_on_rounded,
      translationKey: 'ride.suggestion_roundabout',
      defaultLabel: 'Au rond-point',
    ),
    _QuickSuggestionItem(
      icon: Icons.directions_bus_rounded,
      translationKey: 'ride.suggestion_near_station',
      defaultLabel: 'Près de la station',
    ),
    _QuickSuggestionItem(
      icon: Icons.local_hospital_rounded,
      translationKey: 'ride.suggestion_near_pharmacy',
      defaultLabel: 'Près de la pharmacie',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLandmark ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSuggestionTap(String label) {
    setState(() {
      _controller.text = label;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: label.length),
      );
    });
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

            // 2. Header Row: Orange Squircle with Pin + Title + Subtitle
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.pickupIconBg,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: AppConstants.iconSizeXl,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingUnitXl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ride.how_to_find_you'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingXxs),
                      Text(
                        'ride.how_to_find_you_sub'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingTwenty),

            // 3. Orange Outline Input Field
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingUnitLg,
                vertical: AppConstants.spacingUnit,
              ),
              decoration: BoxDecoration(
                color: AppColors.pickupLandmarkBg,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                border: Border.all(
                  color: AppColors.pickupLandmarkBorder,
                  width: AppConstants.strokeWidthBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.pickupIconBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.near_me_rounded,
                      color: AppColors.primary,
                      size: AppConstants.iconSizeMd,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingUnitLg),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ride.pickup_landmark_hint'.tr(),
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
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
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingTwenty),

            // 4. Section: "⚡ Suggestions rapides"
            Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.primary,
                  size: AppConstants.iconSizeMd,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'ride.quick_suggestions'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingUnitLg),

            // 2x2 Grid of quick suggestion chips
            Row(
              children: [
                Expanded(
                  child: _buildSuggestionTile(_suggestions[0]),
                ),
                const SizedBox(width: AppConstants.spacingUnit),
                Expanded(
                  child: _buildSuggestionTile(_suggestions[1]),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingUnit),
            Row(
              children: [
                Expanded(
                  child: _buildSuggestionTile(_suggestions[2]),
                ),
                const SizedBox(width: AppConstants.spacingUnit),
                Expanded(
                  child: _buildSuggestionTile(_suggestions[3]),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingLg),

            // 5. Orange Action Button: "Enregistrer"
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      color: AppColors.white,
                      size: AppConstants.iconSizeMd,
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Text(
                      'ride.save'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingUnitLg),

            // 6. Text Button: "Annuler"
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.cancelTextBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingLg,
                    vertical: AppConstants.spacingSm,
                  ),
                ),
                child: Text(
                  'ride.cancel'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cancelTextBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(_QuickSuggestionItem item) {
    final label = item.translationKey.tr();
    final isSelected = _controller.text == label;

    return Material(
      color: isSelected
          ? AppColors.peachContainer
          : AppColors.pickupSuggestionBg,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: InkWell(
        onTap: () => _onSuggestionTap(label),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingUnit,
            vertical: AppConstants.spacingUnit,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.pickupSuggestionBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.pickupIconBg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  item.icon,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickSuggestionItem {
  final IconData icon;
  final String translationKey;
  final String defaultLabel;

  const _QuickSuggestionItem({
    required this.icon,
    required this.translationKey,
    required this.defaultLabel,
  });
}
