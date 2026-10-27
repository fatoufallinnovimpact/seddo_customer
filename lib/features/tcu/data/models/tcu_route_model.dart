import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Supported public transport types in Dakar TCU network
enum TcuTransportType {
  all,
  ddd,
  aftu,
  brt,
  ter;

  String get displayName {
    switch (this) {
      case TcuTransportType.all:
        return 'tcu.filter_all'.tr();
      case TcuTransportType.ddd:
        return 'Dem Dikk';
      case TcuTransportType.aftu:
        return 'AFTU';
      case TcuTransportType.brt:
        return 'BRT';
      case TcuTransportType.ter:
        return 'TER';
    }
  }

  Color get dotColor {
    switch (this) {
      case TcuTransportType.all:
        return AppColors.buttonBlack;
      case TcuTransportType.ddd:
        return AppColors.tcuDddGreen;
      case TcuTransportType.aftu:
        return AppColors.tcuAftuBlue;
      case TcuTransportType.brt:
        return AppColors.tcuBrtOrange;
      case TcuTransportType.ter:
        return AppColors.tcuTerPurple;
    }
  }

  Color get badgeBgColor => dotColor;

  String get shortBadge {
    switch (this) {
      case TcuTransportType.all:
        return 'TCU';
      case TcuTransportType.ddd:
        return 'DDD';
      case TcuTransportType.aftu:
        return 'AFTU';
      case TcuTransportType.brt:
        return 'BRT';
      case TcuTransportType.ter:
        return 'TER';
    }
  }

  String get defaultImagePath {
    switch (this) {
      case TcuTransportType.all:
      case TcuTransportType.ddd:
        return 'assets/images/tcu/ddd_bus.png';
      case TcuTransportType.aftu:
        return 'assets/images/tcu/aftu_bus.png';
      case TcuTransportType.brt:
        return 'assets/images/tcu/brt_bus.png';
      case TcuTransportType.ter:
        return 'assets/images/tcu/ter_train.png';
    }
  }

  bool get isTrain => this == TcuTransportType.ter;
}

/// Route preference filters (Plus rapide, Alternative, Panoramique) matching the new design
enum TcuRouteFilter {
  fastest,
  alternative,
  panoramic;

  String get displayName {
    switch (this) {
      case TcuRouteFilter.fastest:
        return 'tcu.filter_fastest'.tr();
      case TcuRouteFilter.alternative:
        return 'tcu.filter_alternative'.tr();
      case TcuRouteFilter.panoramic:
        return 'tcu.filter_panoramic'.tr();
    }
  }

  String get defaultDurationText {
    switch (this) {
      case TcuRouteFilter.fastest:
        return '26 min';
      case TcuRouteFilter.alternative:
        return '33 min';
      case TcuRouteFilter.panoramic:
        return '30 min';
    }
  }
}

/// Represents an individual stop in a public transport journey
class TcuStop {
  final String id;
  final String name;
  final String? subtitle;
  final int walkingDistanceMeters;
  final int walkingDurationMinutes;
  final int nextArrivalMinutes;
  final double latitude;
  final double longitude;

  const TcuStop({
    required this.id,
    required this.name,
    this.subtitle,
    required this.walkingDistanceMeters,
    required this.walkingDurationMinutes,
    required this.nextArrivalMinutes,
    required this.latitude,
    required this.longitude,
  });

  LatLng get coordinates => LatLng(latitude, longitude);

  String get walkingSummary =>
      '$walkingDistanceMeters m · $walkingDurationMinutes min à pied';
}

/// Complete TCU Route option proposition card model
class TcuRouteOption {
  final String id;
  final TcuTransportType type;
  final String lineCode; // e.g. "DDD 10", "B1", "AFTU 24", "TER"
  final String linePrefix; // "Ligne de bus :" or "Ligne :"
  final int estimatedDurationMinutes;
  final String estimatedDurationText; // e.g. "19 min"
  final TcuStop departureStop;
  final TcuStop arrivalStop;
  final int stopsCount;
  final List<String> stopsList;
  final String imagePath;
  final LatLng userOriginCoordinates;
  final List<LatLng> walkingPathToStop;

  const TcuRouteOption({
    required this.id,
    required this.type,
    required this.lineCode,
    required this.linePrefix,
    required this.estimatedDurationMinutes,
    required this.estimatedDurationText,
    required this.departureStop,
    required this.arrivalStop,
    required this.stopsCount,
    required this.stopsList,
    required this.imagePath,
    required this.userOriginCoordinates,
    required this.walkingPathToStop,
  });

  Color get typeColor => type.dotColor;
  Color get badgeBgColor => type.badgeBgColor;
  String get badgeText => type.shortBadge;
  bool get isTrain => type.isTrain;
}
