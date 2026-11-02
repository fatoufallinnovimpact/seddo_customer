import 'package:seddo/features/help/data/models/faq_item_model.dart';
import 'package:seddo/features/help/data/models/support_ticket_message_model.dart';
import 'package:seddo/features/help/data/models/support_ticket_model.dart';
import 'package:seddo/features/help/data/services/help_service.dart';

/// Repository for the Help & Support feature.
/// Handles business logic and data access between BLoC / UI and remote services.
/// Follows Innov & Impact Africa guidelines (data/repositories/).
class HelpRepository {
  final HelpService _service;

  HelpRepository({HelpService? service})
      : _service = service ?? HelpService();

  Future<List<FaqItemModel>> getFaqItems() {
    return _service.fetchFaqItems();
  }

  Future<bool> submitSupportTicket(String subject, String message) {
    return _service.submitSupportTicket(subject, message);
  }

  /// Ouvre une réclamation liée à une course ou générale (POST /v1/support/tickets).
  Future<SupportTicketModel> createSupportTicket({
    String? rideId,
    required String category,
    required String description,
  }) {
    return _service.createSupportTicket(
      rideId: rideId,
      category: category,
      description: description,
    );
  }

  /// Récupère l'historique des réclamations de l'utilisateur (GET /v1/support/tickets).
  Future<List<SupportTicketModel>> getSupportTickets() {
    return _service.getSupportTickets();
  }

  /// Récupère le détail d'une réclamation (GET /v1/support/tickets/{id}).
  Future<SupportTicketModel?> getTicketDetails(String id) {
    return _service.getTicketDetails(id);
  }

  /// Récupère les messages d'une réclamation (GET /v1/support/tickets/{id}/messages).
  Future<List<SupportTicketMessageModel>> getTicketMessages(String id) {
    return _service.getTicketMessages(id);
  }

  /// Ajoute un message à une réclamation (POST /v1/support/tickets/{id}/messages).
  Future<SupportTicketMessageModel?> replyTicketMessage({
    required String id,
    required String body,
  }) {
    return _service.replyTicketMessage(id: id, body: body);
  }
}
