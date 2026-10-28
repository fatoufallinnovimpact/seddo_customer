import 'package:equatable/equatable.dart';

/// Modèle représentant la réponse de l'endpoint d'annulation de course :
/// POST /v1/rides/{id}/cancel
/// "Annulation. Client : gratuite avant acceptation et 2 min après, frais ensuite ; renvoie les frais et le montant remboursé."
class RideCancelResultModel extends Equatable {
  final bool isSuccess;
  final num fee;
  final num refundAmount;
  final String reason;
  final String status;
  final String? message;
  final Map<String, dynamic> raw;

  const RideCancelResultModel({
    required this.isSuccess,
    this.fee = 0,
    this.refundAmount = 0,
    this.reason = '',
    this.status = 'CANCELLED',
    this.message,
    this.raw = const {},
  });

  bool get isFree => fee == 0;

  factory RideCancelResultModel.fromJson(
    Map<String, dynamic> json, {
    String defaultReason = 'Le chauffeur est trop loin',
  }) {
    // 1. Extraction des frais d'annulation (fee, cancelFee, cancellationFee, fees)
    final dynamic rawFee = json['fee'] ??
        json['cancelFee'] ??
        json['cancellationFee'] ??
        json['fees'] ??
        (json['ride'] is Map ? json['ride']['cancelFee'] : null);
    final num parsedFee = rawFee is num
        ? rawFee
        : (num.tryParse(rawFee?.toString() ?? '') ?? 0);

    // 2. Extraction du montant remboursé (refundAmount, refundedAmount, amountRefunded, refund.amount)
    final dynamic rawRefund = json['refundAmount'] ??
        json['refundedAmount'] ??
        json['amountRefunded'] ??
        (json['refund'] is Map ? json['refund']['amount'] : null) ??
        (json['ride'] is Map ? json['ride']['refundAmount'] : null);
    final num parsedRefund = rawRefund is num
        ? rawRefund
        : (num.tryParse(rawRefund?.toString() ?? '') ?? 0);

    // 3. Raison d'annulation
    final String parsedReason = (json['reason'] ??
            (json['ride'] is Map ? json['ride']['cancellationReason'] : null) ??
            defaultReason)
        .toString();

    // 4. Statut de la course
    final String parsedStatus = (json['status'] ??
            (json['ride'] is Map ? json['ride']['status'] : null) ??
            'CANCELLED')
        .toString();

    return RideCancelResultModel(
      isSuccess: true,
      fee: parsedFee,
      refundAmount: parsedRefund,
      reason: parsedReason,
      status: parsedStatus,
      message: json['message']?.toString(),
      raw: json,
    );
  }

  factory RideCancelResultModel.fallback({
    required num originalPrice,
    String reason = 'Le chauffeur est trop loin',
  }) {
    return RideCancelResultModel(
      isSuccess: true,
      fee: 0,
      refundAmount: originalPrice,
      reason: reason,
      status: 'CANCELLED',
    );
  }

  @override
  List<Object?> get props => [
        isSuccess,
        fee,
        refundAmount,
        reason,
        status,
        message,
      ];
}
