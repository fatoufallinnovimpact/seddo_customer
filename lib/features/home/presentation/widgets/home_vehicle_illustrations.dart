import 'package:flutter/material.dart';

/// Clean vector illustrations for Seddo vehicle cards matching reference screenshots:
/// - Sleek car silhouette for Seddo Eco (white body) and Seddo Confort (orange body)
/// - Modern transit bus silhouette for TCU card (white & blue with windows)
class SeddoCarVectorGraphic extends StatelessWidget {
  final Color bodyColor;
  final Color windowColor;
  final double width;
  final double height;

  const SeddoCarVectorGraphic({
    super.key,
    required this.bodyColor,
    required this.windowColor,
    this.width = 170,
    this.height = 70,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SeddoCarPainter(
        bodyColor: bodyColor,
        windowColor: windowColor,
      ),
    );
  }
}

class _SeddoCarPainter extends CustomPainter {
  final Color bodyColor;
  final Color windowColor;

  const _SeddoCarPainter({
    required this.bodyColor,
    required this.windowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 170.0;
    final scaleY = size.height / 70.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    // 1. Sleek Car Body Path
    final bodyPath = Path();
    bodyPath.moveTo(8, 48);
    // Rear bumper & hatch
    bodyPath.quadraticBezierTo(2, 44, 4, 36);
    bodyPath.quadraticBezierTo(6, 28, 16, 26);
    // Sloped rear window & roof
    bodyPath.quadraticBezierTo(26, 22, 48, 12);
    bodyPath.lineTo(104, 12); // Flat roof
    // Windshield slope
    bodyPath.quadraticBezierTo(118, 18, 130, 26);
    // Hood
    bodyPath.lineTo(152, 30);
    // Front nose & bumper
    bodyPath.quadraticBezierTo(168, 36, 168, 44);
    bodyPath.quadraticBezierTo(166, 48, 156, 50);

    // Front wheel cutout
    bodyPath.lineTo(146, 50);
    bodyPath.arcToPoint(
      const Offset(118, 50),
      radius: const Radius.circular(15.5),
      clockwise: false,
    );

    // Mid underbody sill
    bodyPath.lineTo(60, 50);

    // Rear wheel cutout
    bodyPath.arcToPoint(
      const Offset(32, 50),
      radius: const Radius.circular(15.5),
      clockwise: false,
    );

    // Rear sill
    bodyPath.lineTo(8, 50);
    bodyPath.close();

    canvas.drawPath(bodyPath, bodyPaint);

    // 2. Windows
    final windowPaint = Paint()
      ..color = windowColor
      ..style = PaintingStyle.fill;

    // Rear side window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 16, 38, 10.5),
        const Radius.circular(2.5),
      ),
      windowPaint,
    );

    // Front side window (angled)
    final frontWindow = Path();
    frontWindow.moveTo(76, 16);
    frontWindow.lineTo(102, 16);
    frontWindow.lineTo(122, 26);
    frontWindow.lineTo(76, 26);
    frontWindow.close();
    canvas.drawPath(frontWindow, windowPaint);

    // 3. Wheels (Black tires + dark center hubs)
    final tirePaint = Paint()
      ..color = const Color(0xFF18181A)
      ..style = PaintingStyle.fill;

    final rimPaint = Paint()
      ..color = const Color(0xFF2C2C30)
      ..style = PaintingStyle.fill;

    // Rear wheel
    const rearCenter = Offset(46, 51);
    canvas.drawCircle(rearCenter, 12, tirePaint);
    canvas.drawCircle(rearCenter, 5.5, rimPaint);

    // Front wheel
    const frontCenter = Offset(132, 51);
    canvas.drawCircle(frontCenter, 12, tirePaint);
    canvas.drawCircle(frontCenter, 5.5, rimPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SeddoCarPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.windowColor != windowColor;
}

class SeddoBusVectorGraphic extends StatelessWidget {
  final double width;
  final double height;

