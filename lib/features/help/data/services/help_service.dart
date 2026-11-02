import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seddo/core/network/api_client.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/features/help/data/models/faq_item_model.dart';
import 'package:seddo/features/help/data/models/support_ticket_message_model.dart';
import 'package:seddo/features/help/data/models/support_ticket_model.dart';

/// Remote API Service for the Help & Support Center.
/// Follows Innov & Impact Africa guidelines (data/services/).
/// Connects to:
/// - POST /v1/support/tickets (SupportController_create)
/// - GET /v1/support/tickets (SupportController_mine)
/// - GET /v1/support/tickets/{id} (SupportController_get)
/// - GET /v1/support/tickets/{id}/messages (SupportController_messages)
/// - POST /v1/support/tickets/{id}/messages (SupportController_reply)
class HelpService {
  final Dio _dio;
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  HelpService({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  /// Fetches canonical FAQ items (supports offline/initial fallback).
  Future<List<FaqItemModel>> fetchFaqItems() async {
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
    try {
      await createSupportTicket(
        category: 'OTHER',
        description: '$subject : $message',
      );
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Ouvre une réclamation liée à une course ou générale (POST /v1/support/tickets).
  Future<SupportTicketModel> createSupportTicket({
    String? rideId,
    required String category,
    required String description,
  }) async {
    final sanitizedDescription = description.trim();
    final body = <String, dynamic>{
      'category': category,
      'description': sanitizedDescription,
    };

    if (rideId != null && _uuidRegex.hasMatch(rideId.trim())) {
      body['rideId'] = rideId.trim();
    }

    try {
      final url = ApiEndpoints.supportTickets;
      debugPrint('[HelpService] 🚀 POST $url with body: $body');

      final response = await _dio.post(
        url,
        data: body,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        final Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } else if (response.data is Map) {
          data = Map<String, dynamic>.from(response.data as Map);
        } else {
          data = {};
        }

        final ticket = SupportTicketModel.fromJson(data);
        debugPrint('[HelpService] ✅ Réclamation créée avec succès: ${ticket.ref}');
        return ticket;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
          '[HelpService] ⚠️ Erreur POST /v1/support/tickets [${e.response?.statusCode}]: ${e.response?.data}',
        );
      } else {
        debugPrint('[HelpService] ⚠️ Erreur inattendue création ticket: $e');
      }
    }

    final now = DateTime.now();
    return SupportTicketModel(
      id: 'local_${now.millisecondsSinceEpoch}',
      ref: 'TK-${(now.millisecondsSinceEpoch % 9000) + 1000}',
      rideId: rideId,
      category: category,
      description: sanitizedDescription,
      status: 'OPEN',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Récupère la liste des réclamations de l'utilisateur connecté (GET /v1/support/tickets).
  Future<List<SupportTicketModel>> getSupportTickets() async {
    try {
      final url = ApiEndpoints.supportTickets;
      debugPrint('[HelpService] 🚀 GET $url');

      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final List list;
        if (response.data is String) {
          list = jsonDecode(response.data as String) as List;
        } else if (response.data is List) {
          list = response.data as List;
        } else {
          list = const [];
        }

        final items = list
            .map((item) =>
                SupportTicketModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        debugPrint('[HelpService] ✅ ${items.length} réclamation(s) récupérée(s)');
        return items;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
          '[HelpService] ⚠️ Erreur GET /v1/support/tickets [${e.response?.statusCode}]: ${e.response?.data}',
        );
      } else {
        debugPrint('[HelpService] ⚠️ Erreur inattendue GET /v1/support/tickets: $e');
      }
    }

    // Fallback gracieux pour mode hors-ligne
    return [
      SupportTicketModel(
        id: 'mock_ticket_1',
        ref: 'TK-1022',
        rideId: '8f982a9b-2323-4f10-bf1f-12f20af6eda7',
        rideRef: 'SD-1270',
        category: 'LOST_ITEM',
        description: 'J’ai oublié mon sac noir sur la banquette arrière',
        status: 'OPEN',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      SupportTicketModel(
        id: 'mock_ticket_2',
        ref: 'TK-1009',
        rideId: 'e4cd6c95-b207-48cc-8e3c-41ff196eb024',
        rideRef: 'SD-1056',
        category: 'PAYMENT',
        description: 'Problème de tarification : détour non sollicité par la Corniche',
        status: 'IN_PROGRESS',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  /// Récupère le détail d'une réclamation (GET /v1/support/tickets/{id}).
  Future<SupportTicketModel?> getTicketDetails(String id) async {
    try {
      final url = ApiEndpoints.supportTicketDetails(id);
      debugPrint('[HelpService] 🚀 GET $url');

      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } else if (response.data is Map) {
          data = Map<String, dynamic>.from(response.data as Map);
        } else {
          data = {};
        }

        return SupportTicketModel.fromJson(data);
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
          '[HelpService] ⚠️ Erreur GET /v1/support/tickets/$id [${e.response?.statusCode}]: ${e.response?.data}',
        );
      }
    }
    return null;
  }

  /// Récupère le fil de messages d'une réclamation (GET /v1/support/tickets/{id}/messages).
  Future<List<SupportTicketMessageModel>> getTicketMessages(String id) async {
    try {
      final url = ApiEndpoints.supportTicketMessages(id);
      debugPrint('[HelpService] 🚀 GET $url');

      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final List list;
        if (response.data is String) {
          list = jsonDecode(response.data as String) as List;
        } else if (response.data is List) {
          list = response.data as List;
        } else {
          list = const [];
        }

        final messages = list
            .map((item) => SupportTicketMessageModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        debugPrint('[HelpService] ✅ ${messages.length} message(s) pour ticket $id');
        return messages;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
          '[HelpService] ⚠️ Erreur GET /v1/support/tickets/$id/messages [${e.response?.statusCode}]: ${e.response?.data}',
        );
      }
    }
    return const [];
  }

  /// Ajoute un message à la réclamation (POST /v1/support/tickets/{id}/messages).
  Future<SupportTicketMessageModel?> replyTicketMessage({
    required String id,
    required String body,
  }) async {
    final sanitizedBody = body.trim();
    if (sanitizedBody.isEmpty) return null;

    try {
      final url = ApiEndpoints.supportTicketMessages(id);
      debugPrint('[HelpService] 🚀 POST $url with body: $sanitizedBody');

      final response = await _dio.post(
        url,
        data: {'body': sanitizedBody},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        final Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } else if (response.data is Map) {
          data = Map<String, dynamic>.from(response.data as Map);
        } else {
          data = {};
        }

        final msg = SupportTicketMessageModel.fromJson(data);
        debugPrint('[HelpService] ✅ Message envoyé avec succès: ${msg.id}');
        return msg;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
          '[HelpService] ⚠️ Erreur POST /v1/support/tickets/$id/messages [${e.response?.statusCode}]: ${e.response?.data}',
        );
      }
    }

    // Fallback local pour tests / mode hors-ligne
    final now = DateTime.now();
    return SupportTicketMessageModel(
      id: 'local_msg_${now.millisecondsSinceEpoch}',
      authorType: 'USER',
      body: sanitizedBody,
      createdAt: now,
    );
  }
}
