/// Helper to detect if a geographic coordinate or location address
/// is inside Seddo's active operating zone (Dakar metropolitan area + AIBD corridor),
/// or in an unserved area (e.g. Thiès, Mbour, Saint-Louis, Touba).
class ServiceAreaHelper {
  /// Known cities/regions outside of Dakar service zone
  static const Map<String, String> knownOutsideCities = {
    'thiès': 'Thiès',
    'thies': 'Thiès',
    'mbour': 'Mbour',
    'saly': 'Saly',
    'saint-louis': 'Saint-Louis',
    'saint louis': 'Saint-Louis',
    'touba': 'Touba',
    'kaolack': 'Kaolack',
    'ziguinchor': 'Ziguinchor',
    'tivaouane': 'Tivaouane',
    'fatick': 'Fatick',
    'kolda': 'Kolda',
    'richard-toll': 'Richard-Toll',
    'louga': 'Louga',
    'tambacounda': 'Tambacounda',
  };

  /// Returns true if the coordinate is within the Dakar metropolitan and AIBD corridor:
  /// Latitude: [14.45, 14.88]
  /// Longitude: [-17.58, -17.02]
  static bool isWithinServiceCoordinates(double latitude, double longitude) {
    return latitude >= 14.45 &&
        latitude <= 14.88 &&
        longitude >= -17.58 &&
        longitude <= -17.02;
  }

  /// Determines if a place is outside the service area and returns the city name if outside,
  /// or null if it is within the active service area.
  static String? getOutsideCityName({
    required double latitude,
    required double longitude,
    String? address,
  }) {
    if (address != null) {
      final lower = address.toLowerCase();
      for (final entry in knownOutsideCities.entries) {
        if (lower.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    if (!isWithinServiceCoordinates(latitude, longitude)) {
      if (address != null && address.contains(',')) {
        final parts = address.split(',');
        if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
          return parts.first.trim();
        }
      }
      return 'Thiès';
    }

    return null;
  }
}
