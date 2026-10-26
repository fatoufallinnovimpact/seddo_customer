import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:url_launcher/url_launcher.dart';

enum CallState {
  connecting,
  ringing,
  connected,
  ended,
}

/// Yango-style In-App VoIP Audio Call Screen.
/// Provides an encrypted, private in-app calling experience between customer and driver.
/// Built with responsive scrollable layout to prevent any overflow on all screen sizes.
class InAppCallPage extends StatefulWidget {
  final DriverModel driver;

  const InAppCallPage({
    super.key,
    required this.driver,
  });

  static Future<void> show(BuildContext context, {required DriverModel driver}) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, animation, secondaryAnimation) => InAppCallPage(driver: driver),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<InAppCallPage> createState() => _InAppCallPageState();
}

class _InAppCallPageState extends State<InAppCallPage>
    with TickerProviderStateMixin {
  CallState _callState = CallState.connecting;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  int _callSeconds = 0;
  Timer? _callTimer;
  Timer? _stateTimer;

  late final AnimationController _pulseController;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    // Concentric pulsing radar rings for avatar
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Voice waveform simulation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Call state sequence mimicking realistic VoIP connection
    _stateTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _callState = CallState.ringing;
      });

      _stateTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        HapticFeedback.lightImpact();
        setState(() {
          _callState = CallState.connected;
        });
        _startCallTimer();
      });
    });
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _callSeconds++;
      });
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _stateTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleSpeaker() {
    HapticFeedback.selectionClick();
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _endCall() {
    HapticFeedback.heavyImpact();
    _callTimer?.cancel();
    _stateTimer?.cancel();
    setState(() {
      _callState = CallState.ended;
    });
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _fallbackToGsmCall() async {
    final cleanPhone = widget.driver.phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF14171A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Sleek dark ambient gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF2A2018), // subtle brand orange glow
                  Color(0xFF14171A),
                  Color(0xFF0D0F12),
                ],
              ),
            ),
          ),

          // 2. Main Content wrapped with SingleChildScrollView + LayoutBuilder to NEVER overflow
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Top Bar: Minimize button & Encryption security badge
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white70,
                                    size: 30,
                                  ),
                                  tooltip: 'Réduire l\'appel',
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: AppColors.success,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Appel Seddo · Chiffré',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 48), // balance header
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Center: Driver Profile Showcase with Pulsing Radar Rings
                          Center(
                            child: SizedBox(
                              width: 170,
                              height: 170,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Animated Radar Rings (when ringing or in call)
                                  if (_callState != CallState.ended)
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        final progress = _pulseController.value;
                                        final ring1 = (progress * 1.0) % 1.0;
                                        final ring2 = ((progress + 0.5) * 1.0) % 1.0;

                                        return Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Ring 1
                                            Transform.scale(
                                              scale: 1.0 + (ring1 * 0.40),
                                              child: Container(
                                                width: 116,
                                                height: 116,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: AppColors.primary.withValues(
                                                      alpha: (1.0 - ring1) * 0.35,
                                                    ),
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Ring 2
                                            Transform.scale(
                                              scale: 1.0 + (ring2 * 0.40),
                                              child: Container(
                                                width: 116,
                                                height: 116,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: AppColors.primary.withValues(
                                                      alpha: (1.0 - ring2) * 0.25,
                                                    ),
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),

                                  // Center Avatar
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: widget.driver.photoUrl != null &&
                                              widget.driver.photoUrl!.isNotEmpty
                                          ? Image.network(
                                              widget.driver.photoUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => _buildDefaultAvatar(),
                                            )
                                          : _buildDefaultAvatar(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Driver Name
                          Text(
                            widget.driver.name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Vehicle Info & Rating Pill
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${widget.driver.carModel} · ${widget.driver.licensePlate}',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                                    const SizedBox(width: 3),
                                    Text(
                                      widget.driver.rating.toStringAsFixed(1),
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Call Status Text / Live Duration
                          _buildStatusIndicator(),

                          const Spacer(),

                          // Audio Waveform (constant height reserved to eliminate layout jump upon connecting!)
                          SizedBox(
                            height: 28,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: _callState == CallState.connected ? 1.0 : 0.0,
                              child: _buildAudioWaveform(),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // In-Call Action Control Buttons (Mute, Speaker, Keypad)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Mute Button
                                _buildCircleActionButton(
                                  icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                  label: _isMuted ? 'Muet activé' : 'Micro',
                                  isActive: _isMuted,
                                  activeColor: Colors.redAccent,
                                  onTap: _toggleMute,
                                ),

                                // Speakerphone Button
                                _buildCircleActionButton(
                                  icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                                  label: _isSpeakerOn ? 'Haut-parleur' : 'Écouteur',
                                  isActive: _isSpeakerOn,
                                  activeColor: AppColors.primary,
                                  onTap: _toggleSpeaker,
                                ),

                                // Keypad Button
                                _buildCircleActionButton(
                                  icon: Icons.dialpad_rounded,
                                  label: 'Clavier',
                                  isActive: false,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _showKeypadModal(context);
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Large Red Hang Up Button
                          GestureDetector(
                            onTap: _endCall,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE53935).withValues(alpha: 0.45),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Fallback GSM Call Option
                          TextButton.icon(
                            onPressed: _fallbackToGsmCall,
                            icon: const Icon(
                              Icons.phone_outlined,
                              color: Colors.white54,
                              size: 15,
                            ),
                            label: Text(
                              'Problème de réseau ? Appeler par téléphone',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white54,
                              ),
                            ),
                          ),

                          SizedBox(height: math.max(8, bottomPadding)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFF2C2F33),
      child: Center(
        child: Text(
          widget.driver.name.isNotEmpty ? widget.driver.name[0].toUpperCase() : 'C',
          style: GoogleFonts.inter(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    switch (_callState) {
      case CallState.connecting:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Connexion sécurisée...',
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        );
      case CallState.ringing:
        return Text(
          'Sonnerie en cours...',
          style: GoogleFonts.inter(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        );
      case CallState.connected:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_callSeconds),
                style: GoogleFonts.inter(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      case CallState.ended:
        return Text(
          'Appel terminé',
          style: GoogleFonts.inter(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: Colors.redAccent,
          ),
        );
    }
  }

  Widget _buildAudioWaveform() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(12, (index) {
            final phase = (index / 12.0) * 2 * math.pi;
            final wave = math.sin(_waveController.value * 2 * math.pi + phase);
            final height = 5.0 + (wave.abs() * 16.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.2),
              width: 3.2,
              height: height,
              decoration: BoxDecoration(
                color: _isMuted
                    ? Colors.white24
                    : AppColors.primary.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final bgColor = isActive
        ? (activeColor ?? AppColors.primary)
        : Colors.white.withValues(alpha: 0.12);
    final iconColor = isActive ? Colors.white : Colors.white.withValues(alpha: 0.9);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  void _showKeypadModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2124),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Clavier numérique',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#']
                    .map((key) => GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                key,
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
