import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';

/// Modern incident reporting bottom sheet for passenger safety:
/// - Categorized incident tags (Conduite, Véhicule, Tarif, Comportement)
/// - Optional description text field
/// - Immediate alert transmission to Seddo 24/7 security team
class SafetyIncidentReportSheet extends StatefulWidget {
  final DriverModel driver;

  const SafetyIncidentReportSheet({
    super.key,
    required this.driver,
  });

  static Future<void> show(BuildContext context, {required DriverModel driver}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => SafetyIncidentReportSheet(driver: driver),
    );
  }

  @override
  State<SafetyIncidentReportSheet> createState() => _SafetyIncidentReportSheetState();
}

class _SafetyIncidentReportSheetState extends State<SafetyIncidentReportSheet> {
  final TextEditingController _commentController = TextEditingController();
  final Set<String> _selectedReasons = {};

  static const List<String> _incidentCategoryKeys = [
    'safety.incident_cat_driving',
    'safety.incident_cat_vehicle',
    'safety.incident_cat_behavior',
    'safety.incident_cat_price',
    'safety.incident_cat_phone',
    'safety.incident_cat_detour',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toggleReason(String key) {
    setState(() {
      if (_selectedReasons.contains(key)) {
        _selectedReasons.remove(key);
      } else {
        _selectedReasons.add(key);
      }
    });
  }

  void _submitReport() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.buttonBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.refundGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'safety.incident_success'.tr(),
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        14,
        AppConstants.spacingLg,
        (keyboardBottom > 0 ? keyboardBottom : systemBottom) + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: AppConstants.circularIconContainerSize,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dragHandle,
                borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Shield Alert Icon
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.walletContainerBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.report_problem_rounded,
                  color: AppColors.sirenRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'safety.incident_title'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'safety.incident_ride_with'.tr(
                        args: [widget.driver.name, widget.driver.carModel],
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            'safety.incident_question'.tr(),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Categorized chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _incidentCategoryKeys.map((catKey) {
              final isSelected = _selectedReasons.contains(catKey);
              return GestureDetector(
                onTap: () => _toggleReason(catKey),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.walletContainerBg
                        : AppColors.tagChipBg,
                    borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                    border: Border.all(
                      color: isSelected ? AppColors.sirenRed : AppColors.cardBorder,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    catKey.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? AppColors.sirenRed : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Text details
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'safety.incident_comment_hint'.tr(),
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.tagChipBg,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sirenRed,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
                elevation: 0,
              ),
              onPressed: _submitReport,
              child: Text(
                'safety.incident_submit'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
