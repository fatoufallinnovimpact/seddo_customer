import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Helper to generate high-definition custom BitmapDescriptors for Google Maps.
/// Generates user-specified sports car markers, modern teardrop location pins for departure and arrival.
abstract class MapMarkerHelper {
  static BitmapDescriptor? _carMarkerIcon;
  static BitmapDescriptor? _userMarkerIcon;
  static BitmapDescriptor? _departurePinIcon;
  static BitmapDescriptor? _destinationPinIcon;
  static BitmapDescriptor? _ecoCarMarkerIcon;
  static BitmapDescriptor? _confortCarMarkerIcon;
  static BitmapDescriptor? _userHaloMarkerIcon;
  static final Map<String, BitmapDescriptor> _transitMarkerIcons = {};

  /// Clear in-memory cached marker icons to force reload on hot restart or asset updates.
  static void clearCache() {
    _carMarkerIcon = null;
    _userMarkerIcon = null;
    _departurePinIcon = null;
    _destinationPinIcon = null;
    _ecoCarMarkerIcon = null;
    _confortCarMarkerIcon = null;
    _userHaloMarkerIcon = null;
    _transitMarkerIcons.clear();
  }

  static final Map<int, BitmapDescriptor> _coloredCarMarkerCache = {};

  /// Default car marker on the map using assets/images/car.png (white top-down car).
  /// If [color] is provided and not white, dynamically tints the white chassis of
  /// `assets/images/car.png` using canvas modulation while preserving transparent background and details.
  static Future<BitmapDescriptor> get3DCarMarker({Color? color}) async {
    final isWhiteOrDefault = color == null ||
        (color.r > 0.94 && color.g > 0.94 && color.b > 0.94);

    // 1. White or default: directly load and return the pristine white car asset
    if (isWhiteOrDefault) {
      if (_carMarkerIcon != null) return _carMarkerIcon!;

      try {
        final byteData = await rootBundle.load('assets/images/car.png');
        _carMarkerIcon = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
        return _carMarkerIcon!;
      } catch (_) {
        try {
          final byteData =
              await rootBundle.load('assets/images/confort_car_marker.png');
          _carMarkerIcon = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
          return _carMarkerIcon!;
        } catch (_) {
          // Fallback for headless tests without asset bundle
        }
      }

      _carMarkerIcon = await _generateCanvasCarMarker(null);
      return _carMarkerIcon!;
    }

    // 2. Specific color (e.g., Red, Blue, Grey, Black):
    // Dynamically tint the default white car asset (assets/images/car.png)
    final key = color.toARGB32();
    if (_coloredCarMarkerCache.containsKey(key)) {
      return _coloredCarMarkerCache[key]!;
    }

    try {
      final byteData = await rootBundle.load('assets/images/car.png');
      final codec =
          await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(color, BlendMode.modulate);

      canvas.drawImage(image, Offset.zero, paint);
      final picture = pictureRecorder.endRecording();
      final tintedImage = await picture.toImage(image.width, image.height);
      final outByteData =
          await tintedImage.toByteData(format: ui.ImageByteFormat.png);

      if (outByteData != null) {
        final marker =
            BitmapDescriptor.bytes(outByteData.buffer.asUint8List());
        _coloredCarMarkerCache[key] = marker;
        return marker;
      }
    } catch (_) {
      // Fallback for headless tests without asset bundle
    }

    final fallback = await _generateCanvasCarMarker(color);
    _coloredCarMarkerCache[key] = fallback;
    return fallback;
  }

