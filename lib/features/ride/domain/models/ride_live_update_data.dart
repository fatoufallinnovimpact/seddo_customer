import 'package:equatable/equatable.dart';

/// Enum representing the high-level phases of a ride for Live Activities / Updates.
enum RideLiveUpdatePhase {
  driverAssigned,
  driverApproaching,
  driverArrived,
  inProgress,
  completed,
  cancelled,
}

/// Domain model holding all the information needed to render
/// iOS Live Activities (Dynamic Island & Lock Screen) and
/// Android 16 Live Updates (ProgressStyle).
/// Kept under 4 KB for strict Apple ActivityKit compliance.
class RideLiveUpdateData extends Equatable {
  final String rideId;
  final String driverName;
  final String carModel;
  final String carColor;
  final String licensePlate;
  final RideLiveUpdatePhase phase;
  final String statusLabel;
  final int etaMinutes;
  /// Progress from 0.0 (just assigned) to 1.0 (completed)
  final double progress;
  final String? departureText;
  final String? destinationText;
  final int updatedAtTimestamp;

  const RideLiveUpdateData({
    required this.rideId,
    required this.driverName,
    required this.carModel,
    required this.carColor,
    required this.licensePlate,
    required this.phase,
    required this.statusLabel,
    required this.etaMinutes,
    required this.progress,
    this.departureText,
    this.destinationText,
    required this.updatedAtTimestamp,
  });

  /// Factory helper to build initial data
  factory RideLiveUpdateData.initial({
    required String rideId,
    required String driverName,
    required String carModel,
    required String carColor,
    required String licensePlate,
    int etaMinutes = 5,
    String? departureText,
    String? destinationText,
  }) {
    return RideLiveUpdateData(
      rideId: rideId,
      driverName: driverName,
      carModel: carModel,
      carColor: carColor,
      licensePlate: licensePlate,
      phase: RideLiveUpdatePhase.driverAssigned,
      statusLabel: 'Chauffeur assigné',
      etaMinutes: etaMinutes,
      progress: 0.15,
      departureText: departureText,
      destinationText: destinationText,
      updatedAtTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  RideLiveUpdateData copyWith({
    String? rideId,
    String? driverName,
    String? carModel,
    String? carColor,
    String? licensePlate,
    RideLiveUpdatePhase? phase,
    String? statusLabel,
    int? etaMinutes,
    double? progress,
    String? departureText,
    String? destinationText,
    int? updatedAtTimestamp,
  }) {
    return RideLiveUpdateData(
      rideId: rideId ?? this.rideId,
      driverName: driverName ?? this.driverName,
      carModel: carModel ?? this.carModel,
      carColor: carColor ?? this.carColor,
      licensePlate: licensePlate ?? this.licensePlate,
      phase: phase ?? this.phase,
      statusLabel: statusLabel ?? this.statusLabel,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      progress: (progress ?? this.progress).clamp(0.0, 1.0),
      departureText: departureText ?? this.departureText,
      destinationText: destinationText ?? this.destinationText,
      updatedAtTimestamp: updatedAtTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Converts the domain model into a map for native MethodChannel transfer
  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'driverName': driverName,
      'carModel': carModel,
      'carColor': carColor,
      'licensePlate': licensePlate,
      'phase': phase.name,
      'statusLabel': statusLabel,
      'etaMinutes': etaMinutes,
      'progress': progress,
      'departureText': departureText ?? '',
      'destinationText': destinationText ?? '',
      'updatedAtTimestamp': updatedAtTimestamp,
    };
  }

  factory RideLiveUpdateData.fromMap(Map<String, dynamic> map) {
    RideLiveUpdatePhase parsedPhase = RideLiveUpdatePhase.driverAssigned;
    final phaseStr = map['phase']?.toString() ?? '';
    for (final p in RideLiveUpdatePhase.values) {
      if (p.name == phaseStr) {
        parsedPhase = p;
        break;
      }
    }

    return RideLiveUpdateData(
      rideId: map['rideId']?.toString() ?? '',
      driverName: map['driverName']?.toString() ?? '',
      carModel: map['carModel']?.toString() ?? '',
      carColor: map['carColor']?.toString() ?? '',
      licensePlate: map['licensePlate']?.toString() ?? '',
      phase: parsedPhase,
      statusLabel: map['statusLabel']?.toString() ?? '',
      etaMinutes: (map['etaMinutes'] as num?)?.toInt() ?? 0,
      progress: ((map['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
      departureText: map['departureText']?.toString(),
      destinationText: map['destinationText']?.toString(),
      updatedAtTimestamp: (map['updatedAtTimestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  List<Object?> get props => [
        rideId,
        driverName,
        carModel,
        carColor,
        licensePlate,
        phase,
        statusLabel,
        etaMinutes,
        progress,
        departureText,
        destinationText,
        updatedAtTimestamp,
      ];
}
