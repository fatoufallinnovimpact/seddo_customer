import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Pixel-perfect vector side-profile car icon matching the reference design:
/// Used in Suggestions for Seddo Eco (black body) and Confort (orange body).
class SuggestionCarIcon extends StatelessWidget {
  final Color bodyColor;
  final double width;
  final double height;

  const SuggestionCarIcon({
    super.key,
    required this.bodyColor,
    this.width = 44,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _CarIconPainter(bodyColor: bodyColor),
    );
  }
}

class _CarIconPainter extends CustomPainter {
  final Color bodyColor;

  _CarIconPainter({required this.bodyColor});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 44.0;
    final scaleY = size.height / 24.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bodyPath = Path();
    // Front bumper
    bodyPath.moveTo(2, 16);
    bodyPath.lineTo(2, 14);
    bodyPath.quadraticBezierTo(2, 12, 5, 11);
    // Hood
    bodyPath.quadraticBezierTo(9, 10.5, 14, 10);
    // Windshield slope
    bodyPath.quadraticBezierTo(18, 4.5, 20, 4);
    // Roof
    bodyPath.lineTo(28, 4);
    // Rear window slope
    bodyPath.quadraticBezierTo(33, 5, 36, 11);
    // Trunk
    bodyPath.quadraticBezierTo(40, 11.5, 42, 13);
    // Rear bumper
    bodyPath.lineTo(42, 16);
    bodyPath.lineTo(38, 16);
    // Rear wheel arch cutout
    bodyPath.arcToPoint(
      const Offset(28, 16),
      radius: const Radius.circular(5),
      clockwise: true,
    );
    // Bottom side skirt
    bodyPath.lineTo(16, 16);
    // Front wheel arch cutout
    bodyPath.arcToPoint(
      const Offset(6, 16),
      radius: const Radius.circular(5),
      clockwise: true,
    );
    bodyPath.lineTo(2, 16);
    bodyPath.close();

    canvas.drawPath(bodyPath, bodyPaint);

    // Windows cutout / tint
    final windowPaint = Paint()
      ..color = AppColors.surfaceGrey
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Front & rear side windows
    final frontWindow = Path()
      ..moveTo(20, 5.5)
      ..lineTo(25.5, 5.5)
      ..lineTo(25.5, 9.8)
      ..lineTo(16, 9.8)
      ..close();
    canvas.drawPath(frontWindow, windowPaint);

    final rearWindow = Path()
      ..moveTo(27, 5.5)
      ..lineTo(30, 5.5)
      ..quadraticBezierTo(33, 6.5, 35, 9.8)
      ..lineTo(27, 9.8)
      ..close();
    canvas.drawPath(rearWindow, windowPaint);

    // Wheels
    final wheelPaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final rimPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Front wheel at (11, 16)
    canvas.drawCircle(const Offset(11, 16), 4.2, wheelPaint);
    canvas.drawCircle(const Offset(11, 16), 1.8, rimPaint);

    // Rear wheel at (33, 16)
    canvas.drawCircle(const Offset(33, 16), 4.2, wheelPaint);
    canvas.drawCircle(const Offset(33, 16), 1.8, rimPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarIconPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor;
}
