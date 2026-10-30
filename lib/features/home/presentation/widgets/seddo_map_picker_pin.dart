import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Marqueur de sélection sur la carte inspiré du design Yango
/// adapté aux couleurs et à l'identité visuelle de Seddo :
/// - Icône personnalisable (ex: location-pin vectoriel orange) ou squircle orange par défaut
/// - Tige verticale fine sombre ou pointe vectorielle
/// - Ombre au sol dynamique
/// - Animation de lévitation / flottement doux pendant le déplacement
/// - Animation d'atterrissage avec petit rebond (jump) à l'arrêt sur une adresse
class SeddoMapPickerPin extends StatefulWidget {
  final bool isMoving;
  final String? label;
  final Widget? customPinIcon;
  final double? yAnchorOffset;

  const SeddoMapPickerPin({
    super.key,
    required this.isMoving,
    this.label,
    this.customPinIcon,
    this.yAnchorOffset,
  });

  @override
  State<SeddoMapPickerPin> createState() => _SeddoMapPickerPinState();
}

class _SeddoMapPickerPinState extends State<SeddoMapPickerPin>
    with TickerProviderStateMixin {
  late final AnimationController _liftController;
  late final Animation<double> _liftAnimation;

  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Contrôleur de soulèvement et d'atterrissage (avec un SEUL rebond franc)
    _liftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 360),
    );

    _liftAnimation = CurvedAnimation(
      parent: _liftController,
      curve: Curves.easeOutCubic,
      reverseCurve: const SingleBounceLandingCurve(),
    );

    // Contrôleur d'oscillation douce de haut en bas pendant que l'utilisateur déplace la carte
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    _liftController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.isMoving) {
          _floatController.repeat(reverse: true);
        }
      }
    });

    if (widget.isMoving) {
      _liftController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant SeddoMapPickerPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMoving != oldWidget.isMoving) {
      if (widget.isMoving) {
        _liftController.forward();
      } else {
        _floatController.stop();
        _floatController.reset();
        _liftController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _liftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_liftAnimation, _floatAnimation]),
      builder: (context, child) {
        final liftValue = _liftAnimation.value;
        final floatOffset = widget.isMoving && liftValue > 0.8
            ? _floatAnimation.value
            : 0.0;

        // Le marqueur s'élève de 20 px + le flottement continu
        final totalYOffset = -(liftValue * 20.0) + floatOffset;
        final shadowScale = math.max(0.45, 1.0 - (liftValue * 0.45));
        final shadowOpacity = math.max(0.18, 0.45 - (liftValue * 0.25));

        final double anchor = widget.yAnchorOffset ??
            (widget.customPinIcon != null
                ? (widget.label != null && widget.label!.isNotEmpty
                    ? 36.0
                    : 22.0)
                : 33.0);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Ombre au sol (reste ancrée au centre exact de la carte)
            Transform.translate(
              offset: const Offset(0, 0),
              child: Transform.scale(
                scale: shadowScale,
                child: Container(
                  width: 16,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: shadowOpacity),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: shadowOpacity * 0.7),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Marqueur surélevé (Tige + Badge ou customPinIcon)
            Transform.translate(
              // Le bas de la pointe est calé précisément au niveau de l'ombre au sol (0,0)
              offset: Offset(0, totalYOffset - anchor),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.label != null && widget.label!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mapPinAnchor,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusItem),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowHeavy,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.label!,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (widget.customPinIcon != null)
                    widget.customPinIcon!
                  else ...[
                    // Badge orange arrondi
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.mapPickerPinOrange,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.38),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                          const BoxShadow(
                            color: AppColors.shadowCardBlack,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.hail_rounded,
                        color: AppColors.white,
                        size: 27,
                      ),
                    ),

                    // Tige verticale noire fine
                    Container(
                      width: 3.0,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.markerIconBlack,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Courbe d'atterrissage sur la carte qui produit exactement UN seul rebond ("sautille une seule fois")
class SingleBounceLandingCurve extends Curve {
  const SingleBounceLandingCurve();

  @override
  double transformInternal(double t) {
    // Lors du reverse(), t décroît de 1.0 (en l'air) à 0.0 (au sol).
    // De t = 1.0 à 0.35 : la quille descend jusqu'au sol (valeur atteint 0.0).
    // De t = 0.35 à 0.0 : un seul rebond net et franc (hauteur maximale ~4.4px au sommet à t = 0.175),
    //                     puis la quille se pose définitivement à t = 0.0 sans aucun deuxième rebond.
    if (t <= 0.35) {
      final p = t / 0.35; // varie de 1.0 à 0.0
      return 0.22 * 4.0 * p * (1.0 - p);
    } else {
      final u = (t - 0.35) / 0.65; // varie de 0.0 à 1.0
      return u * u;
    }
  }
}
