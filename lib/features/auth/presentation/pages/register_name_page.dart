import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/auth/presentation/widgets/circular_back_button.dart';
import 'package:seddo/features/home/presentation/pages/home_page.dart';
import 'package:seddo/features/onboarding/presentation/widgets/consent_modal_widget.dart';

/// User Name & Profile Registration Screen displayed after OTP verification:
/// - Top bar: Circular back button on the left, orange SEDDO logo on the right
/// - Headline: "Votre profil"
/// - Subtitle: "Entrez votre prénom et votre nom pour que votre chauffeur puisse vous identifier."
/// - Premium, interactive Prénom & Nom input fields with dedicated icon badges and animated focus states
/// - Clear button (cross) displayed when field contains text
/// - "Accepter et continuer" button (enabled when both fields are filled)
/// - On tap: safely unfocuses keyboard, opens the CGU Terms modal (ConsentModalWidget)
/// - Once accepted in the modal: saves profile and redirects to HomePage
class RegisterNamePage extends StatefulWidget {
  const RegisterNamePage({super.key});

  @override
  State<RegisterNamePage> createState() => _RegisterNamePageState();
}

class _RegisterNamePageState extends State<RegisterNamePage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final FocusNode _firstNameFocusNode;
  late final FocusNode _lastNameFocusNode;
  late final ValueNotifier<bool> _isFormValidNotifier;

  bool _isLoading = false;

  bool get _isFormValid =>
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _firstNameFocusNode = FocusNode();
    _lastNameFocusNode = FocusNode();
    _isFormValidNotifier = ValueNotifier<bool>(false);

    void updateFormValidity() {
      final isValid = _isFormValid;
      if (_isFormValidNotifier.value != isValid) {
        _isFormValidNotifier.value = isValid;
      }
    }

    _firstNameController.addListener(updateFormValidity);
    _lastNameController.addListener(updateFormValidity);

    // Request focus smoothly after route slide transition completes to prevent IME cancellation loop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeAnimation = ModalRoute.of(context)?.animation;
      if (routeAnimation != null && !routeAnimation.isCompleted) {
        void statusListener(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            routeAnimation.removeStatusListener(statusListener);
            if (mounted) _firstNameFocusNode.requestFocus();
          }
        }

        routeAnimation.addStatusListener(statusListener);
      } else {
        if (mounted) _firstNameFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _isFormValidNotifier.dispose();
    super.dispose();
  }

  Future<void> _onAcceptAndContinue() async {
    if (!_isFormValid || _isLoading) return;

    // 1. Hide soft keyboard completely to avoid squishing the modal bottom sheet
    FocusScope.of(context).unfocus();
    _firstNameFocusNode.unfocus();
    _lastNameFocusNode.unfocus();
    try {
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    // 2. Open the CGU & mandatory consents modal
    final accepted = await ConsentModalWidget.show(context);
    if (!mounted) return;

    if (accepted == true) {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      try {
        final lang = context.locale.languageCode;
        final firstName = _firstNameController.text.trim();
        final lastName = _lastNameController.text.trim();

        await AuthRepository().registerProfile(
          firstName: firstName,
          lastName: lastName,
          lang: lang,
          acceptData: true,
          acceptLocation: true,
        );

        if (!mounted) return;

        // Redirect to Home Page
        Navigator.of(context).pushAndRemoveUntil(
          SlideRightToLeftRoute(page: const HomePage()),
          (route) => false,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          final message = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.white,
        resizeToAvoidBottomInset: true,
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
                const SizedBox(height: AppConstants.spacingXl),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Title & Subtitle
                        Text(
                          'auth.profile_title'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingSm),
                        Text(
                          'auth.profile_subtitle'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingXl),

                        // 3. First Name Field (Prénom)
                        _buildFieldLabel('auth.first_name'.tr()),
                        const SizedBox(height: AppConstants.spacingSm),
                        _buildPremiumInputField(
                          controller: _firstNameController,
                          focusNode: _firstNameFocusNode,
                          hintText: 'auth.first_name_hint'.tr(),
                          icon: Icons.person_rounded,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) {
                            _lastNameFocusNode.requestFocus();
                          },
                        ),
                        const SizedBox(height: AppConstants.spacingTwenty),

                        // 4. Last Name Field (Nom)
                        _buildFieldLabel('auth.last_name'.tr()),
                        const SizedBox(height: AppConstants.spacingSm),
                        _buildPremiumInputField(
                          controller: _lastNameController,
                          focusNode: _lastNameFocusNode,
                          hintText: 'auth.last_name_hint'.tr(),
                          icon: Icons.badge_rounded,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _onAcceptAndContinue(),
                        ),
                        const SizedBox(height: AppConstants.spacingXxl),
                      ],
                    ),
                  ),
                ),

                // 5. "Accepter et continuer" Button
                ValueListenableBuilder<bool>(
                  valueListenable: _isFormValidNotifier,
                  builder: (context, isValid, _) {
                    final bool isButtonEnabled = isValid && !_isLoading;

                    return Container(
                      width: double.infinity,
                      height: AppConstants.buttonHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusPill,
                        ),
                        boxShadow: isButtonEnabled
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isButtonEnabled
                              ? AppColors.primary
                              : AppColors.buttonDisabled,
                          foregroundColor: AppColors.white,
                          elevation: AppConstants.elevationNone,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingMd,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusPill,
                            ),
                          ),
                        ),
                        onPressed: isButtonEnabled ? _onAcceptAndContinue : null,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'auth.accept_and_continue'.tr(),
                                      style: GoogleFonts.inter(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AppConstants.spacingSm),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: AppColors.white,
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildPremiumInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    required TextInputAction textInputAction,
    required ValueChanged<String> onSubmitted,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([focusNode, controller]),
      builder: (context, _) {
        final bool isFocused = focusNode.hasFocus;
        final bool hasText = controller.text.trim().isNotEmpty;

        return Container(
          height: 58,
          decoration: BoxDecoration(
            color: isFocused ? AppColors.white : AppColors.fieldBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(
              color: isFocused
                  ? AppColors.primary
                  : (hasText
                      ? AppColors.grayBorderMedium
                      : AppColors.border),
              width: isFocused ? 1.8 : 1.2,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Stylized Icon Badge Container
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isFocused
                      ? AppColors.peachContainer
                      : (hasText
                          ? AppColors.peachContainer.withValues(alpha: 0.5)
                          : AppColors.grayBgLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: isFocused
                      ? AppColors.primary
                      : (hasText
                          ? AppColors.primaryDark
                          : AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 12),

              // Text Field
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: textInputAction,
                  onSubmitted: onSubmitted,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              // Trailing: Only Clear Button (cross)
              if (hasText)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    controller.clear();
                    focusNode.requestFocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.chipBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
