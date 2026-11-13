import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modèle léger contenant l'adresse et les coordonnées GPS de l'utilisateur
class CachedUserLocation {
  final String addressShort;
  final String addressDetails;
  final LatLng location;

  const CachedUserLocation({
    required this.addressShort,
    required this.addressDetails,
    required this.location,
  });
}

/// Service de stockage et de mise en cache ultra-rapide de la position utilisateur.
/// Permet un affichage instantané et fluide sous le logo SEDDO dès le démarrage
/// sans attendre de requête réseau.
class UserLocationStorage {
  static const String _keyAddressShort = 'seddo_user_address_short';
  static const String _keyAddressDetails = 'seddo_user_address_details';
  static const String _keyLat = 'seddo_user_lat';
  static const String _keyLng = 'seddo_user_lng';

  /// Cache mémoire statique disponible immédiatement pour la 1ère frame
  static CachedUserLocation? cached;

  /// Réinitialise le cache pour les tests unitaires
  static void resetCache() {
    cached = null;
    _reverseGeocodeMemoryCache.clear();
  }

  /// Cache mémoire des reverse geocodes indexé par coordonnées arrondies (~100m)
  static final Map<String, ({String short, String details})> _reverseGeocodeMemoryCache = {};

  static String _coordKey(double lat, double lng) =>
      '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';

  /// Vérifie si le libellé correspond à une adresse de rue précise (ex: "77 Rue 4", "Rue PE 34", "Avenue...")
  /// et NON à un quartier générique ou une commune (ex: "Fann-Point E-Amitié", "Point E", "Fann Hock").
  static bool isStreetLevelAddress(String address) {
    final clean = address.trim();
    if (clean.isEmpty ||
        clean == 'Chargement...' ||
        clean == 'Position GPS actuelle' ||
        clean == 'Position sélectionnée' ||
        clean == 'Ma position actuelle') {
      return false;
    }
    final lower = clean.toLowerCase();
    // Exclure les libellés de commune ou de quartier générique sans rue
    if (lower == 'fann-point e-amitié' ||
        lower == 'fann-point e' ||
        lower == 'fann point e' ||
        lower == 'point e' ||
        lower == 'point e, dakar' ||
        lower == 'fann hock' ||
        lower == 'fann hock, dakar' ||
        lower == 'fann résidence' ||
        lower == 'fann residence' ||
        lower == 'dakar' ||
        lower == 'dakar, sénégal' ||
        lower == 'dakar, senegal') {
      return false;
    }
    // Indicateurs typiques de rue, voie ou numéro
    final streetKeywords = [
      'rue',
      'rte',
      'route',
      'av.',
      'av ',
      'avenue',
      'bd',
      'boulevard',
      'allée',
      'allee',
      'allees',
      'impasse',
      'voie',
      'place',
      'rond-point',
      'rond point',
      'cité',
      'cite',
      'villa',
      'immeuble',
      'lot',
    ];
    for (final kw in streetKeywords) {
      if (lower.contains(kw)) return true;
    }
    // Présence d'un chiffre suivi ou précédé d'un nom de lieu (ex: "77 PE 34", "5065 L", "YF-557, 20")
    if (RegExp(r'\d').hasMatch(clean) && clean.length >= 4) {
      return true;
    }
    return false;
  }

  /// Récupère l'adresse en cache mémoire pour ces coordonnées si déjà résolue avec précision
  static ({String short, String details})? getCachedGeocode(LatLng location) {
    final cachedEntry =
        _reverseGeocodeMemoryCache[_coordKey(location.latitude, location.longitude)];
    if (cachedEntry != null && isStreetLevelAddress(cachedEntry.short)) {
      return cachedEntry;
    }
    return null;
  }

  /// Met en cache mémoire l'adresse résolue
  static void cacheGeocode(LatLng location, String short, String details) {
    if (short.isNotEmpty &&
        short != 'Chargement...' &&
        short != 'Position GPS actuelle' &&
        isStreetLevelAddress(short)) {
      _reverseGeocodeMemoryCache[_coordKey(location.latitude, location.longitude)] =
          (short: short, details: details);
    }
  }

  /// Charge la dernière position connue depuis SharedPreferences
  static Future<CachedUserLocation?> loadCachedLocation() async {
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final short = prefs.getString(_keyAddressShort);
      final details = prefs.getString(_keyAddressDetails);
      final lat = prefs.getDouble(_keyLat);
      final lng = prefs.getDouble(_keyLng);

      if (short != null && short.isNotEmpty && lat != null && lng != null) {
        cached = CachedUserLocation(
          addressShort: short,
          addressDetails: details ?? '',
          location: LatLng(lat, lng),
        );
        cacheGeocode(cached!.location, short, details ?? '');
        return cached;
      }
    } catch (_) {}
    return null;
  }

  /// Sauvegarde la position et l'adresse en cache mémoire et sur disque
  static Future<void> saveLocation({
    required String addressShort,
    required String addressDetails,
    required LatLng location,
  }) async {
    if (addressShort.isEmpty ||
        addressShort == 'Chargement...' ||
        addressShort == 'Position GPS actuelle') {
      return;
    }

    // Si on a déjà une vraie adresse de rue en mémoire, ne pas la remplacer par un libellé générique de quartier
    if (cached != null &&
        isStreetLevelAddress(cached!.addressShort) &&
        !isStreetLevelAddress(addressShort)) {
      return;
    }

    cached = CachedUserLocation(
      addressShort: addressShort,
      addressDetails: addressDetails,
      location: location,
    );
    cacheGeocode(location, addressShort, addressDetails);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAddressShort, addressShort);
      await prefs.setString(_keyAddressDetails, addressDetails);
      await prefs.setDouble(_keyLat, location.latitude);
      await prefs.setDouble(_keyLng, location.longitude);
    } catch (_) {}
  }
}
