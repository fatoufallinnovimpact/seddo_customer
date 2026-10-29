import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/features/ride/data/services/ride_eta_calculator.dart';

void main() {
  group('RideEtaCalculator - Technical Document Specifications', () {
    const p1 = LatLng(14.6928, -17.4467); // Place de l'Indépendance
    const p2 = LatLng(14.7100, -17.4650); // Point intermédiaire
    const p3 = LatLng(14.7449, -17.5107); // Almadies

    test('1. Haversine distance calculates meters realistically', () {
      final d = RideEtaCalculator.dist(p1, p3);
      expect(d, greaterThan(8000));
      expect(d, lessThan(15000));
    });

    test('2. nearestIndex returns closest point index along the polyline', () {
      final pts = [p1, p2, p3];
      final closeToP1 = const LatLng(14.6929, -17.4468);
      final closeToP3 = const LatLng(14.7448, -17.5106);

      expect(RideEtaCalculator.nearestIndex(pts, closeToP1), equals(0));
      expect(RideEtaCalculator.nearestIndex(pts, closeToP3), equals(2));
    });

    test('3. remainingMeters calculates road distance along the line', () {
      final pts = [p1, p2, p3];
      final rem = RideEtaCalculator.remainingMeters(pts, 0, p1);
      final segment1 = RideEtaCalculator.dist(p1, p2);
      final segment2 = RideEtaCalculator.dist(p2, p3);

      expect(rem, closeTo(segment1 + segment2, 1.0));
    });

    test('4. remainingSeconds implements exact pro-rata formula from Page 2', () {
      // Temps restant = Durée de référence × Distance restante ÷ Distance totale
      final s = RideEtaCalculator.remainingSeconds(
        remainingM: 5000,
        totalM: 10000,
        totalS: 1200, // 20 min
      );
      expect(s, equals(600)); // 10 min
    });

    test('5. etaLabel matches page 2 rules', () {
      // Less than 50 meters -> Arrivé
      expect(RideEtaCalculator.etaLabel(120, 30.0), equals('Arrivé'));

      // 45 seconds (>= 50m) -> 1 min
      expect(RideEtaCalculator.etaLabel(45, 200.0), equals('1 min'));

      // 180 seconds (3 minutes) -> 3 min
      expect(RideEtaCalculator.etaLabel(180, 1500.0), equals('3 min'));

      // 1985 seconds (33.08 minutes ceil = 34 min)
      expect(RideEtaCalculator.etaLabel(1985, 11919.0), equals('34 min'));
    });

    test('6. formatRemainingDistance formats correctly in km and meters', () {
      expect(RideEtaCalculator.formatRemainingDistance(1800), equals('1,8 km'));
      expect(RideEtaCalculator.formatRemainingDistance(450), equals('450 m'));
      expect(RideEtaCalculator.formatRemainingDistance(11919), equals('11,9 km'));
    });

    test('7. weightOf returns weights defined in Page 4 (normal: 1, slow: 1.8, jam: 3)', () {
      expect(RideEtaCalculator.weightOf(TrafficSpeed.normal), equals(1.0));
      expect(RideEtaCalculator.weightOf(TrafficSpeed.slow), equals(1.8));
      expect(RideEtaCalculator.weightOf(TrafficSpeed.jam), equals(3.0));
    });

    test('8. buildTrafficPolylines constructs colored segments matching traffic levels', () {
      final pts = [
        const LatLng(14.69, -17.44),
        const LatLng(14.70, -17.45),
        const LatLng(14.71, -17.46),
        const LatLng(14.72, -17.47),
        const LatLng(14.73, -17.48),
      ];

      final traffic = [
        const TrafficSegmentModel(from: 0, to: 2, speed: TrafficSpeed.normal),
        const TrafficSegmentModel(from: 2, to: 3, speed: TrafficSpeed.slow),
        const TrafficSegmentModel(from: 3, to: 4, speed: TrafficSpeed.jam),
      ];

      final polylines = RideEtaCalculator.buildTrafficPolylines(
        baseId: 'test_route',
        points: pts,
        traffic: traffic,
      );

      expect(polylines.length, greaterThanOrEqualTo(3));

      final colors = polylines.map((p) => p.color).toSet();
      expect(colors.contains(AppColors.trafficNormal), isTrue);
      expect(colors.contains(AppColors.trafficSlow), isTrue);
      expect(colors.contains(AppColors.trafficJam), isTrue);
    });
  });
}
