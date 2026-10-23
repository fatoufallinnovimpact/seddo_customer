import 'dart:async';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/safety/domain/bloc/safety_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetySosCard extends StatefulWidget {
  const SafetySosCard({super.key});

  @override
  State<SafetySosCard> createState() => _SafetySosCardState();
}

class _SafetySosCardState extends State<SafetySosCard>
    with SingleTickerProviderStateMixin {
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  bool _isHolding = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _pulseController.repeat(reverse: true);
    }
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startHolding() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    const stepMs = 50;
    final totalSteps = (AppConstants.sosHoldDurationSeconds * 1000) / stepMs;
    int currentStep = 0;

    _holdTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      currentStep++;
      setState(() {
        _holdProgress = (currentStep / totalSteps).clamp(0.0, 1.0);
      });
      if (currentStep >= totalSteps) {
        timer.cancel();
        _triggerSos();
      }
    });
  }

  void _cancelHolding() {
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  void _triggerSos() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
    context.read<SafetyBloc>().add(const SafetySosTriggered());
  }

  Future<void> _callPolice() async {
    final uri = Uri.parse('tel:${AppConstants.emergencyPoliceNumber}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SafetyBloc, SafetyState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusCardContainer),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.sosTriggered) ...[
                _buildActiveAlertBanner(context),
                const SizedBox(height: 18),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'safety.sos_title'.tr(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'safety.sos_subtitle'.tr(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  _buildSosButton(),
                ],
              ),
              if (_isHolding) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _holdProgress,
                    backgroundColor: AppColors.sosOuterRing,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.sosInnerCircle,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSosButton() {
    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _cancelHolding(),
      onTapCancel: _cancelHolding,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = _isHolding ? 1.08 : _pulseAnimation.value;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: AppConstants.sosOuterRingSize,
              height: AppConstants.sosOuterRingSize,
              decoration: const BoxDecoration(
                color: AppColors.sosOuterRing,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: AppConstants.sosInnerCircleSize,
                  height: AppConstants.sosInnerCircleSize,
                  decoration: const BoxDecoration(
                    color: AppColors.sosInnerCircle,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'safety.sos_button'.tr(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveAlertBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sosAlertBannerBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusSquircle),
        border: Border.all(
          color: AppColors.sosAlertBannerRed.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.sosAlertBannerRed,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'safety.sos_alert_title'.tr(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.sosAlertBannerRed,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.sosAlertBannerRed,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  context.read<SafetyBloc>().add(const SafetySosDismissed());
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'safety.sos_alert_desc'.tr(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.sosAlertBannerRed,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _callPolice,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sosAlertBannerRed,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
              icon: const Icon(Icons.phone, size: 16),
              label: Text(
                'safety.sos_call_police'.tr(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
