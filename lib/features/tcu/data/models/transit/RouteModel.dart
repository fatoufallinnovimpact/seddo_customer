// ignore_for_file: file_names, non_constant_identifier_names

class RouteModel {
  final String routeId;
  final String agency_id;
  final String route_short_name;
  final String route_long_name;
  final String route_type;
  final String route_sort_order;

  RouteModel({
    required this.routeId,
    required this.agency_id,
    required this.route_short_name,
    required this.route_long_name,
    required this.route_type,
    required this.route_sort_order,
  });

  factory RouteModel.fromJson(Map<String, dynamic> map) {
    return RouteModel(
      routeId: map['routeId'] ?? "",
      agency_id: map['agency_id'] ?? "",
      route_short_name: map['route_short_name'] ?? "",
      route_long_name: map['route_long_name'] ?? "",
      route_type: map['route_type'].toString(),
      route_sort_order: map['route_sort_order'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "routeId": routeId,
      "agency_id": agency_id,
      "route_short_name": route_short_name,
      "route_long_name": route_long_name,
      "route_type": route_type,
      "route_sort_order": route_sort_order,
    };
  }

  static List<RouteModel> fromJsonList(List<dynamic> list) {
    return list.map((item) => RouteModel.fromJson(item)).toList();
  }
}
