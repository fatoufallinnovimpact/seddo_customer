import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/ride/presentation/utils/vehicle_color_helper.dart';

/// Dessine une berline vue 100% de profil (comme sur la maquette chauffeur),
/// dont la carrosserie prend dynamiquement la couleur renvoyée par l'API
/// tout en conservant les vitres, les roues, le phare avant et le feu arrière.
class SideProfileCarWidget extends StatelessWidget {
  final String carColor;
  final double width;
  final double height;

  const SideProfileCarWidget({
    super.key,
    required this.carColor,
    this.width = 88,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = VehicleColorHelper.parseColor(
      carColor,
      fallback: AppColors.vehicleDarkGrey,
    );
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SideProfileCarPainter(bodyColor: resolvedColor),
      ),
    );
  }
}

class _SideProfileCarPainter extends CustomPainter {
  final Color bodyColor;

  const _SideProfileCarPainter({required this.bodyColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final isLightBody =
        bodyColor.r > 0.88 && bodyColor.g > 0.88 && bodyColor.b > 0.88;

    // 1. Ombre portée douce sous le châssis
    final shadowPaint = Paint()
      ..color = AppColors.shadowSubtleBlack
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromLTWH(w * 0.06, h * 0.84, w * 0.88, h * 0.12),
      shadowPaint,
    );

    // 2. Silhouette de la carrosserie de profil (berline moderne orientée vers la droite)
    final bodyPath = Path()
      // Bas arrière (gauche)
      ..moveTo(w * 0.08, h * 0.72)
      ..quadraticBezierTo(w * 0.02, h * 0.71, w * 0.02, h * 0.60)
      // Coffre arrière
      ..lineTo(w * 0.03, h * 0.45)
      ..quadraticBezierTo(w * 0.04, h * 0.38, w * 0.13, h * 0.36)
      // Lunette arrière & pavillon (toit)
      ..lineTo(w * 0.27, h * 0.14)
      ..quadraticBezierTo(w * 0.32, h * 0.08, w * 0.42, h * 0.08)
      ..lineTo(w * 0.58, h * 0.08)
      ..quadraticBezierTo(w * 0.66, h * 0.08, w * 0.74, h * 0.20)
      // Pare-brise avant
      ..lineTo(w * 0.82, h * 0.35)
      // Capot avant
      ..quadraticBezierTo(w * 0.94, h * 0.38, w * 0.97, h * 0.48)
      // Pare-chocs avant (droite)
      ..quadraticBezierTo(w * 0.99, h * 0.58, w * 0.98, h * 0.67)
      ..quadraticBezierTo(w * 0.97, h * 0.72, w * 0.91, h * 0.72)
      ..close();

    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(bodyPath, bodyPaint);

    // Contour subtil si la voiture est blanche ou très claire (beige/argent clair)
    if (isLightBody) {
      final borderPaint = Paint()
        ..color = AppColors.grayBorderMedium
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..isAntiAlias = true;
      canvas.drawPath(bodyPath, borderPaint);
    }

    // 3. Vitres latérales (arrière + avant séparées par le montant central)
    final windowPaint = Paint()
      ..color = isLightBody ? AppColors.textLabelGrey : AppColors.vehicleGrey
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Vitre arrière (gauche)
    final rearWindow = Path()
      ..moveTo(w * 0.20, h * 0.35)
      ..lineTo(w * 0.30, h * 0.16)
      ..quadraticBezierTo(w * 0.33, h * 0.13, w * 0.40, h * 0.13)
      ..lineTo(w * 0.47, h * 0.13)
      ..lineTo(w * 0.47, h * 0.35)
      ..close();
    canvas.drawPath(rearWindow, windowPaint);

    // Vitre avant (droite)
    final frontWindow = Path()
      ..moveTo(w * 0.51, h * 0.35)
      ..lineTo(w * 0.51, h * 0.13)
      ..lineTo(w * 0.59, h * 0.13)
      ..quadraticBezierTo(w * 0.65, h * 0.13, w * 0.70, h * 0.21)
      ..lineTo(w * 0.78, h * 0.35)
      ..close();
    canvas.drawPath(frontWindow, windowPaint);

    // 4. Feu arrière (rouge à gauche) et phare avant (ambre/jaune à droite)
    final tailLightPaint = Paint()
      ..color = AppColors.carTaillight
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.025, h * 0.44, w * 0.055, h * 0.08),
        const Radius.circular(2),
      ),
      tailLightPaint,
    );

    final headLightPaint = Paint()
      ..color = AppColors.amberWarning
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.915, h * 0.46, w * 0.06, h * 0.08),
        const Radius.circular(2),
      ),
      headLightPaint,
    );

    // 5. Passages de roues & Roues (arrière et avant)
    final wheelRadius = h * 0.185;
    final rimRadius = wheelRadius * 0.52;
    final wheelY = h * 0.72;
    final rearWheelCenter = Offset(w * 0.24, wheelY);
    final frontWheelCenter = Offset(w * 0.77, wheelY);

    final tirePaint = Paint()
      ..color = AppColors.carWheel
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final rimPaint = Paint()
      ..color = AppColors.carWheelRim
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Roue arrière
    canvas.drawCircle(rearWheelCenter, wheelRadius, tirePaint);
    canvas.drawCircle(rearWheelCenter, rimRadius, rimPaint);

    // Roue avant
    canvas.drawCircle(frontWheelCenter, wheelRadius, tirePaint);
    canvas.drawCircle(frontWheelCenter, rimRadius, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _SideProfileCarPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor;
  }
}
