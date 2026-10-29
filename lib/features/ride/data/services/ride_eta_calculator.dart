import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';

/// Calculation engine for route distance, traffic weighting, and remaining ETA.
/// Implements the exact specifications from technical document:
/// "Seddo : temps restant du trajet" (Pages 1-4).
class RideEtaCalculator {
  /// Haversine GPS distance between two coordinates in meters.
  /// (Formule de Haversine page 2 de la note technique)
  static double dist(LatLng a, LatLng b) {
    const double r = 6371000.0; // Rayon moyen de la terre en mètres
    final double dLat = _rad(b.latitude - a.latitude);
    final double dLng = _rad(b.longitude - a.longitude);
    final double h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _rad(double d) => d * math.pi / 180.0;

  /// Trouve le point de la ligne le plus proche du chauffeur
  /// (nearestIndex page 2 et page 3 de la note technique)
  static int nearestIndex(List<LatLng> pts, LatLng pos, [int lastIndex = 0]) {
    if (pts.isEmpty) return 0;
    int bestIdx = lastIndex.clamp(0, pts.length - 1);
    double minDistance = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final d = dist(pos, pts[i]);
      if (d < minDistance) {
        minDistance = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Distance restante en mètres, le long de la ligne,
  /// depuis le point le plus proche du chauffeur (page 2).
  static double remainingMeters(List<LatLng> pts, int fromIndex, LatLng driver) {
    if (pts.isEmpty) return 0.0;
    final clampedIndex = fromIndex.clamp(0, pts.length - 1);
    double d = dist(driver, pts[clampedIndex]);
    for (int i = clampedIndex; i < pts.length - 1; i++) {
      d += dist(pts[i], pts[i + 1]);
    }
    return d;
  }

  /// Temps restant au prorata de la distance restante (page 2).
  /// Temps restant = Durée de référence × Distance restante ÷ Distance totale
  static int remainingSeconds({
    required double remainingM,
    required int totalM,
    required int totalS,
  }) {
    if (totalM <= 0) return 0;
    return (totalS * remainingM / totalM).round();
  }

  /// Poids proposé selon le trafic (page 4 de la note technique) :
  /// NORMAL = 1.0, SLOW = 1.8, TRAFFIC_JAM = 3.0
  static double weightOf(TrafficSpeed s) => switch (s) {
        TrafficSpeed.slow => 1.8,
        TrafficSpeed.jam => 3.0,
        _ => 1.0,
      };

  /// Temps restant avec pondération du trafic (page 4).
  static int weightedRemainingSeconds({
    required List<LatLng> pts,
    required int fromIndex,
    required LatLng driver,
    required List<TrafficSegmentModel> traffic,
    required int totalS,
    required int totalM,
  }) {
    if (pts.length < 2 || totalM <= 0) return 0;
    if (traffic.isEmpty) {
      final rem = remainingMeters(pts, fromIndex, driver);
      return remainingSeconds(remainingM: rem, totalM: totalM, totalS: totalS);
    }

    // Calcul du dénominateur pondéré total
    double weightedTotal = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      final segDist = dist(pts[i], pts[i + 1]);
      final speed = _speedAtPointIndex(i, traffic);
      weightedTotal += segDist * weightOf(speed);
    }

    if (weightedTotal <= 0) return 0;

    // Calcul du numérateur pondéré restant
    final clampedIndex = fromIndex.clamp(0, pts.length - 1);
    double weightedRemaining = dist(driver, pts[clampedIndex]) *
        weightOf(_speedAtPointIndex(clampedIndex, traffic));

    for (int i = clampedIndex; i < pts.length - 1; i++) {
      final segDist = dist(pts[i], pts[i + 1]);
      final speed = _speedAtPointIndex(i, traffic);
      weightedRemaining += segDist * weightOf(speed);
    }

    return (totalS * weightedRemaining / weightedTotal).round();
  }

  static TrafficSpeed _speedAtPointIndex(
      int index, List<TrafficSegmentModel> traffic) {
    for (final seg in traffic) {
      if (index >= seg.from && index < seg.to) {
        return seg.speed;
      }
    }
    return TrafficSpeed.normal;
  }

  /// Libellé d'affichage de l'ETA selon la note technique (page 2) :
  /// - remainingM < 50 => 'Arrivé'
  /// - min <= 1 => '1 min'
  /// - sinon => '$min min'
  static String etaLabel(int seconds, double remainingM) {
    if (remainingM < 50) return 'Arrivé';
    final min = (seconds / 60).ceil();
    return min <= 1 ? '1 min' : '$min min';
  }

  /// Formatage de la distance restante (ex: '1,8 km' ou '450 m')
  static String formatRemainingDistance(double remainingM) {
    if (remainingM >= 1000) {
      final km = remainingM / 1000.0;
      return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    }
    return '${remainingM.round()} m';
  }

  /// Couleur associée à chaque niveau de trafic
  static Color colorForTrafficSpeed(TrafficSpeed speed) {
    switch (speed) {
      case TrafficSpeed.slow:
        return AppColors.trafficSlow;
      case TrafficSpeed.jam:
        return AppColors.trafficJam;
      case TrafficSpeed.normal:
        return AppColors.trafficNormal;
    }
  }

  /// Construit un jeu de Polylines aux couleurs du trafic Google / Seddo
  /// (Vert fluide #00C853, ambre ralenti #F59E0B, rouge bouchon #DC2626).
  static Set<Polyline> buildTrafficPolylines({
    required String baseId,
    required List<LatLng> points,
    List<TrafficSegmentModel> traffic = const [],
    int width = 5,
    int startIndex = 0,
    LatLng? currentCarPosition,
    int zIndexBase = 1,
  }) {
    if (points.isEmpty) return {};

    final effectiveStart = startIndex.clamp(0, points.length - 1);
    final List<LatLng> remainingPoints;
    if (currentCarPosition != null && effectiveStart > 0) {
      final nextIdx = (effectiveStart + 1).clamp(0, points.length);
      remainingPoints = [
        currentCarPosition,
        ...points.sublist(nextIdx),
      ];
    } else {
      remainingPoints = points.sublist(effectiveStart);
    }
    if (remainingPoints.length < 2) return {};

    final polylines = <Polyline>{};

    // 1. Ligne de base continue garantissant aucun trou visuel (Vert fluide par défaut)
    polylines.add(
      Polyline(
        polylineId: PolylineId('${baseId}_base'),
        points: remainingPoints,
        color: AppColors.trafficNormal,
        width: width,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        zIndex: zIndexBase,
      ),
    );

    if (traffic.isEmpty) {
      return polylines;
    }

    // 2. Tronçons de trafic superposés avec zIndex supérieur
    for (int i = 0; i < traffic.length; i++) {
      final seg = traffic[i];
      final segFrom = seg.from.clamp(0, points.length - 1);
      final segTo = seg.to.clamp(0, points.length - 1);

      if (segTo <= effectiveStart ||
          segFrom >= points.length - 1 ||
          segFrom >= segTo) {
        continue;
      }

      final actualFrom = math.max(segFrom, effectiveStart);
      final actualTo = math.min(segTo, points.length - 1);

      final List<LatLng> segPoints;
      if (currentCarPosition != null &&
          actualFrom == effectiveStart &&
          effectiveStart > 0) {
        final nextIdx = (actualFrom + 1).clamp(0, points.length);
        segPoints = [
          currentCarPosition,
          ...points.sublist(nextIdx, actualTo + 1),
        ];
      } else {
        segPoints = points.sublist(actualFrom, actualTo + 1);
      }

      if (segPoints.length >= 2) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('${baseId}_traffic_$i'),
            points: segPoints,
            color: colorForTrafficSpeed(seg.speed),
            width: width,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            zIndex: zIndexBase + 1,
          ),
        );
      }
    }

