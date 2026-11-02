import 'package:flutter/foundation.dart';

/// Model representing a customer support claim / ticket.
/// Matches backend schema from SupportController (POST /v1/support/tickets, GET /v1/support/tickets).
@immutable
class SupportTicketModel {
  final String id;
  final String ref;
  final String? rideId;
  final String? rideRef;
  final String category;
  final String description;
  final String status;
  final String? resolution;
  final int? refundAmount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  const SupportTicketModel({
    required this.id,
    required this.ref,
    this.rideId,
    this.rideRef,
    required this.category,
    required this.description,
    required this.status,
    this.resolution,
    this.refundAmount,
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
  });

  String get categoryLabel {
    switch (category) {
      case 'LOST_ITEM':
        return 'Objet perdu';
      case 'DRIVER_BEHAVIOR':
        return 'Comportement chauffeur';
      case 'PAYMENT':
        return 'Montant ou paiement';
      case 'REFUND':
        return 'Remboursement';
      case 'CLIENT_BEHAVIOR':
        return 'Comportement client';
      case 'SAFETY':
        return 'Sécurité';
      case 'PRICE':
        return 'Tarification';
      case 'APP':
        return 'Application';
      default:
        return 'Réclamation';
    }
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return 'Ouverte';
      case 'IN_PROGRESS':
        return 'En cours';
      case 'RESOLVED':
        return 'Résolue';
      case 'CLOSED':
        return 'Fermée';
      default:
        return status;
    }
  }

  String get formattedDate {
    if (createdAt == null) return '';
    final local = createdAt!.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    final monthName = months[(local.month - 1) % 12];
    return '${local.day} $monthName · $h:$m';
  }

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: json['id']?.toString() ?? '',
      ref: json['ref']?.toString() ?? '',
      rideId: json['rideId']?.toString(),
      rideRef: json['rideRef']?.toString(),
      category: json['category']?.toString() ?? 'OTHER',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      resolution: json['resolution']?.toString(),
      refundAmount: json['refundAmount'] is num
          ? (json['refundAmount'] as num).toInt()
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ref': ref,
      if (rideId != null) 'rideId': rideId,
      if (rideRef != null) 'rideRef': rideRef,
      'category': category,
      'description': description,
      'status': status,
      if (resolution != null) 'resolution': resolution,
      if (refundAmount != null) 'refundAmount': refundAmount,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
    };
  }
}
