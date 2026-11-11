class PlaceModel {
  final double latitude;
  final double longitude;
  final String name;
  final String address;
  final String?  placeId;

  PlaceModel({
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.address,
    this.placeId
  });

  factory PlaceModel.fromJson(Map<String, dynamic> item) {
    double latitude, longitude;

    // Gestion du cas où les clés sont 'latitude' et 'longitude'
    if (item.containsKey('latitude') && item.containsKey('longitude')) {
      latitude = double.parse(item['latitude'].toString());
      longitude = double.parse(item['longitude'].toString());
    }
    // Gestion du cas où les clés sont 'lat' et 'lon'
    else if (item.containsKey('lat') && item.containsKey('lon')) {
      latitude = double.parse(item['lat'].toString());
      longitude = double.parse(item['lon'].toString());
    } else {
      // Si les deux formats ne sont pas trouvés, retourne une erreur ou une valeur par défaut
      throw Exception('Invalid JSON format for PlaceModel');
    }

    // Extraction du nom
    final name = item['name'] ?? '';
    final placeId= item['placeId'] ?? '';

    // Extraction et gestion de l'adresse
    final address = item['address'] is String
        ? item['address'] // Si l'adresse est déjà une chaîne, pas besoin de formater
        : _formatAddress(item['address']); // Sinon, on formate l'adresse

    return PlaceModel(
      latitude: latitude,
      longitude: longitude,
      name: name,
      address: address,
      placeId: placeId
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'address': address,
      "placeId":placeId
    };
  }

  static List<PlaceModel> fromJsonList(List<dynamic> list) {
    return list.map((item) => PlaceModel.fromJson(item)).toList();
  }

  // Formatage de l'adresse pour la rendre lisible
  static String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return '';

    final parts = [
      address['road'],
      address['neighbourhood'],
      address['suburb'],
      address['city_district'],
      address['city'],
      address['country'],
    ].where((part) => part != null).toList();

    return parts.join(', ');
  }
}
