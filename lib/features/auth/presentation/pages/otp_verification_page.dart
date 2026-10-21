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
import 'package:seddo/features/auth/presentation/widgets/circular_back_button.dart';
import 'package:seddo/features/home/presentation/pages/home_page.dart';

/// OTP Verification Screen matching the reference mockup:
/// - Circular back button on the left, orange SEDDO logo on the right
/// - Title: "Code reçu par SMS"
/// - Subtitle with formatted phone number
/// - Exactly 4 individual OTP digit boxes (black filled when entered, light grey when empty)
/// - Automatically dismisses keyboard when 4 digits are entered
/// - Tapping anywhere outside dismisses keyboard
/// - Countdown timer "Renvoyer le code dans 0:42"
/// - Orange "Continuer" button (enabled when 4 digits are entered)
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

    // Auto-focus the OTP input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onContinuePressed(BuildContext context, AuthState state) {
    if (state.isOtpValid) {
      _focusNode.unfocus();
      context.read<AuthBloc>().add(const AuthOtpSubmittedEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.otpSuccess) {
          Navigator.of(context).pushAndRemoveUntil(
            SlideRightToLeftRoute(page: const HomePage()),
            (route) => false,
          );
        }
      },
      builder: (context, state) {
        final String formattedTime =
            '${state.resendSeconds ~/ 60}:${(state.resendSeconds % 60).toString().padLeft(2, '0')}';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focusNode.unfocus(),
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
                    Text(
                      '${'auth.enter_code_sent_to'.tr()} +221 ${state.formattedPhoneNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 4. Exactly 6-Digit OTP Boxes
                    GestureDetector(
                      onTap: () => _focusNode.requestFocus(),
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        children: [
                          // Visible 6 boxes with sleek, proportional sizing
                          Row(
                            children: List.generate(6, (index) {
                              final bool hasDigit =
                                  index < state.otpCode.length;
                              final String digit =
                                  hasDigit ? state.otpCode[index] : '';
                              final bool isCurrentFocus =
                                  index == state.otpCode.length &&
                                      _focusNode.hasFocus;

                              return Expanded(
                                child: Container(
                                  height: 52,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasDigit
                                        ? AppColors.otpBoxFilled
                                        : AppColors.otpBoxEmpty,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isCurrentFocus
                                        ? Border.all(
                                            color: AppColors.primary,
                                            width: 2.0,
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    digit,
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: hasDigit
                                          ? AppColors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          // Invisible actual TextField receiving numeric input
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

                                // Automatically dismiss keyboard when 6 digits are entered
                                if (value.length >= 6) {
                                  _focusNode.unfocus();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Resend Code Countdown / Action
                    if (!state.canResend)
                      Text(
                        '${'auth.resend_code_in'.tr()} $formattedTime',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      GestureDetector(
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
                      ),

                    const Spacer(),

                    // 6. Bottom "Continuer" Button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: state.isOtpValid
                            ? () => _onContinuePressed(context, state)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: state.isOtpValid
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
                        child: Text(
                          'auth.continue'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingSm),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