    return polylines;
  }

  /// Construit un jeu de polylines en pointillés aux couleurs du trafic réel (route.traffic) :
  /// Chaque tronçon (fluide = vert #00C853, ralenti = ambre #F59E0B, bouchon = rouge #DC2626)
  /// est tracé en pointillés sans superposition pour un rendu net et fidèle à la charte.
  static Set<Polyline> buildDashedTrafficPolylines({
    required String baseId,
    required List<LatLng> points,
    List<TrafficSegmentModel> traffic = const [],
    int startIndex = 0,
    LatLng? currentCarPosition,
    int width = 4,
    List<PatternItem>? patterns,
    int zIndex = 4,
  }) {
    if (points.isEmpty) return {};

    final effectiveStart = startIndex.clamp(0, points.length - 1);
    if (points.length - effectiveStart < 2 && currentCarPosition == null) {
      return {};
    }

    final effectivePatterns = patterns ??
        <PatternItem>[
          PatternItem.dash(16),
          PatternItem.gap(8),
        ];

    final polylines = <Polyline>{};

    // Si aucune donnée de trafic n'est disponible, tracer toute la ligne restante en vert trafic fluide
    if (traffic.isEmpty) {
      final List<LatLng> pts;
      if (currentCarPosition != null && effectiveStart > 0) {
        pts = [
          currentCarPosition,
          ...points.sublist((effectiveStart + 1).clamp(0, points.length)),
        ];
      } else {
        pts = points.sublist(effectiveStart);
      }
      if (pts.length >= 2) {
        polylines.add(
          Polyline(
            polylineId: PolylineId(baseId),
            points: pts,
            color: AppColors.trafficNormal,
            width: width,
            patterns: effectivePatterns,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            zIndex: zIndex,
          ),
        );
      }
      return polylines;
    }

    // Partitionne les points restants en intervalles contigus de même vitesse de trafic
    int curFrom = effectiveStart;
    TrafficSpeed curSpeed = _speedAtPointIndex(curFrom, traffic);
    int segIndex = 0;

    for (int i = effectiveStart + 1; i < points.length; i++) {
      final speed = _speedAtPointIndex(i - 1, traffic);
      if (speed != curSpeed) {
        final List<LatLng> segPts;
        if (segIndex == 0 && currentCarPosition != null && curFrom > 0) {
          final nextIdx = (curFrom + 1).clamp(0, points.length);
          segPts = [
            currentCarPosition,
            ...points.sublist(nextIdx, i),
          ];
        } else {
          segPts = points.sublist(curFrom, i);
        }

        if (segPts.length >= 2) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('${baseId}_$segIndex'),
              points: segPts,
              color: colorForTrafficSpeed(curSpeed),
              width: width,
              patterns: effectivePatterns,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              zIndex: zIndex,
            ),
          );
          segIndex++;
        }
        curFrom = i - 1;
        curSpeed = speed;
      }
    }

    // Dernier intervalle jusqu'à la fin des points
    final List<LatLng> lastPts;
    if (segIndex == 0 && currentCarPosition != null && curFrom > 0) {
      final nextIdx = (curFrom + 1).clamp(0, points.length);
      lastPts = [
        currentCarPosition,
        ...points.sublist(nextIdx),
      ];
    } else {
      lastPts = points.sublist(curFrom);
    }

    if (lastPts.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: PolylineId('${baseId}_$segIndex'),
          points: lastPts,
          color: colorForTrafficSpeed(curSpeed),
          width: width,
          patterns: effectivePatterns,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          zIndex: zIndex,
        ),
      );
    }

    return polylines;
  }
}
