import 'package:seddo/features/help/data/models/faq_item_model.dart';
import 'package:seddo/features/help/data/services/help_service.dart';

/// Repository for the Help feature.
/// Handles business logic and data access between BLoC and remote services.
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
}
