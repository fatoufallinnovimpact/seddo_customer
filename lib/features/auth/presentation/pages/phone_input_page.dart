import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/auth/domain/bloc/auth_bloc.dart';
import 'package:seddo/features/auth/domain/bloc/auth_event.dart';
import 'package:seddo/features/auth/domain/bloc/auth_state.dart';
import 'package:seddo/features/auth/presentation/pages/otp_verification_page.dart';
import 'package:seddo/features/auth/presentation/widgets/circular_back_button.dart';
import 'package:seddo/features/auth/presentation/widgets/senegal_phone_formatter.dart';

/// Écran de saisie du numéro de téléphone :
/// - Circular back button on the left, orange SEDDO logo on the right
/// - Title: "Votre numéro"
/// - Subtitle: "Un numéro Orange Money est nécessaire pour payer vos courses."
/// - Senegal phone field (+221 with fixed Senegal flag)
/// - Strictly caps input at 9 digits and automatically dismisses keyboard at limit
/// - Tapping anywhere outside dismisses keyboard
/// - Orange "Continuer" capsule button with loading indicator navigating to OTP screen
class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  late final TextEditingController _phoneController;
  late final FocusNode _phoneFocusNode;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _phoneFocusNode = FocusNode();

    // Request focus smoothly after route slide transition completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeAnimation = ModalRoute.of(context)?.animation;
      if (routeAnimation != null && !routeAnimation.isCompleted) {
        void statusListener(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            routeAnimation.removeStatusListener(statusListener);
            if (mounted) _phoneFocusNode.requestFocus();
          }
        }

        routeAnimation.addStatusListener(statusListener);
      } else {
        if (mounted) _phoneFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _onContinuePressed(BuildContext context, AuthState state) {
    if (state.isPhoneValid && state.status != AuthStatus.phoneSubmitting) {
      _phoneFocusNode.unfocus();
      context.read<AuthBloc>().add(const AuthPhoneNumberSubmittedEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == AuthStatus.phoneSubmitted ||
              current.status == AuthStatus.error),
      listener: (context, state) {
        if (state.status == AuthStatus.phoneSubmitted) {
          Navigator.of(context).push(
            SlideRightToLeftRoute(
              page: BlocProvider.value(
                value: context.read<AuthBloc>(),
                child: const OtpVerificationPage(),
              ),
            ),
          );
        } else if (state.status == AuthStatus.error &&
            state.errorMessage != null &&
            state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
                vertical: AppConstants.spacingMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Bar: Circular Back Button on left + Orange SEDDO Logo on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const CircularBackButton(),
                      SvgPicture.asset(
                        'assets/icons/seddo_logo_orange.svg',
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 2. Headline
                  Text(
                    'auth.your_number'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Subtitle
                  Text(
                    'auth.orange_money_notice'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Fixed Senegal International Phone Input
                  Row(
                    children: [
                      // Country Code Pill: Senegal Flag + '+221'
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusLg),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Image.asset(
                                'assets/images/sn.jpg',
                                width: 22,
                                height: 16,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+221',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Phone Number Input Container
                      Expanded(
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.inputBackground,
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusLg),
                          ),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              SenegalPhoneInputFormatter(),
                            ],
                            onChanged: (value) {
                              context
                                  .read<AuthBloc>()
                                  .add(AuthPhoneNumberChangedEvent(value));
                            },
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'auth.phone_hint'.tr(),
                              hintStyle: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary.withAlpha(120),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // 5. Bottom "Continuer" Button isolated to prevent rebuilding text field
                  BlocBuilder<AuthBloc, AuthState>(
                    buildWhen: (previous, current) =>
                        previous.isPhoneValid != current.isPhoneValid ||
                        previous.status != current.status,
                    builder: (context, state) {
                      final bool isSubmitting =
                          state.status == AuthStatus.phoneSubmitting;
                      final bool isEnabled =
                          state.isPhoneValid && !isSubmitting;

                      return SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: isEnabled
                              ? () => _onContinuePressed(context, state)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEnabled
                                ? AppColors.primary
                                : AppColors.buttonDisabled,
                            foregroundColor: AppColors.white,
                            disabledBackgroundColor:
                                AppColors.buttonDisabled,
                            disabledForegroundColor: AppColors.white70,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusFull,
                              ),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'auth.continue'.tr(),
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