  static Future<BitmapDescriptor> _generateCanvasCarMarker(Color? color) async {

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(26, 32);
    canvas.scale(26.0 / 64.0, 32.0 / 64.0);

    // 1. Realistic ground shadow (offset diagonal blurred ellipse)
    final shadowPaint = Paint()
      ..color = AppColors.shadowCarCanvas
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(
      const Rect.fromLTWH(8, 38, 48, 18),
      shadowPaint,
    );

    // 2. 4 3D Wheels with chrome rims
    final tirePaint = Paint()
      ..color = AppColors.darkMarker
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = AppColors.silverMarker
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

    final Color startColor = color != null
        ? color.withAlpha(240)
        : AppColors.carRoofGradientStart;
    final Color midColor = color ?? AppColors.carRoofGradientMid;
    final Color endColor = color != null
        ? Color.lerp(color, Colors.black, 0.35)!
        : AppColors.carRoofGradientEnd;

    final bodyGradient = ui.Gradient.linear(
      const Offset(32, 12),
      const Offset(32, 53),
      [
        startColor,
        midColor,
        endColor,
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
    final grillePaint = Paint()..color = AppColors.carGrilleDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(24, 13, 16, 4), const Radius.circular(2)),
      grillePaint,
    );

    // LED Headlights
    final headlightPaint = Paint()..color = AppColors.headlightMarker;
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
        AppColors.windshieldBlueStart.withAlpha(200),
        AppColors.windshieldBlueMid.withAlpha(220),
        AppColors.licensePlateBg,
      ],
      [0.0, 0.5, 1.0],
    );
    final glassPaint = Paint()
      ..shader = glassGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(cabinPath, glassPaint);

    // 7. 3D Roof (Elevated platform above glass)
    final roofPaint = Paint()
      ..color = AppColors.darkMirror
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
    final mirrorPaint = Paint()..color = AppColors.darkMirror;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(12, 24, 5, 3), const Radius.circular(1.5)),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(47, 24, 5, 3), const Radius.circular(1.5)),
      mirrorPaint,
    );

    // 9. Rear Taillights (Glossy red LEDs)
    final tailPaint = Paint()..color = AppColors.taillightMarker;
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

  /// Generate modern Departure Location Pin marker (compact Yango-style):
  /// Vibrant Seddo Orange teardrop location pin with soft shadow, white ring and central dot.
  /// Anchor at (0.5, 1.0) so the pin tip points directly at the departure point.
  static Future<BitmapDescriptor> getDeparturePinMarker() async {
    if (_departurePinIcon != null) return _departurePinIcon!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double width = 24.0;
    const double height = 30.0;

    // 1. Soft ground shadow under pin point
    final shadowPaint = Paint()
      ..color = AppColors.shadowCanvasMedium
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawOval(
      const Rect.fromLTWH(8, height - 3.5, 8, 3.0),
      shadowPaint,
    );

    // 2. Teardrop Location Pin Path
    final pinPath = Path();
    pinPath.moveTo(width / 2, height - 2.5); // Pin bottom tip
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
      height - 2.5,
    );
    pinPath.close();

    // 3. Pin Body Gradient (Primary Orange -> Deep Orange)
    final pinGradient = ui.Gradient.linear(
      const Offset(width / 2, 0),
      Offset(width / 2, height),
      [
        AppColors.amberRating,
        AppColors.primary,
        AppColors.orangeDarkPin,
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
      ..strokeWidth = 1.4;
    canvas.drawPath(pinPath, borderPaint);

    // 4. White Center Circle
    final centerOffset = Offset(width / 2, height * 0.33);
    final whiteCenterPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerOffset, 4.2, whiteCenterPaint);

    // 5. Inner Orange Location Dot
    final innerDotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerOffset, 2.2, innerDotPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    _departurePinIcon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _departurePinIcon!;
  }

  /// Generate modern Destination / Arrival Location Pin marker (compact Yango-style):
  /// Sleek Deep Black teardrop location pin with white circle and target / arrival dot.
  /// Anchor at (0.5, 1.0) so the pin tip points directly at destination point.
  static Future<BitmapDescriptor> getDestinationPinMarker() async {
    if (_destinationPinIcon != null) return _destinationPinIcon!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double width = 24.0;
    const double height = 30.0;

    // 1. Soft ground shadow under pin point
    final shadowPaint = Paint()
      ..color = AppColors.shadowCanvasMedium
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawOval(
      const Rect.fromLTWH(8, height - 3.5, 8, 3.0),
      shadowPaint,
    );

    // 2. Teardrop Location Pin Path
    final pinPath = Path();
    pinPath.moveTo(width / 2, height - 2.5); // Pin bottom tip
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
      height - 2.5,
    );
    pinPath.close();

    // 3. Pin Body Gradient (Executive Black)
    final pinGradient = ui.Gradient.linear(
      const Offset(width / 2, 0),
      Offset(width / 2, height),
      [
        AppColors.pinDarkGradientStart,
        AppColors.buttonBlack,
        AppColors.pureBlack,
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
      ..strokeWidth = 1.4;
    canvas.drawPath(pinPath, borderPaint);

    // 4. White Center Circle
    final centerOffset = Offset(width / 2, height * 0.33);
    final whiteCenterPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerOffset, 4.2, whiteCenterPaint);

    // 5. Inner Black Arrival Dot
    final innerDotPaint = Paint()
      ..color = AppColors.buttonBlack
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerOffset, 2.2, innerDotPaint);

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
    const double radius = 16.0;
    const center = Offset(radius, radius);

    // Outer aura
    final auraPaint = Paint()
      ..color = AppColors.primary.withAlpha(45)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, auraPaint);

    // Inner orange circle
    final orangePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10.5, orangePaint);

    // White border
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 10.5, borderPaint);

    // White directional arrow / navigation triangle inside
    final arrowPath = Path();
    arrowPath.moveTo(center.dx, center.dy - 5.5);
    arrowPath.lineTo(center.dx + 4, center.dy + 4.5);
    arrowPath.lineTo(center.dx, center.dy + 2.2);
    arrowPath.lineTo(center.dx - 4, center.dy + 4.5);
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

  /// Generate Departure marker with floating white badge "Rendez-vous ici"
  /// matching the approaching driver screenshot.
  static Future<BitmapDescriptor> getRendezVousIciMarker() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    const double pillWidth = 132.0;
    const double pillHeight = 30.0;
    const double pinWidth = 26.0;
    const double pinHeight = 32.0;
    const double spacing = 6.0;
    const double totalHeight = pillHeight + spacing + pinHeight;
    const double totalWidth = pillWidth;

    // 1. Floating white pill badge "Rendez-vous ici" with soft shadow
    final badgeRect = const Rect.fromLTWH(0, 0, pillWidth, pillHeight);
    final shadowPaint = Paint()
      ..color = AppColors.shadowCanvasSoft
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect.shift(const Offset(0, 2)), const Radius.circular(15)),
      shadowPaint,
    );

    final bgPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(15)),
      bgPaint,
    );

    final borderPaint = Paint()
      ..color = AppColors.grayBorderDivider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(15)),
      borderPaint,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Rendez-vous ici',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((pillWidth - textPainter.width) / 2, (pillHeight - textPainter.height) / 2),
    );

    // 2. Orange Teardrop Location Pin below badge
    final pinLeft = (totalWidth - pinWidth) / 2;
    final pinTop = pillHeight + spacing;

    final pinPath = Path();
    pinPath.moveTo(pinLeft + pinWidth / 2, pinTop + pinHeight - 2.5);
    pinPath.cubicTo(
      pinLeft + pinWidth * 0.16,
      pinTop + pinHeight * 0.65,
      pinLeft + pinWidth * 0.04,
      pinTop + pinHeight * 0.45,
      pinLeft + pinWidth * 0.04,
      pinTop + pinHeight * 0.32,
    );
    pinPath.arcToPoint(
      Offset(pinLeft + pinWidth * 0.96, pinTop + pinHeight * 0.32),
      radius: const Radius.circular(pinWidth * 0.46),
      clockwise: true,
    );
    pinPath.cubicTo(
      pinLeft + pinWidth * 0.96,
      pinTop + pinHeight * 0.45,
      pinLeft + pinWidth * 0.84,
      pinTop + pinHeight * 0.65,
      pinLeft + pinWidth / 2,
      pinTop + pinHeight - 2.5,
    );
    pinPath.close();

    final pinGradient = ui.Gradient.linear(
      Offset(pinLeft + pinWidth / 2, pinTop),
      Offset(pinLeft + pinWidth / 2, pinTop + pinHeight),
      [
        AppColors.amberRating,
        AppColors.primary,
        AppColors.orangeDarkPin,
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawPath(
      pinPath,
      Paint()
        ..shader = pinGradient
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final centerOffset = Offset(pinLeft + pinWidth / 2, pinTop + pinHeight * 0.33);
    canvas.drawCircle(centerOffset, 4.5, Paint()..color = AppColors.white);
    canvas.drawCircle(centerOffset, 2.4, Paint()..color = AppColors.primary);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// Generate floating pill badge marker on route (e.g. "4 min")
  static Future<BitmapDescriptor> getEtaPillMarker(String text) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    const double pillWidth = 58.0;
    const double pillHeight = 28.0;

    final badgeRect = const Rect.fromLTWH(0, 0, pillWidth, pillHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect.shift(const Offset(0, 2)), const Radius.circular(14)),
      Paint()
        ..color = AppColors.shadowCanvasSoft
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(14)),
      Paint()..color = AppColors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(14)),
      Paint()
        ..color = AppColors.grayBorderDivider
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.0,
          fontWeight: FontWeight.w800,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((pillWidth - textPainter.width) / 2, (pillHeight - textPainter.height) / 2),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(pillWidth.toInt(), pillHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// User location marker matching the new Home screen design:
  /// Concentric orange halo + white circle ring + orange core dot
  static Future<BitmapDescriptor> getUserLocationHaloMarker() async {
    if (_userHaloMarkerIcon != null) return _userHaloMarkerIcon!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double size = 48.0;
    const center = Offset(size / 2, size / 2);

    // 1. Outer soft translucent orange aura
    final auraPaint = Paint()
      ..color = AppColors.userHaloAura
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 22.0, auraPaint);

    // 2. White shadow ring
    final shadowPaint = Paint()
      ..color = AppColors.userHaloShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(center.translate(0, 1), 10.0, shadowPaint);

    // 3. Middle white circle ring
    final whitePaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 9.0, whitePaint);

    // 4. Inner orange core dot
    final corePaint = Paint()
      ..color = AppColors.userHaloCore
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5.5, corePaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    _userHaloMarkerIcon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _userHaloMarkerIcon!;
  }

  /// Dark Eco car top-down marker matching Screenshot 1
  static Future<BitmapDescriptor> getEcoCarMarker() async {
    if (_ecoCarMarkerIcon != null) return _ecoCarMarkerIcon!;
    _ecoCarMarkerIcon = await getTopDownCarMarker(
      bodyColor: AppColors.topDownEcoBody,
      roofColor: AppColors.topDownEcoRoof,
      windowColor: AppColors.topDownEcoWindow,
    );
    return _ecoCarMarkerIcon!;
  }

  /// Vibrant Orange Confort car top-down marker matching Screenshot 2
  static Future<BitmapDescriptor> getConfortCarMarker() async {
    if (_confortCarMarkerIcon != null) return _confortCarMarkerIcon!;
    _confortCarMarkerIcon = await getTopDownCarMarker(
      bodyColor: AppColors.topDownConfortBody,
      roofColor: AppColors.topDownConfortRoof,
      windowColor: AppColors.topDownConfortWindow,
    );
    return _confortCarMarkerIcon!;
  }

  /// Top-down car generator matching the reference screenshots
  static Future<BitmapDescriptor> getTopDownCarMarker({
    required Color bodyColor,
    required Color roofColor,
    required Color windowColor,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double width = 22.0;
    const double height = 34.0;
    const double baseWidth = 32.0;
    const double baseHeight = 48.0;
    canvas.scale(width / baseWidth, height / baseHeight);

    // 1. Soft shadow
    final shadowPaint = Paint()
      ..color = AppColors.topDownShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 4, width - 6, height - 6),
        const Radius.circular(8),
      ),
      shadowPaint,
    );

    // 2. Wheels (4 black wheels)
    final tirePaint = Paint()..color = AppColors.topDownWheel;
    // Front wheels
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 7, 4.0, 9), const Radius.circular(2)), tirePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(width - 4.0, 7, 4.0, 9), const Radius.circular(2)), tirePaint);
    // Rear wheels
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, height - 16, 4.0, 9), const Radius.circular(2)), tirePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(width - 4.0, height - 16, 4.0, 9), const Radius.circular(2)), tirePaint);

    // 3. Car Body
    final bodyPaint = Paint()..color = bodyColor;
    final bodyRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2.5, 2, width - 5, height - 4),
      const Radius.circular(7.5),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    // White outline for contrast on map
    final borderPaint = Paint()
      ..color = AppColors.white.withAlpha(160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bodyRRect, borderPaint);

    // 4. Windshield & Rear window
    final windowPaint = Paint()..color = windowColor;
    // Front windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6.0, 11, width - 12, 7.5),
        const Radius.circular(2.5),
      ),
      windowPaint,
    );
    // Rear window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(7.0, height - 16, width - 14, 5.5),
        const Radius.circular(2.0),
      ),
      windowPaint,
    );

    // 5. Roof
    final roofPaint = Paint()..color = roofColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6.0, 19, width - 12, height - 36),
        const Radius.circular(2.5),
      ),
      roofPaint,
    );

    // 6. Headlights
    final headlightPaint = Paint()..color = AppColors.topDownHeadlight;
    canvas.drawCircle(const Offset(6.5, 3.5), 1.5, headlightPaint);
    canvas.drawCircle(Offset(width - 6.5, 3.5), 1.5, headlightPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// Circular transit stop pin with white border and single letter matching Screenshot 3
  static Future<BitmapDescriptor> getTransitStopLetterMarker({
    required String letter,
    required Color color,
  }) async {
    final key = '${letter}_${color.toARGB32()}';
    if (_transitMarkerIcons.containsKey(key)) return _transitMarkerIcons[key]!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double size = 36.0;
    const center = Offset(size / 2, size / 2);

    // Shadow
    final shadowPaint = Paint()
      ..color = AppColors.transitStopShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(center.translate(0, 1.5), 13.5, shadowPaint);

    // White outer ring
    final whitePaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 13.5, whitePaint);

    // Inner colored circle
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 11.0, fillPaint);

    // Bold White Letter
    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 13.0,
          fontWeight: FontWeight.w900,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final icon = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    _transitMarkerIcons[key] = icon;
    return icon;
  }
}
