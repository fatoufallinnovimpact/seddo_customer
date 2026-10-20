import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Helper to generate high-definition custom BitmapDescriptors for Google Maps.
abstract class MapMarkerHelper {
  static BitmapDescriptor? _carMarkerIcon;
  static BitmapDescriptor? _userMarkerIcon;

  /// Generate top-down realistic car marker matching the reference design:
  /// Black sedan body, rounded corners, white/grey windshield and rear window.
  static Future<BitmapDescriptor> getCarMarker() async {
    if (_carMarkerIcon != null) return _carMarkerIcon!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(54, 30);

    // 1. Car Body Shadow
    final shadowPaint = Paint()
      ..color = AppColors.shadowHeavy
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 4, size.width - 6, size.height - 6),
        const Radius.circular(8),
      ),
      shadowPaint,
    );

    // 2. Car Body (Deep Black)
    final bodyPaint = Paint()
      ..color = AppColors.buttonBlack
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
        const Radius.circular(7),
      ),
      bodyPaint,
    );

    // 3. Side Mirrors
    final mirrorPaint = Paint()..color = AppColors.buttonBlack;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.40, 0, 7, 3),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.40, size.height - 3, 7, 3),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );

    // 4. Windshield & Windows (Tinted glass)
    final glassPaint = Paint()
      ..color = AppColors.mapCarWindow
      ..style = PaintingStyle.fill;

    // Front windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.35, 5, 8, size.height - 10),
        const Radius.circular(3),
      ),
      glassPaint,
    );

    // Rear window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.70, 5, 6, size.height - 10),
        const Radius.circular(2),
      ),
      glassPaint,
    );

    // Roof
    final roofPaint = Paint()..color = AppColors.mapCarRoof;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.45, 5, size.width * 0.24, size.height - 10),
        const Radius.circular(2),
      ),
      roofPaint,
    );

    // Headlights (Warm white)
    final lightPaint = Paint()..color = AppColors.mapCarLight;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 4, 3, 5),
        const Radius.circular(1),
      ),
      lightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, size.height - 9, 3, 5),
        const Radius.circular(1),
      ),
      lightPaint,
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    _carMarkerIcon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _carMarkerIcon!;
  }

  /// Generate user location pin (Orange circle with white navigation arrow inside).
  static Future<BitmapDescriptor> getUserLocationMarker() async {
    if (_userMarkerIcon != null) return _userMarkerIcon!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double radius = 20.0;
    const center = Offset(radius, radius);

    // Outer aura
    final auraPaint = Paint()
      ..color = AppColors.primary.withAlpha(50)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, auraPaint);

    // Inner orange circle
    final orangePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 13.0, orangePaint);

    // White border
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, 13.0, borderPaint);

    // White directional arrow / navigation triangle inside
    final arrowPath = Path();
    arrowPath.moveTo(center.dx, center.dy - 7);
    arrowPath.lineTo(center.dx + 5, center.dy + 6);
    arrowPath.lineTo(center.dx, center.dy + 3);
    arrowPath.lineTo(center.dx - 5, center.dy + 6);
    arrowPath.close();

    final arrowPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage((radius * 2).toInt(), (radius * 2).toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    _userMarkerIcon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _userMarkerIcon!;
  }
}
