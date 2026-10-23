import 'dart:async';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/help/data/models/faq_item_model.dart';

/// Remote API Service for the Help Center.
/// Follows Innov & Impact Africa guidelines (data/services/).
/// Uses [BaseUrl.current] without hardcoding URLs.
class HelpService {
  final String _endpoint = '${BaseUrl.current}/api/v1/help';

  String get endpoint => _endpoint;

  /// Fetches canonical FAQ items (supports offline/initial fallback).
  Future<List<FaqItemModel>> fetchFaqItems() async {
    // In production: final res = await http.get(Uri.parse('$_endpoint/faq'));
    return const [
      FaqItemModel(
        id: 'faq_1',
        questionKey: 'help.faq_1_q',
        answerKey: 'help.faq_1_a',
      ),
      FaqItemModel(
        id: 'faq_2',
        questionKey: 'help.faq_2_q',
        answerKey: 'help.faq_2_a',
      ),
      FaqItemModel(
        id: 'faq_3',
        questionKey: 'help.faq_3_q',
        answerKey: 'help.faq_3_a',
      ),
    ];
  }

  /// Submits a support message or ticket to the backend.
  Future<bool> submitSupportTicket(String subject, String message) async {
    // In production: final res = await http.post(Uri.parse('$_endpoint/tickets'), body: ...);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }
}
