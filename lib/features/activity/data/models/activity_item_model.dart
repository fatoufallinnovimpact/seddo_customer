import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';

/// Type of icon displayed for past rides in Activity history.
enum ActivityRideIconType {
  car,
  airport,
  briefcase,
}

/// Model representing a single ride entry in the user's Activity page.
class ActivityRideItem extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final int price;
  final String priceText;
  final String status;
  final String dateTag;
  final String dateText;
  final String departureTime;
  final String arrivalTime;
  final String durationText;
  final String distanceText;
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final DriverModel driver;
  final String driverInitials;
  final String orangeRef;
  final bool isRecentWithMap;
  final bool isCancelled;
  final bool isRefunded;
  final ActivityRideIconType iconType;
  final List<LatLng> polylinePoints;

  const ActivityRideItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.priceText,
    required this.status,
    required this.dateTag,
    required this.dateText,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationText,
    required this.distanceText,
    required this.departure,
    required this.destination,
    required this.driver,
    required this.driverInitials,
    required this.orangeRef,
    this.isRecentWithMap = false,
    this.isCancelled = false,
    this.isRefunded = false,
    this.iconType = ActivityRideIconType.car,
    this.polylinePoints = const [],
  });

  RideOptionModel toRideOptionModel() {
    return RideOptionModel(
      type: RideType.eco,
      title: 'Seddo Eco',
      subtitle: '$arrivalTime · à $durationText',
      capacity: 4,
      price: price,
      estimatedArrival: arrivalTime,
      pickupDuration: durationText,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        subtitle,
        price,
        priceText,
        status,
        dateTag,
        dateText,
        departureTime,
        arrivalTime,
        durationText,
        distanceText,
        departure,
        destination,
        driver,
        driverInitials,
        orangeRef,
        isRecentWithMap,
        isCancelled,
        isRefunded,
        iconType,
        polylinePoints,
      ];
}

/// Model representing a refund entry in the user's Activity page.
class ActivityRefundItem extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final String amountText;
  final String status;
  final bool isPending;
  final ActivityRideItem? associatedRide;

  const ActivityRefundItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.status,
    this.isPending = false,
    this.associatedRide,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        subtitle,
        amountText,
        status,
        isPending,
        associatedRide,
      ];
}

/// Summary metrics model for the Activity page.
class ActivitySummary extends Equatable {
  final int paidRidesCount;
  final String totalSpentFormatted;
  final String totalRefundedFormatted;
  final String refundPaymentAccount;

  const ActivitySummary({
    required this.paidRidesCount,
    required this.totalSpentFormatted,
    required this.totalRefundedFormatted,
    required this.refundPaymentAccount,
  });

  @override
  List<Object?> get props => [
        paidRidesCount,
        totalSpentFormatted,
        totalRefundedFormatted,
        refundPaymentAccount,
      ];
}
