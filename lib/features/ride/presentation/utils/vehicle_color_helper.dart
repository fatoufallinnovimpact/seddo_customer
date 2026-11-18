import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Helper to parse car color string from API (e.g. "Mauve", "Rouge", "Blanc", "Gris", "#FF0000")
/// and provide tint colors / color filters for vehicle assets & map markers.
class VehicleColorHelper {
  /// Maps textual color names or hex strings to a Flutter [Color]
  static Color parseColor(
    String? colorStr, {
    Color fallback = AppColors.vehicleWhite,
  }) {
    if (colorStr == null || colorStr.trim().isEmpty) return fallback;
    final clean = colorStr.trim().toLowerCase();

    // Check hex (#RRGGBB, RRGGBB, #RGB, #AARRGGBB, 0xFFRRGGBB)
    final hexCandidate = clean
        .replaceFirst('#', '')
        .replaceFirst('0x', '');
    if (clean.startsWith('#') ||
        clean.startsWith('0x') ||
        ((hexCandidate.length == 6 || hexCandidate.length == 8) &&
            int.tryParse(hexCandidate, radix: 16) != null)) {
      if (hexCandidate.length == 3) {
        final expanded = hexCandidate.split('').map((c) => '$c$c').join();
        final val = int.tryParse('FF$expanded', radix: 16);
        if (val != null) return Color(val);
      } else if (hexCandidate.length == 6) {
        final val = int.tryParse('FF$hexCandidate', radix: 16);
        if (val != null) return Color(val);
      } else if (hexCandidate.length == 8) {
        final val = int.tryParse(hexCandidate, radix: 16);
        if (val != null) return Color(val);
      }
    }

    // Blanc / White / Perle / Nacré
    if (clean.contains('blanc') ||
        clean.contains('white') ||
        clean.contains('perle') ||
        clean.contains('nacr') ||
        clean.contains('neige')) {
      return AppColors.vehicleWhite;
    }

    // Mauve / Violet / Purple / Lilas / Prune / Pourpre / Indigo / Lavande
    if (clean.contains('mauve') ||
        clean.contains('meuve') ||
        clean.contains('violet') ||
        clean.contains('purple') ||
        clean.contains('pourpre') ||
        clean.contains('lilas') ||
        clean.contains('prune') ||
        clean.contains('lavande') ||
        clean.contains('indigo') ||
        clean.contains('améthyste') ||
        clean.contains('amethyste')) {
      return AppColors.vehicleMauve;
    }

    // Rose / Pink / Magenta / Fuchsia / Corail
    if (clean.contains('rose') ||
        clean.contains('pink') ||
        clean.contains('magenta') ||
        clean.contains('fuchsia') ||
        clean.contains('corail') ||
        clean.contains('saumon')) {
      return AppColors.vehiclePink;
    }

    // Noir / Black / Ébène / Carbone
    if (clean.contains('noir') ||
        clean.contains('black') ||
        clean.contains('ébène') ||
        clean.contains('ebene') ||
        clean.contains('carbone')) {
      return AppColors.vehicleBlack;
    }

    // Anthracite / Gris foncé / Charcoal / Graphite / Titane
    if (clean.contains('anthracite') ||
        clean.contains('charcoal') ||
        clean.contains('graphite') ||
        clean.contains('titane') ||
        clean.contains('ardoise') ||
        (clean.contains('gris') &&
            (clean.contains('fonc') || clean.contains('sombre')))) {
      return AppColors.vehicleDarkGrey;
    }

    // Gris / Argent / Silver / Platine / Métallisé
    if (clean.contains('gris') ||
        clean.contains('grey') ||
        clean.contains('gray') ||
        clean.contains('argent') ||
        clean.contains('silver') ||
        clean.contains('platine') ||
        clean.contains('métallis') ||
        clean.contains('metallis') ||
        clean.contains('chrome')) {
      return AppColors.vehicleGrey;
    }

    // Bordeaux / Grenat / Burgundy / Maroon / Rubis
    if (clean.contains('bordeaux') ||
        clean.contains('grenat') ||
        clean.contains('burgundy') ||
        clean.contains('maroon') ||
        clean.contains('rubis') ||
        clean.contains('cerise')) {
      return AppColors.vehicleBurgundy;
    }

    // Rouge / Red
    if (clean.contains('rouge') ||
        clean.contains('red') ||
        clean.contains('vermillon') ||
        clean.contains('carmin')) {
      return AppColors.vehicleRed;
    }

    // Turquoise / Cyan / Bleu ciel / Azur / Menthe / Teal
    if (clean.contains('turquoise') ||
        clean.contains('cyan') ||
        clean.contains('bleu ciel') ||
        clean.contains('azur') ||
        clean.contains('menthe') ||
        clean.contains('teal') ||
        clean.contains('aqua')) {
      return AppColors.vehicleCyan;
    }

    // Bleu nuit / Marine / Navy
    if (clean.contains('marine') ||
        clean.contains('nuit') ||
        clean.contains('navy') ||
        (clean.contains('bleu') &&
            (clean.contains('fonc') || clean.contains('sombre')))) {
      return AppColors.vehicleNavy;
    }

    // Bleu / Blue
    if (clean.contains('bleu') || clean.contains('blue')) {
      return AppColors.vehicleBlue;
    }

    // Or / Doré / Gold / Champagne
    if (clean.contains('doré') ||
        clean.contains('dore') ||
        clean.contains('gold') ||
        clean.contains('champagne') ||
        clean == 'or' ||
        clean.startsWith('or ') ||
        clean.endsWith(' or')) {
      return AppColors.vehicleGold;
    }

    // Jaune / Yellow / Citron / Moutarde
    if (clean.contains('jaune') ||
        clean.contains('yellow') ||
        clean.contains('citron') ||
        clean.contains('moutarde')) {
      return AppColors.vehicleYellow;
    }

    // Olive / Kaki / Khaki
    if (clean.contains('olive') ||
        clean.contains('kaki') ||
        clean.contains('khaki')) {
      return AppColors.vehicleOlive;
    }

    // Vert / Green / Émeraude
    if (clean.contains('vert') ||
        clean.contains('green') ||
        clean.contains('émeraude') ||
        clean.contains('emeraude') ||
        clean.contains('lime')) {
      return AppColors.vehicleGreen;
    }

    // Orange / Mandarine / Abricot
    if (clean.contains('orange') ||
        clean.contains('mandarine') ||
        clean.contains('abricot')) {
      return AppColors.vehicleOrange;
    }

    // Bronze / Cuivre / Copper
    if (clean.contains('bronze') ||
        clean.contains('cuivre') ||
        clean.contains('copper') ||
        clean.contains('rouille')) {
      return AppColors.vehicleBronze;
    }

    // Beige / Crème / Ivoire / Sable
    if (clean.contains('beige') ||
        clean.contains('crème') ||
        clean.contains('creme') ||
        clean.contains('cream') ||
        clean.contains('ivoire') ||
        clean.contains('ivory') ||
        clean.contains('sable') ||
        clean.contains('sand') ||
        clean.contains('écru') ||
        clean.contains('ecru')) {
      return AppColors.vehicleBeige;
    }

    // Marron / Brun / Brown / Chocolat / Café / Caramel / Taupe
    if (clean.contains('marron') ||
        clean.contains('brun') ||
        clean.contains('brown') ||
        clean.contains('chocolat') ||
        clean.contains('café') ||
        clean.contains('cafe') ||
        clean.contains('camel') ||
        clean.contains('caramel') ||
        clean.contains('taupe')) {
      return AppColors.vehicleBrown;
    }

    return fallback;
  }

  /// Returns a ColorFilter to dynamically tint a vehicle asset in the modal
  /// while strictly preserving 100% transparency of all background pixels (zero rectangular discoloration).
  static ColorFilter? getColorFilter(String? colorStr) {
    if (colorStr == null || colorStr.trim().isEmpty) return null;
    final clean = colorStr.trim().toLowerCase();

    // Blanc / White est la couleur naturelle de carr_cropped.png -> aucun filtre requis
    if (clean.contains('blanc') ||
        clean.contains('white') ||
        clean.contains('perle') ||
        clean.contains('nacr') ||
        clean.contains('neige') ||
        clean == '#ffffff' ||
        clean == 'ffffff' ||
        clean == '#fff') {
      return null;
    }

    final color = parseColor(colorStr);
    if (color == AppColors.vehicleWhite) {
      return null;
    }
    return ColorFilter.mode(color, BlendMode.modulate);
  }
}