  const SeddoBusVectorGraphic({
    super.key,
    this.width = 175,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: const _SeddoBusPainter(),
    );
  }
}

class _SeddoBusPainter extends CustomPainter {
  const _SeddoBusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 175.0;
    final scaleY = size.height / 72.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // 1. Main White Bus Body
    final bodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final bodyPath = Path();
    bodyPath.moveTo(10, 48);
    // Rear of bus
    bodyPath.lineTo(8, 20);
    bodyPath.quadraticBezierTo(8, 12, 18, 12);
    // Roof
    bodyPath.lineTo(152, 12);
    // Front windshield curve
    bodyPath.quadraticBezierTo(168, 12, 170, 26);
    bodyPath.lineTo(170, 44);
    bodyPath.quadraticBezierTo(168, 48, 160, 48);

    // Front wheel cutout
    bodyPath.lineTo(154, 48);
    bodyPath.arcToPoint(
      const Offset(126, 48),
      radius: const Radius.circular(15.5),
      clockwise: false,
    );

    // Mid sill
    bodyPath.lineTo(62, 48);

    // Rear wheel cutout
    bodyPath.arcToPoint(
      const Offset(34, 48),
      radius: const Radius.circular(15.5),
      clockwise: false,
    );

    // Rear bottom
    bodyPath.lineTo(10, 48);
    bodyPath.close();

    canvas.drawPath(bodyPath, bodyPaint);

    // 2. Horizontal Blue Bottom Accent Stripe
    final stripePaint = Paint()
      ..color = const Color(0xFF274C9E)
      ..style = PaintingStyle.fill;

    final stripePath = Path();
    stripePath.moveTo(8, 42);
    stripePath.lineTo(34, 42);
    stripePath.arcToPoint(
      const Offset(62, 42),
      radius: const Radius.circular(15.5),
      clockwise: true,
    );
    stripePath.lineTo(126, 42);
    stripePath.arcToPoint(
      const Offset(154, 42),
      radius: const Radius.circular(15.5),
      clockwise: true,
    );
    stripePath.lineTo(170, 42);
    stripePath.lineTo(170, 46);
    stripePath.lineTo(156, 46);
    stripePath.arcToPoint(
      const Offset(124, 46),
      radius: const Radius.circular(17.5),
      clockwise: false,
    );
    stripePath.lineTo(64, 46);
    stripePath.arcToPoint(
      const Offset(32, 46),
      radius: const Radius.circular(17.5),
      clockwise: false,
    );
    stripePath.lineTo(8, 46);
    stripePath.close();
    canvas.drawPath(stripePath, stripePaint);

    // 3. Windows (Soft lavender/light blue tint)
    final windowPaint = Paint()
      ..color = const Color(0xFFC7D7FA)
      ..style = PaintingStyle.fill;

    // 3 Passenger windows
    for (int i = 0; i < 3; i++) {
      final left = 20.0 + i * 26.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 18, 20, 16),
          const Radius.circular(5.5),
        ),
        windowPaint,
      );
    }

    // Panoramic Front Windshield Window
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(102, 18, 48, 16),
        topLeft: const Radius.circular(5.5),
        bottomLeft: const Radius.circular(5.5),
        topRight: const Radius.circular(11.0),
        bottomRight: const Radius.circular(5.5),
      ),
      windowPaint,
    );

    // 4. Wheels
    final tirePaint = Paint()
      ..color = const Color(0xFF18181A)
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = const Color(0xFF2C2C30)
      ..style = PaintingStyle.fill;

    // Rear wheel
    const rearCenter = Offset(48, 49);
    canvas.drawCircle(rearCenter, 12, tirePaint);
    canvas.drawCircle(rearCenter, 5.5, rimPaint);

    // Front wheel
    const frontCenter = Offset(140, 49);
    canvas.drawCircle(frontCenter, 12, tirePaint);
    canvas.drawCircle(frontCenter, 5.5, rimPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SeddoBusPainter oldDelegate) => false;
}
