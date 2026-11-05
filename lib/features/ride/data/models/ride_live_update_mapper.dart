import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_model.dart';
import 'package:seddo/features/ride/domain/models/ride_live_update_data.dart';
import 'package:seddo/features/ride/presentation/utils/vehicle_color_helper.dart';

/// Mapper utility that transforms domain & data models (DriverModel, RideModel, status)
/// into a compact [RideLiveUpdateData] object for Live Activities & Live Updates.
class RideLiveUpdateMapper {
  /// Maps a driver and ride status into a [RideLiveUpdateData] payload.
  static RideLiveUpdateData fromRideAndDriver({
    required String rideId,
    required DriverModel driver,
    RideStatus? rideStatus,
    String? rawStatus,
    int? overrideEtaMinutes,
    double? overrideProgress,
    String? departureText,
    String? destinationText,
  }) {
    final statusString = (rawStatus ?? rideStatus?.name ?? '').toUpperCase();

    RideLiveUpdatePhase phase;
    String statusLabel;
    double progress;

    if (statusString.contains('CANCEL') || rideStatus == RideStatus.cancelled) {
      phase = RideLiveUpdatePhase.cancelled;
      statusLabel = 'Course annulée';
      progress = 0.0;
    } else if (statusString.contains('COMPLETE') || rideStatus == RideStatus.completed) {
      phase = RideLiveUpdatePhase.completed;
      statusLabel = 'Course terminée';
      progress = 1.0;
    } else if (statusString.contains('IN_PROGRESS') ||
        statusString.contains('PROGRESS') ||
        statusString.contains('STARTED') ||
        rideStatus == RideStatus.inProgress) {
      phase = RideLiveUpdatePhase.inProgress;
      statusLabel = 'En route vers destination';
      progress = overrideProgress ?? 0.05;
    } else if (statusString.contains('ARRIVED')) {
      phase = RideLiveUpdatePhase.driverArrived;
      statusLabel = 'Chauffeur arrivé au point de prise en charge';
      progress = overrideProgress ?? 1.0;
    } else if (statusString.contains('APPROACH') || (driver.etaMinutes > 0 && driver.etaMinutes <= 15)) {
      phase = RideLiveUpdatePhase.driverApproaching;
      statusLabel = 'Chauffeur en approche';
      // Progression continue de gauche (0.05) vers la droite (0.98)
      final eta = overrideEtaMinutes ?? driver.etaMinutes;
      final remainingRatio = (eta / 15.0).clamp(0.0, 1.0);
      progress = overrideProgress ?? ((1.0 - remainingRatio).clamp(0.05, 0.98));
    } else {
      phase = RideLiveUpdatePhase.driverAssigned;
      statusLabel = 'Chauffeur assigné';
      progress = overrideProgress ?? 0.05;
    }

    final eta = overrideEtaMinutes ?? driver.etaMinutes;

    // Standardize car color representation using VehicleColorHelper
    final color = VehicleColorHelper.parseColor(driver.carColor);
    final hexColor = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return RideLiveUpdateData(
      rideId: rideId,
      driverName: driver.name.isNotEmpty ? driver.name : 'Chauffeur Seddo',
      carModel: driver.carModel.isNotEmpty ? driver.carModel : 'Véhicule Seddo',
      carColor: driver.carColor.isNotEmpty ? driver.carColor : hexColor,
      licensePlate: driver.licensePlate.isNotEmpty ? driver.licensePlate : 'Seddo VTC',
      phase: phase,
      statusLabel: statusLabel,
      etaMinutes: eta,
      progress: progress.clamp(0.0, 1.0),
      departureText: departureText,
      destinationText: destinationText,
      updatedAtTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
