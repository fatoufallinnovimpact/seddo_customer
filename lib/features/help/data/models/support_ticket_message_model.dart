import 'package:equatable/equatable.dart';

/// Model representing a message in a support ticket thread.
/// Matches backend schema from GET /v1/support/tickets/{id}/messages
/// and POST /v1/support/tickets/{id}/messages.
class SupportTicketMessageModel extends Equatable {
  final String id;
  final String authorType;
  final String body;
  final DateTime? createdAt;

  const SupportTicketMessageModel({
    required this.id,
    required this.authorType,
    required this.body,
    this.createdAt,
  });

  bool get isUser => authorType.toUpperCase() == 'USER';

  String get formattedTime {
    if (createdAt == null) return '';
    final local = createdAt!.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get formattedDate {
    if (createdAt == null) return '';
    final local = createdAt!.toLocal();
    final now = DateTime.now();
    final diffDays = DateTime(now.year, now.month, now.day)
        .difference(DateTime(local.year, local.month, local.day))
        .inDays;

    final time = formattedTime;
    if (diffDays == 0) {
      return 'Aujourd\'hui · $time';
    } else if (diffDays == 1) {
      return 'Hier · $time';
    } else {
      const months = [
        'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
        'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
      ];
      final monthName = months[(local.month - 1) % 12];
      return '${local.day} $monthName · $time';
    }
  }

  factory SupportTicketMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketMessageModel(
      id: json['id']?.toString() ?? '',
      authorType: json['authorType']?.toString() ?? 'USER',
      body: json['body']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorType': authorType,
      'body': body,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, authorType, body, createdAt];
}
