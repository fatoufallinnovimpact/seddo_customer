import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Helper to generate high-definition custom BitmapDescriptors for Google Maps.
/// Generates 3D isometric car markers, modern teardrop location pins for departure and arrival.
abstract class MapMarkerHelper {
  static BitmapDescriptor? _carMarkerIcon;
  static BitmapDescriptor? _userMarkerIcon;
  static BitmapDescriptor? _departurePinIcon;
  static BitmapDescriptor? _destinationPinIcon;

  /// Generate high-fidelity 3D isometric car marker for GPS map navigation:
  /// Realistic 3D perspective, sleek dark metallic finish with Seddo orange accents,
  /// 3D angled roof & tinted windshield, LED headlights, chrome alloy wheels, and soft ground shadow.
  static Future<BitmapDescriptor> get3DCarMarker() async {
    if (_carMarkerIcon != null) return _carMarkerIcon!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(64, 64);

    // 1. Realistic ground shadow (offset diagonal blurred ellipse)
    final shadowPaint = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(
      const Rect.fromLTWH(8, 38, 48, 18),
      shadowPaint,
    );

    // 2. 4 3D Wheels with chrome rims
    final tirePaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = const Color(0xFFC0C0C0)
      ..style = PaintingStyle.fill;

    // Front-left wheel
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(11, 24, 7, 14), const Radius.circular(3)),
      tirePaint,
    );
    canvas.drawCircle(const Offset(14.5, 31), 2.5, rimPaint);

    // Front-right wheel
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(46, 24, 7, 14), const Radius.circular(3)),
      tirePaint,
    );
    canvas.drawCircle(const Offset(49.5, 31), 2.5, rimPaint);

    // Rear-left wheel
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(13, 40, 7, 14), const Radius.circular(3)),
      tirePaint,
    );
    canvas.drawCircle(const Offset(16.5, 47), 2.5, rimPaint);

    // Rear-right wheel
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(44, 40, 7, 14), const Radius.circular(3)),
      tirePaint,
    );
    canvas.drawCircle(const Offset(47.5, 47), 2.5, rimPaint);

    // 3. Lower 3D Chassis / Body (Deep metallic black gradient)
    final bodyPath = Path();
    bodyPath.moveTo(22, 12); // Hood front left
    bodyPath.lineTo(42, 12); // Hood front right
    bodyPath.lineTo(51, 22); // Front right fender
    bodyPath.lineTo(52, 44); // Rear right fender
    bodyPath.lineTo(44, 53); // Rear right bumper
    bodyPath.lineTo(20, 53); // Rear left bumper
    bodyPath.lineTo(12, 44); // Rear left fender
    bodyPath.lineTo(13, 22); // Front left fender
    bodyPath.close();

    final bodyGradient = ui.Gradient.linear(
      const Offset(32, 12),
      const Offset(32, 53),
      [
        const Color(0xFF3A3A3C),
        const Color(0xFF1C1C1E),
        const Color(0xFF0D0D0E),
      ],
      [0.0, 0.5, 1.0],
    );
    final bodyPaint = Paint()
      ..shader = bodyGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, bodyPaint);

    // 4. Seddo Orange Racing / Roof Accent Stripe
    final stripePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(30, 13, 4, 38), const Radius.circular(2)),
      stripePaint,
    );

    // 5. 3D Hood contour & Front Grille
    final grillePaint = Paint()..color = const Color(0xFF111111);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(24, 13, 16, 4), const Radius.circular(2)),
      grillePaint,
    );

    // LED Headlights
    final headlightPaint = Paint()..color = const Color(0xFFFFF9D2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18, 14, 5, 3), const Radius.circular(1.5)),
      headlightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(41, 14, 5, 3), const Radius.circular(1.5)),
      headlightPaint,
    );

    // 6. 3D Cabin & Windshield (Glossy glass with reflection)
    final cabinPath = Path();
    cabinPath.moveTo(21, 23); // Windshield bottom-left
    cabinPath.lineTo(43, 23); // Windshield bottom-right
    cabinPath.lineTo(40, 42); // Rear window top-right
    cabinPath.lineTo(24, 42); // Rear window top-left
    cabinPath.close();

    final glassGradient = ui.Gradient.linear(
      const Offset(21, 23),
      const Offset(43, 42),
      [
        const Color(0xFF64D2FF).withAlpha(200),
        const Color(0xFF0A2E4C).withAlpha(220),
        const Color(0xFF1E293B),
      ],
      [0.0, 0.5, 1.0],
    );
    final glassPaint = Paint()
      ..shader = glassGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(cabinPath, glassPaint);

    // 7. 3D Roof (Elevated platform above glass)
    final roofPaint = Paint()
      ..color = const Color(0xFF2C2C2E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(25, 27, 14, 11), const Radius.circular(2.5)),
      roofPaint,
    );

    // Sunroof / Roof highlight
    final roofTopPaint = Paint()..color = AppColors.primary.withAlpha(220);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(27, 28, 10, 5), const Radius.circular(1.5)),
      roofTopPaint,
    );

    // 8. 3D Side Mirrors
    final mirrorPaint = Paint()..color = const Color(0xFF2C2C2E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(12, 24, 5, 3), const Radius.circular(1.5)),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(47, 24, 5, 3), const Radius.circular(1.5)),
      mirrorPaint,
    );

    // 9. Rear Taillights (Glossy red LEDs)
    final tailPaint = Paint()..color = const Color(0xFFFF3B30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(19, 51, 6, 2.5), const Radius.circular(1)),
      tailPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(39, 51, 6, 2.5), const Radius.circular(1)),
      tailPaint,
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    _carMarkerIcon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _carMarkerIcon!;
  }

  /// Alias for get3DCarMarker for seamless backward compatibility
  static Future<BitmapDescriptor> getCarMarker() => get3DCarMarker();

  /// Generate modern Departure Location Pin marker:
  /// Vibrant Seddo Orange teardrop location pin with soft shadow, white ring and central dot.
  /// Anchor at (0.5, 1.0) so the pin tip points directly at the departure point.
  static Future<BitmapDescriptor> getDeparturePinMarker() async {
    if (_departurePinIcon != null) return _departurePinIcon!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double width = 44.0;
    const double height = 54.0;

    // 1. Soft ground shadow under pin point
    final shadowPaint = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      const Rect.fromLTWH(14, height - 7, 16, 6),
      shadowPaint,
    );

    // 2. Teardrop Location Pin Path
    final pinPath = Path();
    pinPath.moveTo(width / 2, height - 4); // Pin bottom tip
    pinPath.cubicTo(
      width * 0.16,
      height * 0.65,
      width * 0.04,
      height * 0.45,
      width * 0.04,
      height * 0.32,
    );
    pinPath.arcToPoint(
      Offset(width * 0.96, height * 0.32),
      radius: const Radius.circular(width * 0.46),
      clockwise: true,
    );
    pinPath.cubicTo(
      width * 0.96,
      height * 0.45,
      width * 0.84,
      height * 0.65,
      width / 2,
      height - 4,
    );
    pinPath.close();

    // 3. Pin Body Gradient (Primary Orange -> Deep Orange)
    final pinGradient = ui.Gradient.linear(
      const Offset(width / 2, 0),
      Offset(width / 2, height),
      [
        const Color(0xFFFF9500),
        AppColors.primary,
        const Color(0xFFD64400),
      ],
      [0.0, 0.5, 1.0],
    );
    final pinPaint = Paint()
      ..shader = pinGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // White outer border for crisp definition on map
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(pinPath, borderPaint);

    // 4. White Center Circle
    final centerOffset = Offset(width / 2, height * 0.33);
    final whiteCenterPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerOffset, 7.5, whiteCenterPaint);

    // 5. Inner Orange Location Dot
    final innerDotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerOffset, 4.0, innerDotPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    _departurePinIcon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _departurePinIcon!;
  }

  /// Generate modern Destination / Arrival Location Pin marker:
  /// Sleek Deep Black teardrop location pin with white circle and target / arrival dot.
  /// Anchor at (0.5, 1.0) so the pin tip points directly at destination point.
  static Future<BitmapDescriptor> getDestinationPinMarker() async {
    if (_destinationPinIcon != null) return _destinationPinIcon!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double width = 44.0;
    const double height = 54.0;

    // 1. Soft ground shadow under pin point
    final shadowPaint = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      const Rect.fromLTWH(14, height - 7, 16, 6),
      shadowPaint,
    );

    // 2. Teardrop Location Pin Path
    final pinPath = Path();
    pinPath.moveTo(width / 2, height - 4); // Pin bottom tip
    pinPath.cubicTo(
      width * 0.16,
      height * 0.65,
      width * 0.04,
      height * 0.45,
      width * 0.04,
      height * 0.32,
    );
    pinPath.arcToPoint(
      Offset(width * 0.96, height * 0.32),
      radius: const Radius.circular(width * 0.46),
      clockwise: true,
    );
    pinPath.cubicTo(
      width * 0.96,
      height * 0.45,
      width * 0.84,
      height * 0.65,
      width / 2,
      height - 4,
    );
    pinPath.close();

    // 3. Pin Body Gradient (Executive Black)
    final pinGradient = ui.Gradient.linear(
      const Offset(width / 2, 0),
      Offset(width / 2, height),
      [
        const Color(0xFF333333),
        AppColors.buttonBlack,
        const Color(0xFF000000),
      ],
      [0.0, 0.5, 1.0],
    );
    final pinPaint = Paint()
      ..shader = pinGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // White outer border for crisp definition on map
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(pinPath, borderPaint);

    // 4. White Center Circle
    final centerOffset = Offset(width / 2, height * 0.33);
    final whiteCenterPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerOffset, 7.5, whiteCenterPaint);

    // 5. Inner Black Arrival Dot
    final innerDotPaint = Paint()
      ..color = AppColors.buttonBlack
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerOffset, 4.0, innerDotPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    _destinationPinIcon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _destinationPinIcon!;
  }

  /// Backward-compatible alias for destination pin marker (replaces previous orange square)
  static Future<BitmapDescriptor> getDestinationSquareMarker() => getDestinationPinMarker();

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

  /// Generate pickup badge marker:
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
