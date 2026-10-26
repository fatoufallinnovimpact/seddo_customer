import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Pristine, razor-sharp vector location pin widget for the Seddo onboarding scene.
/// Renders at native device DPI with vibrant brand orange gradient, crisp white outline,
/// inner beacon core, grounded contact shadow, and an organic drop-and-settle entrance animation.
class OnboardingLocationPinWidget extends StatefulWidget {
  final double width;
  final double height;

  const OnboardingLocationPinWidget({
    super.key,
    this.width = 50.0,
    this.height = 70.0,
  });

  @override
  State<OnboardingLocationPinWidget> createState() =>
      _OnboardingLocationPinWidgetState();
}

class _OnboardingLocationPinWidgetState
    extends State<OnboardingLocationPinWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _dropAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _dropAnimation = Tween<double>(begin: -16.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    Future.delayed(const Duration(milliseconds: 120), () {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _LocationPinPainter(
            offsetY: _dropAnimation.value,
            scale: _scaleAnimation.value,
          ),
        );
      },
    );
  }
}

class _LocationPinPainter extends CustomPainter {
  final double offsetY;
  final double scale;

  const _LocationPinPainter({
    required this.offsetY,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2.0;

    final double bulbRadius = w * 0.44;
    final double bulbCenterY = bulbRadius + 3.0;
    final double tipY = h - 6.0;

    // 1. Soft realistic contact shadow under the pin tip
    final double shadowScale = scale.clamp(0.5, 1.1);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, tipY + 2.5),
        width: 18.0 * shadowScale,
        height: 5.0 * shadowScale,
      ),
      shadowPaint,
    );

    // 2. Animated drop pin body
    canvas.save();
    canvas.translate(0, offsetY);

    // Compute exact tangent lines from tip to bulb circle
    final double dy = tipY - bulbCenterY;
    final double alpha = math.asin((bulbRadius / dy).clamp(-1.0, 1.0));
    final double leftX = cx - bulbRadius * math.cos(alpha);
    final double leftY = bulbCenterY + bulbRadius * math.sin(alpha);
    final double rightX = cx + bulbRadius * math.cos(alpha);
    final double rightY = leftY;

    final pinPath = Path()
      ..moveTo(cx, tipY)
      ..lineTo(leftX, leftY)
      ..arcToPoint(
        Offset(rightX, rightY),
        radius: Radius.circular(bulbRadius),
        clockwise: true,
        largeArc: true,
      )
      ..close();

    // 3. Subtle, clean ambient drop shadow behind pin
    final ambientDropShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(pinPath.shift(const Offset(0, 2.0)), ambientDropShadow);

    // 4. Vibrant Seddo Orange Gradient Body
    final pinGradient = ui.Gradient.linear(
      Offset(cx - bulbRadius, bulbCenterY - bulbRadius),
      Offset(cx + bulbRadius, tipY),
      const [
        Color(0xFFFF7E1D), // Vivid bright orange top
        AppColors.primary, // Seddo Brand Orange #FB5B00
        Color(0xFFD64800), // Deep rich orange at tip
      ],
      const [0.0, 0.55, 1.0],
    );
    final bodyPaint = Paint()
      ..shader = pinGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, bodyPaint);

    // 5. Crisp Outer White Border for razor-sharp definition against skyline
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(pinPath, borderPaint);

    // 6. Pristine White Inner Core Circle
    final coreCenter = Offset(cx, bulbCenterY);
    final double coreRadius = bulbRadius * 0.46;
    final corePaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(coreCenter, coreRadius, corePaint);

    // 7. Inner Brand Orange Beacon Dot
    final innerDotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(coreCenter, coreRadius * 0.50, innerDotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LocationPinPainter oldDelegate) {
    return oldDelegate.offsetY != offsetY || oldDelegate.scale != scale;
  }
}
