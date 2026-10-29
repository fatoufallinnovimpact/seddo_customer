import 'package:flutter/material.dart';

/// Helper to parse car color string from API (e.g. "Rouge", "Blanc", "Gris", "#FF0000")
/// and provide tint colors / color filters for vehicle assets & map markers.
class VehicleColorHelper {
  /// Maps textual color names or hex strings to a Flutter [Color]
  static Color parseColor(String? colorStr, {Color fallback = const Color(0xFFFFFFFF)}) {
    if (colorStr == null || colorStr.trim().isEmpty) return fallback;
    final clean = colorStr.trim().toLowerCase();

    // Check hex (#RRGGBB or RRGGBB)
    if (clean.startsWith('#') || (clean.length == 6 && int.tryParse(clean, radix: 16) != null)) {
      final hex = clean.replaceFirst('#', '');
      if (hex.length == 6) {
        final val = int.tryParse('FF$hex', radix: 16);
        if (val != null) return Color(val);
      }
    }

    if (clean.contains('blanc') || clean.contains('white')) return const Color(0xFFFFFFFF);
    if (clean.contains('noir') || clean.contains('black')) return const Color(0xFF1F2937);
    if (clean.contains('gris') ||
        clean.contains('grey') ||
        clean.contains('gray') ||
        clean.contains('argent') ||
        clean.contains('silver')) {
      return const Color(0xFF9CA3AF);
    }
    if (clean.contains('rouge') || clean.contains('red') || clean.contains('bordeaux')) {
      return const Color(0xFFDC2626);
    }
    if (clean.contains('bleu') || clean.contains('blue')) return const Color(0xFF2563EB);
    if (clean.contains('jaune') || clean.contains('yellow')) return const Color(0xFFF59E0B);
    if (clean.contains('vert') || clean.contains('green')) return const Color(0xFF16A34A);
    if (clean.contains('orange')) return const Color(0xFFEA580C);
    if (clean.contains('marron') || clean.contains('brown')) return const Color(0xFF78350F);

    return fallback;
  }

  /// Returns a ColorFilter to dynamically tint a vehicle asset in the modal
  /// while strictly preserving 100% transparency of all background pixels (zero rectangular discoloration).
  static ColorFilter? getColorFilter(String? colorStr) {
    if (colorStr == null || colorStr.trim().isEmpty) return null;
    final clean = colorStr.trim().toLowerCase();
    // If yellow (default seddo eco color), no filter needed
    if (clean.contains('jaune') || clean.contains('yellow')) return null;

    final color = parseColor(colorStr);
    final r = color.r;
    final g = color.g;
    final b = color.b;

    // Rec. 601 Luminance grayscale matrix modulated by target color:
    // Transparent pixels (A = 0) strictly stay (0, 0, 0, 0).
    return ColorFilter.matrix(<double>[
      0.299 * r, 0.587 * r, 0.114 * r, 0.0, 0.0,
      0.299 * g, 0.587 * g, 0.114 * g, 0.0, 0.0,
      0.299 * b, 0.587 * b, 0.114 * b, 0.0, 0.0,
      0.0,       0.0,       0.0,       1.0, 0.0,
    ]);
  }
}
