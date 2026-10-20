import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

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

  static BitmapDescriptor? _destSquareIcon;

  /// Generate destination anchor marker (Orange square with crisp white border matching design)
  static Future<BitmapDescriptor> getDestinationSquareMarker() async {
    if (_destSquareIcon != null) return _destSquareIcon!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double size = 26.0;

    // Outer drop shadow
    final shadowPaint = Paint()
      ..color = AppColors.shadowPinBox
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 18, 18),
        const Radius.circular(AppConstants.radiusXs),
      ),
      shadowPaint,
    );

    // Orange square center
    final orangePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 18, 18),
        const Radius.circular(AppConstants.radiusXs),
      ),
      orangePaint,
    );

    // Crisp white border
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 18, 18),
        const Radius.circular(AppConstants.radiusXs),
      ),
      borderPaint,
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    _destSquareIcon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _destSquareIcon!;
  }

  /// Generate pickup badge marker matching screenshot:
  /// Black circle dot on road + floating pill badge "• Prise en charge · 4 min"
  static Future<BitmapDescriptor> getPickupBadgeMarker({
    String label = 'Prise en charge · 4 min',
    Color dotColor = AppColors.primary,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    const double pillHeight = 28.0;
    const double pillWidth = 168.0;
    const double dotRadius = 5.0;
    const double totalHeight = 50.0;
    const double totalWidth = pillWidth;

    // 1. Draw floating black pill
    final pillPaint = Paint()
      ..color = AppColors.buttonBlack
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, pillWidth, pillHeight),
        const Radius.circular(14),
      ),
      pillPaint,
    );

    // Colored dot inside pill
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(14, pillHeight / 2), 3.5, dotPaint);

    // Label text
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(24, (pillHeight - textPainter.height) / 2),
    );

    // 2. Draw black pickup dot with white border at bottom center
    const dotCenter = Offset(pillWidth / 2, totalHeight - dotRadius - 2);
    final dotOuterPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotCenter, dotRadius + 2.0, dotOuterPaint);

    final dotInnerPaint = Paint()
      ..color = AppColors.buttonBlack
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotCenter, dotRadius, dotInnerPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }
}
