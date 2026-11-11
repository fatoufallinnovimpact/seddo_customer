class TransitRoute {
  final String routeId;
  String agencyId;
  String routeShortName;
  String routeLongName;
  String routeType;
  String routeSortOrder;

  TransitRoute({
    required this.routeId,
    required this.agencyId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
    required this.routeSortOrder,
  });

  // Crée un objet TransitRoute à partir d'un Map (par exemple, un JSON décodé)
  factory TransitRoute.fromJson(Map<String, dynamic> map) {
    return TransitRoute(
      routeId: map['routeId'],
      agencyId: map['agency_id'],
      routeShortName:
          map['route_short_name'], // Utilisation de la méthode statique
      routeLongName: removePrefix(map['routeId'], map['route_long_name']),
      routeType: map['route_type'],
      routeSortOrder: map['route_sort_order'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'agency_id': agencyId,
      'route_short_name': routeShortName,
      'route_long_name': routeLongName,
      'route_type': routeType,
      'route_sort_order': routeSortOrder,
    };
  }

  // Méthode pour convertir une liste de Map en liste de TransitRoute
  static List<TransitRoute> fromJsonList(List<dynamic> list) {
    return list.map((item) => TransitRoute.fromJson(item)).toList();
  }

  // Méthode statique pour supprimer le préfixe
  static String removePrefix(String prefix, String input) {
    if (input.startsWith('${prefix}_')) {
      return input.substring(
        prefix.length + 1,
      ); // Retourner la chaîne après le préfixe
    }
    return input;
  }
}
