import 'dart:math' as math;
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

/// Main Onboarding screen matching the exact reference design au détail près:
/// - Pristine vector-rendered background scene from scene.jpeg (silhouette skyline,
///   palm trees, razor-sharp location pin, winding road, and decorative concentric arcs)
/// - Exact 3D orange sedan advancing and parking smoothly with suspension settle on the road
/// - Bold condensed SEDDO logo
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
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {},
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.primary,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final double screenWidth = constraints.maxWidth;
              final double screenHeight = constraints.maxHeight;

              // Mathematical mapping from scene.jpeg (509 x 1024) to screen coordinates
              final double scale = math.max(
                screenWidth / 509.0,
                screenHeight / 1024.0,
              );
              final double scaledWidth = 509.0 * scale;
              final double scaledHeight = 1024.0 * scale;
              final double dx = (screenWidth - scaledWidth) / 2.0;
              final double dy = (screenHeight - scaledHeight) / 2.0;

              // Resting parking position of the car in scene.jpeg (x=200, y=510, w=254, h=123)
              final double carLeft = dx + 200.0 * scale;
              final double carTop = dy + 510.0 * scale;
              final double carWidth = 254.0 * scale;
              final double carHeight = 123.0 * scale;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Pristine Full-screen Background Scene (Vector-sharp artwork from scene.jpeg)
                  Positioned(
                    left: dx,
                    top: dy,
                    width: scaledWidth,
                    height: scaledHeight,
                    child: Image.asset(
                      'assets/images/scene.jpeg',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),

                  // 2. Animated Parking Car Layer (driving in and settling on the road)
                  Positioned(
                    left: carLeft,
                    top: carTop,
                    width: carWidth,
                    height: carHeight,
                    child: AnimatedParkingCarWidget(
                      driveOffset: carWidth * 0.55,
                    ),
                  ),

                  // 3. UI Controls and Texts
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingLg,
                        vertical: AppConstants.spacingMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppConstants.spacingSm),

                          // SEDDO Logo Text
                          SvgPicture.asset(
                            'assets/icons/seddo_logo_white.svg',
                            height: 52,
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: AppConstants.spacingLg),

                          // Headline
                          Text(
                            'onboarding.hero_title'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                              height: 1.22,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingMd),

                          // Subtitle
                          Text(
                            'onboarding.hero_subtitle'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: AppColors.white90,
                              height: 1.35,
                            ),
                          ),

                          const Spacer(),

                          // Bilingual Language Pills with Circular Flags
                          const LanguageSelectorWidget(),
                          const SizedBox(height: AppConstants.spacingMd),

                          // Primary Action Capsule: Black "Commencer ->"
                          SizedBox(
                            width: double.infinity,
                            height: 58,
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
                                  color: AppColors.white90,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingXs),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
