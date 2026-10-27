import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/auth/domain/bloc/auth_bloc.dart';
import 'package:seddo/features/auth/domain/bloc/auth_event.dart';
import 'package:seddo/features/auth/domain/bloc/auth_state.dart';
import 'package:seddo/features/auth/presentation/pages/register_name_page.dart';
import 'package:seddo/features/auth/presentation/widgets/circular_back_button.dart';
import 'package:seddo/features/home/presentation/pages/home_page.dart';

/// 6-digit OTP SMS / WhatsApp Verification Screen:
/// - Circular back button on the left, orange SEDDO logo on the right
/// - Title: "Code reçu par SMS"
/// - Subtitle: "Entrez le code envoyé au +221 XX XXX XX XX"
/// - Exactly 6 digit OTP boxes with smooth animation
/// - Resend timer with countdown
/// - Orange "Continuer" button navigating to RegisterNamePage if needsProfile is true, or HomePage if false
class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  late final TextEditingController _otpController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController();
    _focusNode = FocusNode();

    // Request focus smoothly after route slide transition completes to prevent IME cancellation loop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeAnimation = ModalRoute.of(context)?.animation;
      if (routeAnimation != null && !routeAnimation.isCompleted) {
        void statusListener(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            routeAnimation.removeStatusListener(statusListener);
            if (mounted) _focusNode.requestFocus();
          }
        }

        routeAnimation.addStatusListener(statusListener);
      } else {
        if (mounted) _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onContinuePressed(BuildContext context, AuthState state) {
    if (state.isOtpValid && state.status != AuthStatus.otpVerifying) {
      _focusNode.unfocus();
      context.read<AuthBloc>().add(const AuthOtpSubmittedEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == AuthStatus.otpSuccess ||
              current.status == AuthStatus.error),
      listener: (context, state) {
        if (state.status == AuthStatus.otpSuccess) {
          // If the user already has a complete profile (needsProfile == false), go directly to Home
          if (!state.needsProfile) {
            Navigator.of(context).pushAndRemoveUntil(
              SlideRightToLeftRoute(page: const HomePage()),
              (route) => false,
            );
          } else {
            // New user needing profile setup
            Navigator.of(context).pushReplacement(
              SlideRightToLeftRoute(page: const RegisterNamePage()),
            );
          }
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
                    'auth.code_received'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Subtitle with phone number
                  BlocBuilder<AuthBloc, AuthState>(
                    buildWhen: (p, c) =>
                        p.formattedPhoneNumber != c.formattedPhoneNumber,
                    builder: (context, state) {
                      return Text(
                        '${'auth.enter_code_sent_to'.tr()} +221 ${state.formattedPhoneNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // 4. Exactly 6-Digit OTP Boxes
                  GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      children: [
                        // Visible 6 boxes with sleek, proportional sizing
                        BlocBuilder<AuthBloc, AuthState>(
                          buildWhen: (p, c) => p.otpCode != c.otpCode,
                          builder: (context, state) {
                            return Row(
                              children: List.generate(6, (index) {
                                final bool hasDigit =
                                    index < state.otpCode.length;
                                final String digit =
                                    hasDigit ? state.otpCode[index] : '';
                                final bool isCurrentFocus =
                                    _focusNode.hasFocus &&
                                        index == state.otpCode.length;

                                return Expanded(
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      right: index == 5 ? 0 : 8,
                                    ),
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: hasDigit
                                          ? AppColors.white
                                          : AppColors.otpBoxEmpty,
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.radiusDefault,
                                      ),
                                      border: Border.all(
                                        color: isCurrentFocus
                                            ? AppColors.primary
                                            : (hasDigit
                                                ? AppColors.grayBorderMedium
                                                : AppColors.transparent),
                                        width: isCurrentFocus ? 2.0 : 1.2,
                                      ),
                                      boxShadow: isCurrentFocus
                                          ? const [
                                              BoxShadow(
                                                color: AppColors.shadowLight,
                                                blurRadius: 8,
                                                offset: Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      digit,
                                      style: GoogleFonts.inter(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),

                        // Hidden real TextField capturing user keyboard input
                        Opacity(
                          opacity: 0.0,
                          child: TextField(
                            controller: _otpController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (value) {
                              context
                                  .read<AuthBloc>()
                                  .add(AuthOtpCodeChangedEvent(value));

                              if (value.length == 6) {
                                _focusNode.unfocus();
                                context
                                    .read<AuthBloc>()
                                    .add(const AuthOtpSubmittedEvent());
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Countdown / Resend Action isolated from main page
                  BlocBuilder<AuthBloc, AuthState>(
                    buildWhen: (p, c) =>
                        p.resendSeconds != c.resendSeconds ||
                        p.canResend != c.canResend,
                    builder: (context, state) {
                      final String formattedTime =
                          '${state.resendSeconds ~/ 60}:${(state.resendSeconds % 60).toString().padLeft(2, '0')}';

                      if (!state.canResend) {
                        return Row(
                          children: [
                            Text(
                              'auth.resend_code_in'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedTime,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return GestureDetector(
                          onTap: () {
                            context
                                .read<AuthBloc>()
                                .add(const AuthResendOtpEvent());
                          },
                          child: Text(
                            'auth.resend_code'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }
                    },
                  ),

                  const Spacer(),

                  // 6. Bottom "Continuer" Button isolated to prevent unnecessary rebuilds
                  BlocBuilder<AuthBloc, AuthState>(
                    buildWhen: (p, c) =>
                        p.isOtpValid != c.isOtpValid || p.status != c.status,
                    builder: (context, state) {
                      final bool isVerifying =
                          state.status == AuthStatus.otpVerifying;
                      final bool isEnabled = state.isOtpValid && !isVerifying;

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
                            disabledBackgroundColor: AppColors.buttonDisabled,
                            disabledForegroundColor: AppColors.white70,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusFull,
                              ),
                            ),
                          ),
                          child: isVerifying
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
