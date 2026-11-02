import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/help/data/models/support_ticket_message_model.dart';
import 'package:seddo/features/help/data/models/support_ticket_model.dart';
import 'package:seddo/features/help/data/repositories/help_repository.dart';
import 'package:seddo/features/help/presentation/pages/support_ticket_detail_page.dart';
import 'package:seddo/features/help/presentation/pages/support_tickets_page.dart';
import '../../test_helpers/test_localization_helper.dart';

class MockHelpRepositoryForFlow extends HelpRepository {
  String? lastRepliedTicketId;
  String? lastRepliedBody;
  int replyCallCount = 0;

  final List<SupportTicketModel> mockTickets = [
    SupportTicketModel(
      id: 'ticket_1',
      ref: 'TK-1024',
      rideId: '8f982a9b-2323-4f10-bf1f-12f20af6eda7',
      rideRef: 'SD-1270',
      category: 'LOST_ITEM',
      description: 'J’ai oublié mon sac noir sur la banquette arrière',
      status: 'OPEN',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    SupportTicketModel(
      id: 'ticket_2',
      ref: 'TK-1009',
      rideId: 'e4cd6c95-b207-48cc-8e3c-41ff196eb024',
      rideRef: 'SD-1056',
      category: 'PAYMENT',
      description: 'Détour non prévu et montant débité en double',
      status: 'IN_PROGRESS',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<SupportTicketMessageModel> mockMessages = [
    SupportTicketMessageModel(
      id: 'msg_1',
      authorType: 'USER',
      body: 'Bonjour, avez-vous des nouvelles du chauffeur svp ?',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    SupportTicketMessageModel(
      id: 'msg_2',
      authorType: 'SUPPORT',
      body: 'Bonjour, nous avons contacté Moussa Diop qui vérifie son véhicule.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
  ];

  @override
  Future<List<SupportTicketModel>> getSupportTickets() async {
    return mockTickets;
  }

  @override
  Future<SupportTicketModel?> getTicketDetails(String id) async {
    return mockTickets.firstWhere((t) => t.id == id);
  }

  @override
  Future<List<SupportTicketMessageModel>> getTicketMessages(String id) async {
    return mockMessages;
  }

  @override
  Future<SupportTicketMessageModel?> replyTicketMessage({
    required String id,
    required String body,
  }) async {
    lastRepliedTicketId = id;
    lastRepliedBody = body;
    replyCallCount++;

    return SupportTicketMessageModel(
      id: 'msg_new_$replyCallCount',
      authorType: 'USER',
      body: body,
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('Support Tickets & Messaging Flow Tests', () {
    testWidgets(
        'SupportTicketsPage renders claims list and navigates to SupportTicketDetailPage',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final mockRepo = MockHelpRepositoryForFlow();

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: SupportTicketsPage(
            helpRepository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar
      expect(find.text('Mes réclamations'), findsOneWidget);
      expect(find.text('Assistance prioritaire client'), findsOneWidget);

      // Filter tabs are present
      expect(find.text('Toutes'), findsOneWidget);
      expect(find.text('En attente'), findsOneWidget);
      expect(find.text('Résolues'), findsOneWidget);

      // List of tickets from GET /v1/support/tickets
      expect(find.text('#TK-1024'), findsOneWidget);
      expect(find.text('Objet perdu'), findsOneWidget);
      expect(find.text('OUVERT'), findsOneWidget);
      expect(find.textContaining('Course SD-1270'), findsOneWidget);
      expect(
        find.text('J’ai oublié mon sac noir sur la banquette arrière'),
        findsOneWidget,
      );

      expect(find.text('#TK-1009'), findsOneWidget);
      expect(find.text('Montant ou paiement'), findsOneWidget);
      expect(find.text('EN COURS'), findsOneWidget);

      // Tap on ticket #TK-1024 to open modal sheet detail
      await tester.tap(find.text('#TK-1024'));
      await tester.pumpAndSettle();

      // Detail bottom sheet is opened
      expect(find.byType(SupportTicketDetailPage), findsOneWidget);
      expect(find.text('ENREGISTRÉ'), findsOneWidget);
      expect(find.text('EXAMEN EN COURS'), findsOneWidget);
      expect(find.text('RÉSOLU'), findsOneWidget);

      // Thread messages are visible
      expect(
        find.text('Bonjour, avez-vous des nouvelles du chauffeur svp ?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Bonjour, nous avons contacté Moussa Diop qui vérifie son véhicule.',
        ),
        findsOneWidget,
      );

      // Reply input is rendered
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);

      // Enter a reply
      await tester.enterText(inputFinder, 'Toujours pas de remboursement reçu');
      await tester.pumpAndSettle();

      // Tap send button (Icons.send_rounded)
      final sendBtnFinder = find.byIcon(Icons.send_rounded);
      expect(sendBtnFinder, findsOneWidget);
      await tester.tap(sendBtnFinder);
      await tester.pumpAndSettle();

      // Verified POST /v1/support/tickets/{id}/messages called
      expect(mockRepo.replyCallCount, 1);
      expect(mockRepo.lastRepliedTicketId, 'ticket_1');
      expect(mockRepo.lastRepliedBody, 'Toujours pas de remboursement reçu');

      // The new message is displayed in thread
      expect(
        find.text('Toujours pas de remboursement reçu'),
        findsOneWidget,
      );

      // Close modal sheet back to tickets list
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SupportTicketsPage), findsOneWidget);
    });

    testWidgets(
        'SupportTicketsPage paginates 10 tickets per page and loads next on scroll to bottom',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final mockRepo = MockHelpRepositoryForFlow();
      // Generate 15 tickets to test pagination by 10
      mockRepo.mockTickets.clear();
      for (int i = 1; i <= 15; i++) {
        mockRepo.mockTickets.add(
          SupportTicketModel(
            id: 'ticket_$i',
            ref: 'TK-10$i',
            category: 'OTHER',
            description: 'Réclamation test numéro $i',
            status: 'OPEN',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: SupportTicketsPage(
            helpRepository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only first 10 tickets are initially loaded into the displayed list
      expect(find.text('#TK-101'), findsOneWidget);
      expect(find.text('#TK-1011'), findsNothing);

      // Scroll down to trigger pagination and load next batch
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Scroll until ticket 15 is in view
      await tester.scrollUntilVisible(
        find.text('#TK-1015'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('#TK-1015'), findsOneWidget);
    });
  });
}
