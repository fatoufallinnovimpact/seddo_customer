import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Carte animée et interactive « Où allons-nous ? »
/// avec petite voiture carr.png, oscillation douce et accélération au toucher.
class OuAllonsNousCard extends StatefulWidget {
  const OuAllonsNousCard({
    super.key,
    this.label = 'Où allons-nous ?',
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  State<OuAllonsNousCard> createState() => _OuAllonsNousCardState();
}

class _OuAllonsNousCardState extends State<OuAllonsNousCard>
    with TickerProviderStateMixin {
  // Ticker unique : oscillation de la voiture et accélération au toucher.
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _bobPhase = 0;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  // Animation « avance puis revient » au toucher.
  late final AnimationController _drive = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final Animation<double> _driveX = TweenSequence<double>([
    TweenSequenceItem(
      tween:
          Tween(begin: 0.0, end: 14.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 14.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 55,
    ),
  ]).animate(_drive);

  bool _reduceMotion = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    _ticker = createTicker(_onTick);
    if (!isTest) {
      _ticker.start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final reduce = MediaQuery.of(context).disableAnimations || isTest;
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      if (reduce) {
        _ticker.stop();
        _drive.stop();
      } else if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    _bobPhase += dt;
    _repaint.value++;
  }

  void _handleTap() {
    if (!_reduceMotion) _drive.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _drive.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const carWidth = 62.0;
    const carHeight = carWidth * 171 / 421;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: Container(
        height: 52,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.serviceCardBg,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowFaintBlack,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Petite voiture carr.png avec oscillation douce
            Positioned(
              left: -6,
              bottom: 5,
              width: carWidth,
              height: carHeight,
              child: AnimatedBuilder(
                animation: Listenable.merge([_repaint, _drive]),
                builder: (context, child) {
                  final bob = -0.8 *
                      (0.5 - 0.5 * math.cos(2 * math.pi * _bobPhase / 0.9));
                  final dx = _reduceMotion ? 0.0 : _driveX.value;
                  return Transform.translate(
                    offset: Offset(dx, _reduceMotion ? 0 : bob),
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/images/carr.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomLeft,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.directions_car_rounded,
                    size: 24,
                    color: AppColors.nearBlack,
                  ),
                ),
              ),
            ),

            // Texte centré horizontalement
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.nearBlack,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),

            // Bouton chevron circulaire à droite
            Positioned(
              right: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  offset: Offset(_pressed ? 0.1 : 0, 0),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.nearBlack,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
