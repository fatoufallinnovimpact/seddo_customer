import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/widgets/driver_avatar_widget.dart';
import 'package:seddo/features/ride/presentation/widgets/active_driver_card_widget.dart';
import '../../test_helpers/test_localization_helper.dart';

class _FakeRideService extends Fake implements RideService {
  final Uint8List? bytes;
  _FakeRideService([this.bytes]);

  @override
  Future<Uint8List?> getPartyPhoto({
    required String rideId,
    String party = 'driver',
    String? explicitUrl,
  }) async {
    return bytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('Driver Photo & Avatar Tests', () {
    test('DriverModel.fromRideJson parses photoUrl correctly from endpoint payload', () {
      final json = {
        'id': '38d04d42-3072-49fb-9ed1-4a188d75a6b1',
        'status': 'DRIVER_ACCEPTED',
        'driver': {
          'id': 'drv_123',
          'name': 'Moussa Diop',
          'photoUrl':
              '/v1/rides/38d04d42-3072-49fb-9ed1-4a188d75a6b1/driver/photo?v=1794673375',
          'phone': '+221 77 123 45 67',
          'rating': 4.9,
          'vehicle': {
            'model': 'Peugeot 308',
            'color': 'Mauve',
            'plate': 'DK-1234-AA',
          },
        },
      };

      final driver = DriverModel.fromRideJson(json);
      expect(
        driver.photoUrl,
        '/v1/rides/38d04d42-3072-49fb-9ed1-4a188d75a6b1/driver/photo?v=1794673375',
      );
      expect(driver.name, 'Moussa Diop');
    });

    test('DriverAvatarHelper.resolveUrl formats relative photo URLs correctly', () {
      const relative =
          '/v1/rides/38d04d42-3072-49fb-9ed1-4a188d75a6b1/driver/photo?v=1794673375';
      final resolved = DriverAvatarHelper.resolveUrl(relative);
      expect(resolved, contains('/v1/rides/38d04d42-3072-49fb-9ed1-4a188d75a6b1/driver/photo'));
      expect(resolved, startsWith(BaseUrl.current));

      const absolute = 'https://custom-cdn.example.com/driver.png';
      expect(DriverAvatarHelper.resolveUrl(absolute), absolute);
      expect(DriverAvatarHelper.resolveUrl(null), isNull);
      expect(DriverAvatarHelper.resolveUrl(''), isNull);
    });

    testWidgets('DriverAvatarWidget renders initials fallback when photoUrl is null or empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverAvatarWidget(
              photoUrl: null,
              name: 'Abdoulaye Wade',
              size: 52,
              rideService: _FakeRideService(),
            ),
          ),
        ),
      );

      expect(find.text('AW'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('DriverAvatarWidget renders Image when photo bytes are fetched',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverAvatarWidget(
              photoUrl:
                  '/v1/rides/38d04d42-3072-49fb-9ed1-4a188d75a6b1/driver/photo?v=1794673375',
              name: 'Moussa Diop',
              size: 52,
              rideService: _FakeRideService(Uint8List.fromList([1, 2, 3])),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('ActiveDriverCardWidget uses DriverAvatarWidget with real driver photo or initials',
        (tester) async {
      final driverWithPhoto = DriverModel(
        id: 'drv_test',
        name: 'Modou Fall',
        phone: '+221 77 000 00 00',
        rating: 4.8,
        totalRides: 350,
        carModel: 'Toyota Corolla',
        carColor: 'Mauve',
        licensePlate: 'DK-9999-AB',
        rideType: RideType.eco,
        etaMinutes: 4,
        distanceKm: 1.2,
        currentLocation: const LatLng(14.69, -17.44),
        photoUrl:
            '/v1/rides/38d04d42-3072-49fb-9ed1-4a188d75a6b1/driver/photo?v=1794673375',
      );

      DriverAvatarHelper.setCached(
        driverWithPhoto.photoUrl!,
        Uint8List.fromList([0, 1, 2]),
      );

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: ActiveDriverCardWidget(
              driver: driverWithPhoto,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DriverAvatarWidget), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Modou Fall'), findsOneWidget);
    });
  });
}
