import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/help/data/models/support_ticket_model.dart';
import 'package:seddo/features/help/data/repositories/help_repository.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/presentation/widgets/safety_incident_report_sheet.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_modal_widget.dart';
import '../../test_helpers/test_localization_helper.dart';

class MockHelpRepository extends HelpRepository {
  String? lastRideId;
  String? lastCategory;
  String? lastDescription;
  int submitCount = 0;

  @override
  Future<SupportTicketModel> createSupportTicket({
    String? rideId,
    required String category,
    required String description,
  }) async {
    lastRideId = rideId;
    lastCategory = category;
    lastDescription = description;
    submitCount++;

    return SupportTicketModel(
      id: 'mock_ticket_123',
      ref: 'TK-8899',
      rideId: rideId,
      category: category,
      description: description,
      status: 'OPEN',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testDestination = PlaceSearchResult(
    id: 'place_dest',
    mainText: 'Almadies, Dakar',
    secondaryText: 'Dakar, Sénégal',
    fullAddress: 'Almadies, Dakar, Sénégal',
    latitude: 14.7450,
    longitude: -17.5180,
  );

  const testDriver = DriverModel(
    id: 'driver_modou',
    name: 'Modou Diop',
    phone: '+221 77 555 12 34',
    rating: 4.9,
    totalRides: 320,
    carModel: 'Peugeot 301',
    carColor: 'Gris',
    licensePlate: 'DK-4455-AA',
    rideType: RideType.eco,
    currentLocation: LatLng(14.7000, -17.4600),
    etaMinutes: 4,
    distanceKm: 1.2,
  );

  setUpAll(() async {
    await initTestLocalization();
  });

  group('SafetyModalWidget Tests', () {
    testWidgets(
        'Renders emergency contacts, share position button, and report problem button',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const Scaffold(
            body: SafetyModalWidget(
              destination: testDestination,
              driver: testDriver,
              rideId: '4b3d8a1c-9123-4567-89ab-cdef01234567',
              currentPosition: LatLng(14.7123, -17.4789),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('SÉCURITÉ DU'), findsOneWidget);
      expect(find.text('Police'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('SAMU'), findsOneWidget);
      expect(find.text('1515'), findsOneWidget);
      expect(find.text('Partager ma position d\'urgence'), findsOneWidget);
      expect(find.text('Signaler un problème à Seddo'), findsOneWidget);
    });
  });

  group('SafetyIncidentReportSheet POST /v1/support/tickets Tests', () {
    testWidgets(
        'Submits report to POST /v1/support/tickets via HelpRepository with category, description and rideId',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      final mockRepo = MockHelpRepository();

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: SafetyIncidentReportSheet(
              driver: testDriver,
              rideId: '4b3d8a1c-9123-4567-89ab-cdef01234567',
              currentPosition: const LatLng(14.7123, -17.4789),
              helpRepository: mockRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and driver information
      expect(find.text('Signaler un incident'), findsOneWidget);
      expect(find.textContaining('Modou Diop'), findsOneWidget);

      // Select "Conduite dangereuse / Vitesse" chip
      final drivingChip = find.textContaining('Conduite dangereuse');
      expect(drivingChip, findsOneWidget);
      await tester.tap(drivingChip);
      await tester.pumpAndSettle();

      // Enter a descriptive comment
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(
          textField, 'Le chauffeur roule à plus de 100 km/h en ville.');
      await tester.pumpAndSettle();

      // Tap submit button "Transmettre le signalement"
      final submitButton = find.text('Transmettre le signalement');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify that createSupportTicket was called with correct data
      expect(mockRepo.submitCount, 1);
      expect(mockRepo.lastRideId, '4b3d8a1c-9123-4567-89ab-cdef01234567');
      expect(mockRepo.lastCategory, 'SAFETY');
      expect(
          mockRepo.lastDescription,
          contains(
              'Détails : Le chauffeur roule à plus de 100 km/h en ville.'));
      expect(
          mockRepo.lastDescription, contains('Conduite dangereuse'));

      // Check success SnackBar containing the ticket reference
      expect(find.textContaining('TK-8899'), findsOneWidget);
    });

    testWidgets(
        'Maps price reason to PRICE category when submitting support ticket',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      final mockRepo = MockHelpRepository();

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: SafetyIncidentReportSheet(
              driver: testDriver,
              rideId: '4b3d8a1c-9123-4567-89ab-cdef01234567',
              helpRepository: mockRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select "Désaccord sur le tarif"
      final priceChip = find.textContaining('Désaccord sur le tarif');
      expect(priceChip, findsOneWidget);
      await tester.tap(priceChip);
      await tester.pumpAndSettle();

      // Tap submit button
      final submitButton = find.text('Transmettre le signalement');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(mockRepo.submitCount, 1);
      expect(mockRepo.lastCategory, 'PRICE');
      expect(mockRepo.lastDescription, contains('Désaccord sur le tarif'));
    });
  });
}
