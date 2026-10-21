import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/onboarding/domain/bloc/onboarding_bloc.dart';
import 'package:seddo/features/onboarding/domain/bloc/onboarding_event.dart';
import 'package:seddo/features/onboarding/domain/bloc/onboarding_state.dart';

/// Modal bottom sheet listing terms and mandatory consents matching the design spec:
/// - Rounded top bottom sheet with drag handle
/// - Peach container with verified shield icon
/// - Uppercase header "CONSENTEMENTS OBLIGATOIRES" + explanatory subtitle
/// - 3-segment progress indicator with reactive counter ("0/3" -> "3/3")
/// - 3 selectable cards (CGU, Data Privacy, Geolocation) with white icon square and circular radio check
/// - Legal notice disclaimer
/// - "Accepter & Commencer →" button with soft peach disabled look transitioning to vivid orange
class ConsentModalWidget extends StatefulWidget {
  const ConsentModalWidget({super.key});

  static Future<bool?> show(BuildContext context) {
    final bloc = context.read<OnboardingBloc>();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusSheet),
        ),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: bloc,
          child: const ConsentModalWidget(),
        );
      },
    );
  }

  @override
  State<ConsentModalWidget> createState() => _ConsentModalWidgetState();
}

class _ConsentModalWidgetState extends State<ConsentModalWidget> {
  bool _acceptedCgu = false;
  bool _acceptedPrivacy = false;
  bool _acceptedLocation = false;

  int get _selectedCount =>
      (_acceptedCgu ? 1 : 0) +
      (_acceptedPrivacy ? 1 : 0) +
      (_acceptedLocation ? 1 : 0);

  bool get _allSelected => _selectedCount == 3;

  void _handleAcceptAndStart(BuildContext context) {
    context.read<OnboardingBloc>().add(const OnboardingCompletedEvent());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      builder: (context, state) {
        final title = 'consent.title'.tr();
        final subtitle = 'consent.subtitle'.tr();
        final termsLabel = 'consent.cgu'.tr();
        final privacyLabel = 'consent.privacy'.tr();
        final locationLabel = 'consent.location'.tr();
        final startButtonLabel = 'consent.accept_start'.tr();
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final systemBottom = MediaQuery.of(context).padding.bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppConstants.spacingLg,
              right: AppConstants.spacingLg,
              top: AppConstants.spacingMd,
              bottom: bottomInset > 0
                  ? bottomInset + AppConstants.spacingMd
                  : (systemBottom > 0
                      ? systemBottom + AppConstants.spacingUnit
                      : AppConstants.spacingLg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Drag handle bar
                Center(
                  child: Container(
                    width: AppConstants.handleWidth,
                    height: AppConstants.handleHeight,
                    decoration: BoxDecoration(
                      color: AppColors.dragHandle,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusXs),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),

                // 2. Brand Shield Badge & Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.peachContainer,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusLg),
                      ),
                      child: const Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: AppColors.primary,
                              size: 28,
                            ),
                            Icon(
                              Icons.check,
                              color: AppColors.primary,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingUnitXl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              height: 1.12,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingXs),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingMd),

                // 3. Segmented Progress Bar & Counter ("0/3" -> "3/3")
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _buildProgressBarSegment(isFilled: _selectedCount >= 1),
                          const SizedBox(width: AppConstants.spacingS),
                          _buildProgressBarSegment(isFilled: _selectedCount >= 2),
                          const SizedBox(width: AppConstants.spacingS),
                          _buildProgressBarSegment(isFilled: _selectedCount >= 3),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingUnitXl),
                    Text(
                      '$_selectedCount/3',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.orangeDarkAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingUnitXl),

                // 4. Three Selectable Consent Cards
                _ConsentSelectionCard(
                  icon: Icons.article_outlined,
                  title: termsLabel,
                  isSelected: _acceptedCgu,
                  onTap: () {
                    setState(() {
                      _acceptedCgu = !_acceptedCgu;
                    });
                  },
                ),
                const SizedBox(height: AppConstants.spacingUnit),
                _ConsentSelectionCard(
                  icon: Icons.shield_outlined,
                  title: privacyLabel,
                  isSelected: _acceptedPrivacy,
                  onTap: () {
                    setState(() {
                      _acceptedPrivacy = !_acceptedPrivacy;
                    });
                  },
                ),
                const SizedBox(height: AppConstants.spacingUnit),
                _ConsentSelectionCard(
                  icon: Icons.location_on_outlined,
                  title: locationLabel,
                  isSelected: _acceptedLocation,
                  onTap: () {
                    setState(() {
                      _acceptedLocation = !_acceptedLocation;
                    });
                  },
                ),
                const SizedBox(height: AppConstants.spacingMd),

                // 5. Subtle Legal Notice Disclaimer
                Text(
                  'onboarding.legal_notice'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),

                // 6. Action Button: "Accepter & Commencer →"
                SizedBox(
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => _handleAcceptAndStart(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allSelected
                          ? AppColors.primary
                          : AppColors.consentButtonDisabled,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingMd,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusLg),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            startButtonLabel,
                            style: GoogleFonts.inter(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingSm),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.white,
                          size: AppConstants.iconSizeMd,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBarSegment({required bool isFilled}) {
    return Expanded(
      child: Container(
        height: 4.5,
        decoration: BoxDecoration(
          color: isFilled ? AppColors.primary : AppColors.grayBgLight,
          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
        ),
      ),
    );
  }
}

/// A sleek interactive consent selection card with white icon box and circular radio toggle
class _ConsentSelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConsentSelectionCard({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingUnitLg,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceGrey,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          child: Row(
            children: [
              // White rounded container with orange brand icon
              Container(
                width: AppConstants.circularButtonSize,
                height: AppConstants.circularButtonSize,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusDefault),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: AppConstants.iconSizeLg,
                  color: AppColors.orangeDarkAccent,
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitXl),

              // Title Text
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnit),

              // Circular Radio Selection Checkbox
              Container(
                width: AppConstants.spacingLg,
                height: AppConstants.spacingLg,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isSelected ? AppColors.primary : AppColors.transparent,
                  border: isSelected
                      ? null
                      : Border.all(
                          color: AppColors.grayBorderMedium,
                          width: 2.0,
                        ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: AppColors.white,
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
