import 'package:flutter/material.dart';

/// Animated Onboarding Car Widget using the exact artwork from the reference design.
/// - Animates the photorealistic orange sedan with realistic drive-in,
///   deceleration, braking suspension tilt, and settling into its parking spot.
class AnimatedParkingCarWidget extends StatefulWidget {
  final double? driveOffset;

  const AnimatedParkingCarWidget({
    super.key,
    this.driveOffset,
  });

  @override
  State<AnimatedParkingCarWidget> createState() =>
      AnimatedParkingCarWidgetState();
}

class AnimatedParkingCarWidgetState extends State<AnimatedParkingCarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _driveAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _suspensionAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    final double offset = widget.driveOffset ?? 100.0;

    // 1. Horizontal drive-in (moves from right to exact parking spot 0px)
    _driveAnimation = Tween<double>(begin: offset, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.82, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Perspective scale (starts slightly smaller in the distance 0.93 -> 1.0)
    _scaleAnimation = Tween<double>(begin: 0.93, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.82, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Braking suspension tilt: subtle nose dip (-0.02 rad) as brakes apply, then gentle settle
    _suspensionAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.0),
        weight: 60,
      ),
      // Gentle forward pitch on brake engagement
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.02)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 18,
      ),
      // Suspension rebound
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.02, end: 0.005)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 12,
      ),
      // Settle at rest
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.005, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
    ]).animate(_controller);

    // Start parking animation after a brief organic delay
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void replay() {
    if (!_controller.isAnimating) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: replay,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double dx = _driveAnimation.value;
          final double scale = _scaleAnimation.value;
          final double tilt = _suspensionAnimation.value;

          return Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomRight,
              child: Transform.rotate(
                angle: tilt,
                alignment: const Alignment(-0.2, 0.8),
                child: Image.asset(
                  'assets/images/seddo_car.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
