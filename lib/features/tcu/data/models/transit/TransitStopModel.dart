class TransitStopModel {
  final String stopId;
  final String stopCode;
  final String stopName;
  final String stopDesc;
  final double stopLat;
  final double stopLon;
  final int locationType;
  final String parentStation;
  final String stopTimezone;
  final String platformCode;
  final String transitType;
  final String line;
  bool isMixt;

  TransitStopModel(
      {required this.stopId,
      required this.stopCode,
      required this.stopName,
      required this.stopDesc,
      required this.stopLat,
      required this.stopLon,
      required this.locationType,
      required this.parentStation,
      required this.stopTimezone,
      required this.platformCode,
      required this.transitType,
      this.line = "",
      this.isMixt = false});

  // Méthode pour convertir un Map en TransitStopModel
  factory TransitStopModel.fromJson(Map<String, dynamic> json) {
    return TransitStopModel(
      stopId: json['stopId'] ?? '',
      stopCode: json['stopCode'] ?? '',
      stopName: json['stopName'] ?? '',
      stopDesc: json['stopDesc'] ?? '',
      stopLat: json['stopLat']?.toDouble() ?? 0.0,
      // Convertit en double
      stopLon: json['stopLon']?.toDouble() ?? 0.0,
      // Convertit en double
      locationType: json['locationType'] ?? 0,
      parentStation: json['parentStation'] ?? '',
      stopTimezone: json['stopTimezone'] ?? '',
      platformCode: json['platformCode'] ?? '',
      transitType: json['transitType'] ?? '',
      line: '',
      isMixt: false,
    );
  }

  // Méthode pour convertir un TransitStopModel en Map
  Map<String, dynamic> toJson() {
    return {
      'stopId': stopId,
      'stopCode': stopCode,
      'stopName': stopName,
      'stopDesc': stopDesc,
      'stopLat': stopLat,
      'stopLon': stopLon,
      'locationType': locationType,
      'parentStation': parentStation,
      'stopTimezone': stopTimezone,
      'platformCode': platformCode,
      'transitType': transitType,
      'isMixt': isMixt,
      'line': line,
    };
  }

  static List<TransitStopModel> fromJsonList(List<dynamic> list) {
    return list.map((item) => TransitStopModel.fromJson(item)).toList();
  }
}
