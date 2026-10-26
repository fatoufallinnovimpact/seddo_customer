import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/auth/domain/bloc/auth_bloc.dart';
import 'package:seddo/features/auth/presentation/pages/phone_input_page.dart';
import 'package:seddo/features/onboarding/domain/bloc/onboarding_bloc.dart';
import 'package:seddo/features/onboarding/domain/bloc/onboarding_state.dart';
import 'package:seddo/features/onboarding/presentation/widgets/animated_parking_car_widget.dart';
import 'package:seddo/features/onboarding/presentation/widgets/consent_modal_widget.dart';
import 'package:seddo/features/onboarding/presentation/widgets/language_selector_widget.dart';

/// Main Onboarding screen with clean white theme:
/// - Pristine vector-rendered background scene on white (silhouette skyline,
///   palm trees, razor-sharp orange location pin, winding road, and decorative ambient arcs)
/// - Exact 3D orange sedan advancing and parking smoothly with suspension settle on the road
/// - Bold condensed orange SEDDO logo
/// - Bold headline: "Votre chauffeur, payé en Orange Money."
/// - Subtitle: "Prix fixe avant de partir. Zéro cash."
/// - Unified language pill container with circular French and Senegalese flags
/// - Black capsule button: "Commencer ->" / "Tambali ->"
/// - Centered 2-line legal disclaimer
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingBloc(),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  const _OnboardingView();

  Future<void> _onStartPressed(
    BuildContext context,
    OnboardingState state,
  ) async {
    if (state.isCompleted) {
      Navigator.of(context).push(
        SlideRightToLeftRoute(
          page: BlocProvider(
            create: (_) => AuthBloc(),
            child: const PhoneInputPage(),
          ),
        ),
      );
      return;
    }

    final accepted = await ConsentModalWidget.show(context);
    if (!context.mounted) return;
    if (accepted == true || context.read<OnboardingBloc>().state.isCompleted) {
      Navigator.of(context).push(
        SlideRightToLeftRoute(
          page: BlocProvider(
            create: (_) => AuthBloc(),
            child: const PhoneInputPage(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {},
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFFDF8F0),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Texts
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppConstants.spacingLg,
                    right: AppConstants.spacingLg,
                    top: AppConstants.spacingSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SEDDO Logo Text in Brand Orange
                      SvgPicture.asset(
                        'assets/icons/seddo_logo_orange.svg',
                        height: 44,
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 18),

                      // Headline
                      Text(
                        'onboarding.hero_title'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                          height: 1.18,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        'onboarding.hero_subtitle'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF555555),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Artwork: Dakar Monument + Animated Orange Sedan on Road Curve (Full phone width)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double screenWidth = constraints.maxWidth;
                      final double screenHeight = constraints.maxHeight;

                      // Full width calculation: image spans 100% of phone width
                      const double bgNativeWidth = 1024.0;
                      const double bgNativeHeight = 850.0;
                      const double bgAspect = bgNativeWidth / bgNativeHeight; // ≈ 1.205

                      // Desired height based on full phone width
                      double artworkWidth = screenWidth;
                      double artworkHeight = artworkWidth / bgAspect;

                      // If screen is unusually short, scale gracefully
                      if (artworkHeight > screenHeight) {
                        artworkHeight = screenHeight;
                        artworkWidth = artworkHeight * bgAspect;
                      }

                      final double carLeft = artworkWidth * (348.0 / bgNativeWidth);
                      final double carTop = artworkHeight * (396.0 / bgNativeHeight);
                      final double carWidth = artworkWidth * (614.0 / bgNativeWidth);
                      final double carHeight = carWidth * (506.0 / 1020.0);

                      return Center(
                        child: SizedBox(
                          width: artworkWidth,
                          height: artworkHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            fit: StackFit.expand,
                            children: [
                              // 1. Dakar Scene Background Plate (spans full phone width edge-to-edge)
                              Image.asset(
                                'assets/images/onboarding_bg_hd.png',
                                fit: BoxFit.fill,
                                width: artworkWidth,
                                height: artworkHeight,
                                filterQuality: FilterQuality.high,
                              ),

                              // 2. Animated Parking Car Layer (gliding in from right and settling on road)
                              Positioned(
                                left: carLeft,
                                top: carTop,
                                width: carWidth,
                                height: carHeight,
                                child: AnimatedParkingCarWidget(
                                  driveOffset: carWidth * 0.55,
                                ),
                              ),

                              // 3. Smooth bottom gradient fade to seamlessly melt into background color (0xFFFDF8F0)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: -1,
                                height: artworkHeight * 0.28,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          const Color(0xFFFDF8F0).withValues(alpha: 0.0),
                                          const Color(0xFFFDF8F0).withValues(alpha: 0.4),
                                          const Color(0xFFFDF8F0).withValues(alpha: 0.85),
                                          const Color(0xFFFDF8F0),
                                        ],
                                        stops: const [0.0, 0.4, 0.8, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppConstants.spacingLg,
                    right: AppConstants.spacingLg,
                    bottom: AppConstants.spacingSm,
                  ),
                  child: Column(
                    children: [
                      // Bilingual Language Pills with Circular Flags
                      const LanguageSelectorWidget(),
                      const SizedBox(height: AppConstants.spacingMd),

                      // Primary Action Capsule: Black "Commencer ->"
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => _onStartPressed(context, state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonBlack,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusFull,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'onboarding.start'.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacingSm),
                              const Icon(
                                Icons.arrow_forward,
                                color: AppColors.white,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingMd),

                      // Legal Disclaimer Footer
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingSm,
                          ),
                          child: Text(
                            'onboarding.legal_notice'.tr(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8E8E93),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingXs),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
