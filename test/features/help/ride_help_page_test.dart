import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/help/data/models/support_ticket_model.dart';
import 'package:seddo/features/help/data/repositories/help_repository.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/presentation/pages/ride_help_page.dart';
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
      id: 'mock_ticket_1',
      ref: 'TK-1022',
      rideId: rideId,
      rideRef: 'SD-1270',
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

  setUpAll(() async {
    await initTestLocalization();
  });

  group('RideHelpPage Support Ticket Tests', () {
    testWidgets(
        'Renders support form, selects category, appends quick tag, and submits to POST /v1/support/tickets',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final mockRepo = MockHelpRepository();

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: RideHelpPage(
            rideId: '8f982a9b-2323-4f10-bf1f-12f20af6eda7',
            rideRef: 'SD-1270',
            destination: const PlaceSearchResult(
              id: 'dest_1',
              mainText: 'Almadies',
              secondaryText: 'Dakar',
              fullAddress: 'Almadies, Dakar',
              latitude: 14.7431,
              longitude: -17.5186,
            ),
            priceText: '3 500 F',
            dateText: '15 avr. · Course terminée',
            helpRepository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify headers and summary
      expect(find.text('Aide sur cette course'), findsOneWidget);
      expect(find.text('Almadies'), findsOneWidget);
      expect(find.text('3 500 F'), findsOneWidget);
      expect(find.text('15 avr. · Course terminée · Réf. SD-1270'), findsOneWidget);

      // 2. Verify 4 issue options
      expect(find.text("J'ai oublié un objet"), findsOneWidget);
      expect(find.text("Le trajet ne s'est pas bien passé"), findsOneWidget);
      expect(find.text('Montant ou paiement'), findsOneWidget);
      expect(find.text('Remboursement non reçu'), findsOneWidget);

      // 3. Select "J'ai oublié un objet"
      await tester.tap(find.text("J'ai oublié un objet"));
      await tester.pumpAndSettle();

      // Quick tags adapted for lost item
      expect(find.text('Sac oublié'), findsOneWidget);
      expect(find.text('Téléphone'), findsOneWidget);

      // Tap tag "Sac oublié"
      await tester.tap(find.text('Sac oublié'));
      await tester.pumpAndSettle();

      // 4. Submit support ticket
      final submitBtn = find.text('Envoyer au support');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pump();

      // Verify repository was called with correct parameters
      expect(mockRepo.submitCount, 1);
      expect(mockRepo.lastRideId, '8f982a9b-2323-4f10-bf1f-12f20af6eda7');
      expect(mockRepo.lastCategory, 'LOST_ITEM');
      expect(mockRepo.lastDescription, contains('Sac oublié'));

      // Verify success snackbar with ticket reference TK-1022
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('TK-1022'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 800));
    });

    testWidgets('Validates description min length before sending ticket',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final mockRepo = MockHelpRepository();

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: RideHelpPage(
            rideId: '8f982a9b-2323-4f10-bf1f-12f20af6eda7',
            helpRepository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear text field to < 5 chars
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hi');
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Envoyer au support'));
      await tester.pump();

      // Repo should NOT be called
      expect(mockRepo.submitCount, 0);

      // Warning snackbar shown
      expect(
        find.text('Veuillez préciser votre demande (au moins 5 caractères)'),
        findsOneWidget,
      );
    });
  });
}
