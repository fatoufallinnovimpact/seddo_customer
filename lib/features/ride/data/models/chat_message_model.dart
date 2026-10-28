enum ChatSender { customer, driver }

/// Chat message model for driver-passenger communication.
/// Follows Innov & Impact Africa guidelines (data/models/).
class ChatMessageModel {
  final String id;
  final ChatSender sender;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  const ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.isRead = true,
  });

  /// Parse backend JSON according to OpenAPI spec (GET /v1/rides/{id}/messages)
  /// Handles { "body": "...", "sender": "customer|driver", "createdAt": "..." }
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final senderStr = (json['sender'] ??
            json['senderType'] ??
            json['from'] ??
            json['role'] ??
            '')
        .toString()
        .toLowerCase();
    final isCustomer = senderStr == 'customer' ||
        senderStr == 'passenger' ||
        senderStr == 'client' ||
        senderStr == 'user';
    final sender = isCustomer ? ChatSender.customer : ChatSender.driver;

    DateTime parsedTime;
    try {
      final rawTime = json['createdAt'] ??
          json['timestamp'] ??
          json['sentAt'] ??
          json['date'];
      if (rawTime is String) {
        parsedTime = DateTime.tryParse(rawTime) ?? DateTime.now();
      } else if (rawTime is int) {
        parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTime);
      } else {
        parsedTime = DateTime.now();
      }
    } catch (_) {
      parsedTime = DateTime.now();
    }

    return ChatMessageModel(
      id: (json['id'] ??
              json['_id'] ??
              'msg_${DateTime.now().millisecondsSinceEpoch}')
          .toString(),
      sender: sender,
      text: (json['body'] ?? json['text'] ?? json['message'] ?? '').toString(),
      timestamp: parsedTime,
      isRead: json['isRead'] ?? json['read'] ?? true,
    );
  }

  /// Serialize to backend JSON according to OpenAPI spec
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': text,
      'sender': sender == ChatSender.customer ? 'customer' : 'driver',
      'createdAt': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
