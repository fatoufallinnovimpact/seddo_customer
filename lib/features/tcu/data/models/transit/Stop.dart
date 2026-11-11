// ignore_for_file: equal_keys_in_map, unnecessary_null_comparison

import 'ShopModel.dart';

class StopModel {
  String stop_id;
  String stop_name;
  String stop_lat;
  String stop_lon;
  String stop_timezone;
  String picture;
  List<String> pictures;
  List<ShopModel> shops; // Liste des utilisateurs qui ont aimé le post
  String stop_desc;
  String stop_code;
  bool terAgency;
  bool parking;
  bool toilets;
  bool shop;

  bool waitingRoom;
  bool lostAndFound;

  StopModel({
    this.stop_id = "",
    this.stop_name = "",
    this.stop_code = "",

    this.stop_lat = "",
    this.stop_lon = "",
    this.stop_timezone = "",
    this.picture = "",
    this.pictures = const [],
    this.shops = const [],
    this.stop_desc = "",
    this.lostAndFound = false,
    this.parking = false,
    this.shop = false,
    this.terAgency = false,
    this.toilets = false,
    this.waitingRoom = false,
  });

  StopModel.fromJson(Map<String, dynamic> map)
    : stop_id = map['stop_id'] ?? map['id'] ?? "",
      stop_name = map['stop_name'] ?? "",
      stop_lat = map['stop_lat'].toString(),
      stop_lon = map['stop_lon'].toString(),
      stop_timezone = map['stop_timezone'] ?? "",
      picture = map['picture'] ?? "",
      pictures = List<String>.from(map['pictures'] ?? []),
      shops = ShopModel.fromJsonList(map["shopslist"] ?? []),
      stop_desc = map['stop_desc'] ?? "",
      stop_code = map['stop_code'] ?? "",
      terAgency = map['terAgency'] ?? false,
      parking = map['parking'] ?? false,
      toilets = map['toilets'] ?? false,
      shop = map['shops'] ?? false,
      waitingRoom = map['waitingRoom'] ?? false,
      lostAndFound = map['lostAndFound'] ?? false;

  Map<String, dynamic> toJson() => {
    "stop_id": stop_id,
    "stop_name": stop_name,
    "stop_lat": stop_lat,
    "stop_lon": stop_lon,
    "stop_timezone": stop_timezone,
    "picture": picture,
    "pictures": pictures,
    "stop_desc": stop_desc,
    "shops": shops,
    "terAgency": terAgency,
    "parking": parking,
    "toilets": toilets,
    "stop_code": stop_code,
    "shops": shop,
    "waitingRoom": waitingRoom,
    "lostAndFound": lostAndFound,
  };

  static List<StopModel> fromJsonList(List? list) {
    if (list == null) return [];
    return list.map((item) => StopModel.fromJson(item)).toList();
  }
}
