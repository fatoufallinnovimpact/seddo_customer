import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/services/route_service.dart';

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
  final DriverModel? driver;
  final String? driverInitials;
  final String orangeRef;
  final String category;
  final bool isRecentWithMap;
  final bool isCancelled;
  final bool isRefunded;
  final ActivityRideIconType iconType;
  final List<LatLng> polylinePoints;
  final List<TrafficSegmentModel> trafficSegments;
  final String? startCode;
  final String? paymentMethod;
  final String? paymentPhone;
  final String? paymentStatus;
  final DateTime? createdAt;

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
    this.driver,
    this.driverInitials,
    required this.orangeRef,
    this.category = 'ECO',
    this.isRecentWithMap = false,
    this.isCancelled = false,
    this.isRefunded = false,
    this.iconType = ActivityRideIconType.car,
    this.polylinePoints = const [],
    this.trafficSegments = const [],
    this.startCode,
    this.paymentMethod,
    this.paymentPhone,
    this.paymentStatus,
    this.createdAt,
  });

  String get categoryLabel =>
      category.toUpperCase() == 'CONFORT' ? 'Seddo Confort' : 'Seddo Éco';

  RideOptionModel toRideOptionModel() {
    final isConfort = category.toUpperCase() == 'CONFORT';
    return RideOptionModel(
      type: isConfort ? RideType.confort : RideType.eco,
      title: isConfort ? 'Seddo Confort' : 'Seddo Éco',
      subtitle: '$arrivalTime · à $durationText',
      capacity: 4,
      price: price,
      estimatedArrival: arrivalTime,
      pickupDuration: durationText,
    );
  }

  /// Format an integer price with spaces (e.g. 1750 -> '1 750 F')
  static String formatPrice(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} F';
  }

  /// Parses an item returned by GET /v1/rides (RidesController_history)
  factory ActivityRideItem.fromBackendSummary(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final ref = (json['ref'] ?? 'SD-1000').toString();
    final rawStatus = (json['status'] ?? '').toString().toUpperCase();
    final category = (json['category'] ?? 'ECO').toString().toUpperCase();
    final price = (json['price'] as num?)?.toInt() ?? 0;
    final distanceM = (json['distanceM'] as num?)?.toInt() ?? 0;

    final isCancelled = rawStatus.contains('CANCEL');
    final isRefunded = json['refund'] != null && json['refund'] != false;

    String statusText;
    if (rawStatus.contains('CANCEL')) {
      statusText = 'Annulée';
    } else if (rawStatus == 'NO_DRIVER') {
      statusText = 'Sans chauffeur';
    } else if (rawStatus == 'PAYMENT_FAILED') {
      statusText = 'Échec';
    } else if (rawStatus == 'COMPLETED') {
      statusText = 'Terminée';
    } else if (rawStatus == 'IN_PROGRESS' || rawStatus == 'TRIP') {
      statusText = 'En cours';
    } else if (rawStatus == 'PENDING') {
      statusText = 'En attente';
    } else if (isRefunded) {
      statusText = 'Remboursée';
    } else {
      statusText = 'Terminée';
    }

    // Date & Time formatting
    DateTime? created;
    if (json['createdAt'] != null) {
      created = DateTime.tryParse(json['createdAt'].toString());
    }
    final now = DateTime.now();
    String dateText = 'Aujourd\'hui';
    String timeStr = '12:00';
    if (created != null) {
      final local = created.toLocal();
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      timeStr = '$h:$m';

      final diffDays = DateTime(now.year, now.month, now.day)
          .difference(DateTime(local.year, local.month, local.day))
          .inDays;
      if (diffDays == 0) {
        dateText = 'Aujourd\'hui';
      } else if (diffDays == 1) {
        dateText = 'Hier';
      } else {
        const months = [
          'janv.',
          'févr.',
          'mars',
          'avr.',
          'mai',
          'juin',
          'juil.',
          'août',
          'sept.',
          'oct.',
          'nov.',
          'déc.'
        ];
        const days = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
        final dayName = days[(local.weekday - 1) % 7];
        final monthName = months[(local.month - 1) % 12];
        dateText = '$dayName ${local.day} $monthName';
      }
    }
    final dateTag = '$dateText · $timeStr';

    // Distance and Duration text
    final distanceText = distanceM >= 1000
        ? '${(distanceM / 1000.0).toStringAsFixed(1).replaceAll('.', ',')} km'
        : '$distanceM m';
    final approxMinutes = (distanceM / 400).round().clamp(5, 60);
    final durationText = '$approxMinutes min';

    // Departure and Destination
    final pickupRaw = (json['pickupAddress'] ?? 'Dakar, Sénégal').toString();
    final dropoffRaw = (json['dropoffAddress'] ?? 'Almadies').toString();
    final pickupMain = pickupRaw.split(',').first.trim();
    final dropoffMain = dropoffRaw.split(',').first.trim();

    final departure = PlaceSearchResult(
      id: 'pickup_$id',
      mainText: pickupMain.isNotEmpty ? pickupMain : 'Départ',
      secondaryText: pickupRaw,
      fullAddress: pickupRaw,
      latitude: 14.6937,
      longitude: -17.4647,
    );
    final destination = PlaceSearchResult(
      id: 'dropoff_$id',
      mainText: dropoffMain.isNotEmpty ? dropoffMain : 'Destination',
      secondaryText: dropoffRaw,
      fullAddress: dropoffRaw,
      latitude: 14.7431,
      longitude: -17.5186,
    );

    // Icon type
    ActivityRideIconType iconType = ActivityRideIconType.car;
    final lowerDest = dropoffRaw.toLowerCase();
    if (lowerDest.contains('aéroport') || lowerDest.contains('aibd')) {
      iconType = ActivityRideIconType.airport;
    } else if (lowerDest.contains('plateau') ||
        lowerDest.contains('carnot') ||
        lowerDest.contains('bureau') ||
        lowerDest.contains('immeuble')) {
      iconType = ActivityRideIconType.briefcase;
    }

    DriverModel? driver;
    String? driverInitials;
    if (json['driver'] is Map && json['driver'] != null) {
      final driverMap = json['driver'] as Map;
      final vehicleMap =
          driverMap['vehicle'] is Map ? driverMap['vehicle'] as Map : null;
      final firstName = (driverMap['firstName'] ?? '').toString().trim();
      final lastName = (driverMap['lastName'] ?? '').toString().trim();
      final dName = '$firstName $lastName'.trim();
      if (dName.isNotEmpty) {
        if (firstName.isNotEmpty) {
          final fChar = firstName[0].toUpperCase();
          final lChar = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
          driverInitials = '$fChar$lChar';
        }
        driver = DriverModel(
          id: 'driver_${json['id']}',
          name: dName,
          phone: (driverMap['phone'] ?? '').toString(),
          rating: (driverMap['rating'] as num?)?.toDouble() ?? 4.8,
          totalRides: 450,
          carModel: (vehicleMap?['model'] != null && vehicleMap?['make'] != null)
              ? '${vehicleMap!['make']} ${vehicleMap['model']}'
              : 'Toyota Corolla',
          carColor: (vehicleMap?['color'] ?? '').toString(),
          licensePlate: (vehicleMap?['plate'] ?? '').toString(),
          rideType: category == 'CONFORT' ? RideType.confort : RideType.eco,
          currentLocation: const LatLng(14.6937, -17.4647),
          etaMinutes: 3,
          distanceKm: 1.2,
        );
      }
    }

    String subtitle;
    if (isCancelled) {
      subtitle = '$dateText · $timeStr · Annulée';
    } else if (rawStatus == 'NO_DRIVER') {
      subtitle = '$dateText · $timeStr · Sans chauffeur';
    } else if (driver != null) {
      subtitle = '${driver.name} · $distanceText';
    } else {
      subtitle = '$dateText · $timeStr · $distanceText';
    }

    return ActivityRideItem(
      id: id,
      title: dropoffMain.isNotEmpty ? dropoffMain : 'Course Seddo',
      subtitle: subtitle,
      price: price,
      priceText: formatPrice(price),
      status: statusText,
      dateTag: dateTag,
      dateText: dateText,
      departureTime: timeStr,
      arrivalTime: timeStr,
      durationText: durationText,
      distanceText: distanceText,
      departure: departure,
      destination: destination,
      driver: driver,
      driverInitials: driverInitials,
      orangeRef: ref,
      category: category,
      isCancelled: isCancelled,
      isRefunded: isRefunded,
      iconType: iconType,
      createdAt: created,
    );
  }

  /// Parses detailed ride returned by GET /v1/rides/{id} (RidesController_get)
  factory ActivityRideItem.fromBackendDetail(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final ref = (json['ref'] ?? 'SD-1000').toString();
    final rawStatus = (json['status'] ?? '').toString().toUpperCase();
    final category = (json['category'] ?? 'ECO').toString().toUpperCase();
    final price = (json['price'] as num?)?.toInt() ?? 0;
    final distanceM = (json['distanceM'] as num?)?.toInt() ?? 0;
    final durationS = (json['durationS'] as num?)?.toInt() ?? 0;
    final startCode = json['startCode']?.toString();

    final isCancelled = rawStatus.contains('CANCEL');
    final isRefunded = json['refund'] != null && json['refund'] != false;

    String statusText;
    if (rawStatus.contains('CANCEL')) {
      statusText = 'Annulée';
    } else if (rawStatus == 'NO_DRIVER') {
      statusText = 'Sans chauffeur';
    } else if (rawStatus == 'PAYMENT_FAILED') {
      statusText = 'Échec';
    } else if (rawStatus == 'COMPLETED') {
      statusText = 'Terminée';
    } else if (rawStatus == 'IN_PROGRESS' || rawStatus == 'TRIP') {
      statusText = 'En cours';
    } else if (rawStatus == 'PENDING') {
      statusText = 'En attente';
    } else if (isRefunded) {
      statusText = 'Remboursée';
    } else {
      statusText = 'Terminée';
    }

    // Parse pickup and dropoff with real coordinates
    final pickupMap = json['pickup'] is Map ? json['pickup'] as Map : null;
    final dropoffMap = json['dropoff'] is Map ? json['dropoff'] as Map : null;

    final pickupLat = (pickupMap?['lat'] as num?)?.toDouble() ?? 14.6788;
    final pickupLng = (pickupMap?['lng'] as num?)?.toDouble() ?? -17.4631;
    final pickupAddr = (pickupMap?['address'] ?? 'Dakar, Sénégal').toString();

    final dropoffLat = (dropoffMap?['lat'] as num?)?.toDouble() ?? 14.7449;
    final dropoffLng = (dropoffMap?['lng'] as num?)?.toDouble() ?? -17.5107;
    final dropoffAddr = (dropoffMap?['address'] ?? 'Almadies').toString();

    final pickupMain = pickupAddr.split(',').first.trim();
    final dropoffMain = dropoffAddr.split(',').first.trim();

    final departure = PlaceSearchResult(
      id: 'pickup_$id',
      mainText: pickupMain.isNotEmpty ? pickupMain : 'Départ',
      secondaryText: pickupAddr,
      fullAddress: pickupAddr,
      latitude: pickupLat,
      longitude: pickupLng,
    );
    final destination = PlaceSearchResult(
      id: 'dropoff_$id',
      mainText: dropoffMain.isNotEmpty ? dropoffMain : 'Destination',
      secondaryText: dropoffAddr,
      fullAddress: dropoffAddr,
      latitude: dropoffLat,
      longitude: dropoffLng,
    );

    // Parse Polyline & Traffic conditions
    final polylineStr = json['plannedPolyline'] as String? ??
        (json['route'] is Map ? (json['route']['polyline'] as String?) : null);
    List<LatLng> polylinePoints = const [];
    if (polylineStr != null && polylineStr.isNotEmpty) {
      polylinePoints = RouteService.decodePolyline(polylineStr);
    }

    final trafficRaw = json['plannedTraffic'] as List? ??
        (json['route'] is Map ? (json['route']['traffic'] as List?) : null);
    List<TrafficSegmentModel> trafficSegments = const [];
    if (trafficRaw != null && trafficRaw.isNotEmpty) {
      trafficSegments = trafficRaw
          .map((t) => TrafficSegmentModel.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
    }

    // Parse Driver details
    DriverModel? driver;
    String? driverInitials;
    final driverMap = json['driver'] is Map ? json['driver'] as Map : null;
    if (driverMap != null) {
      final vehicleMap =
          driverMap['vehicle'] is Map ? driverMap['vehicle'] as Map : null;

      final firstName = (driverMap['firstName'] ?? '').toString().trim();
      final lastName = (driverMap['lastName'] ?? '').toString().trim();
      final dName = '$firstName $lastName'.trim();

      if (dName.isNotEmpty) {
        if (firstName.isNotEmpty) {
          final fChar = firstName[0].toUpperCase();
          final lChar = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
          driverInitials = '$fChar$lChar';
        }

        final carModel =
            (vehicleMap?['model'] != null && vehicleMap?['make'] != null)
                ? '${vehicleMap!['make']} ${vehicleMap['model']}'
                : 'Toyota Corolla';
        final carColor = (vehicleMap?['color'] ?? 'Gris argent').toString();
        final licensePlate = (vehicleMap?['plate'] ?? 'DK 3453 BC').toString();
        final rating = (driverMap['rating'] as num?)?.toDouble() ?? 4.9;

        driver = DriverModel(
          id: 'driver_$id',
          name: dName,
          phone: (driverMap['phone'] ?? '+221 77 123 45 67').toString(),
          rating: rating,
          totalRides: 480,
          carModel: carModel,
          carColor: carColor,
          licensePlate: licensePlate,
          rideType: category == 'CONFORT' ? RideType.confort : RideType.eco,
          currentLocation: LatLng(pickupLat, pickupLng),
          etaMinutes: 3,
          distanceKm: 1.2,
        );
      }
    }

    // Date & Time formatting
    DateTime? created;
    if (json['createdAt'] != null) {
      created = DateTime.tryParse(json['createdAt'].toString());
    }
    final now = DateTime.now();
    String dateText = 'Aujourd\'hui';
    String timeStr = '18:19';
    if (created != null) {
      final local = created.toLocal();
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      timeStr = '$h:$m';

      final diffDays = DateTime(now.year, now.month, now.day)
          .difference(DateTime(local.year, local.month, local.day))
          .inDays;
      if (diffDays == 0) {
        dateText = 'Aujourd\'hui';
      } else if (diffDays == 1) {
        dateText = 'Hier';
      } else {
        const months = [
          'janv.',
          'févr.',
          'mars',
          'avr.',
          'mai',
          'juin',
          'juil.',
          'août',
          'sept.',
          'oct.',
          'nov.',
          'déc.'
        ];
        const days = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
        final dayName = days[(local.weekday - 1) % 7];
        final monthName = months[(local.month - 1) % 12];
        dateText = '$dayName ${local.day} $monthName';
      }
    }
    final dateTag = '$dateText · $timeStr';

    final distanceText = distanceM >= 1000
        ? '${(distanceM / 1000.0).toStringAsFixed(1).replaceAll('.', ',')} km'
        : '$distanceM m';
    final durationMinutes = durationS > 0
        ? (durationS / 60).round()
        : (distanceM / 400).round().clamp(5, 60);
    final durationText = '$durationMinutes min';

    // Payment details
    final paymentMap = json['payment'] is Map ? json['payment'] as Map : null;
    final paymentMethod = paymentMap?['method']?.toString();
    final paymentStatus = paymentMap?['status']?.toString();

    String subtitle;
    if (driver != null) {
      subtitle = '${driver.name} · $distanceText';
    } else if (isCancelled) {
      subtitle = '$dateText · $timeStr · Annulée';
    } else if (rawStatus == 'NO_DRIVER') {
      subtitle = '$dateText · $timeStr · Sans chauffeur';
    } else {
      subtitle = '$dateText · $timeStr · $distanceText';
    }

    return ActivityRideItem(
      id: id,
      title: dropoffMain.isNotEmpty ? dropoffMain : 'Almadies',
      subtitle: subtitle,
      price: price,
      priceText: formatPrice(price),
      status: statusText,
      dateTag: dateTag,
      dateText: dateText,
      departureTime: timeStr,
      arrivalTime: timeStr,
      durationText: durationText,
      distanceText: distanceText,
      departure: departure,
      destination: destination,
      driver: driver,
      driverInitials: driverInitials,
      orangeRef: ref,
      category: category,
      isRecentWithMap: true,
      isCancelled: isCancelled,
      isRefunded: isRefunded,
      iconType: ActivityRideIconType.car,
      polylinePoints: polylinePoints,
      trafficSegments: trafficSegments,
      startCode: startCode,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      createdAt: created,
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
        category,
        isRecentWithMap,
        isCancelled,
        isRefunded,
        iconType,
        polylinePoints,
        trafficSegments,
        startCode,
        paymentMethod,
        paymentPhone,
        paymentStatus,
        createdAt,
      ];
}

/// Model representing a refund entry in the user's Activity page.
/// Connects to GET /v1/users/me/refunds (UsersController_refunds).
class ActivityRefundItem extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final String amountText;
  final String status;
  final bool isPending;
  final ActivityRideItem? associatedRide;
  final String? rideId;
  final String? rideRef;
  final String? providerRef;
  final int? amount;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? paidAt;

  const ActivityRefundItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.status,
    this.isPending = false,
    this.associatedRide,
    this.rideId,
    this.rideRef,
    this.providerRef,
    this.amount,
    this.reason,
    this.createdAt,
    this.paidAt,
  });

  /// Factory constructor parsing response from GET /v1/users/me/refunds
  factory ActivityRefundItem.fromBackend(
    Map<String, dynamic> json, {
    ActivityRideItem? associatedRide,
  }) {
    final id = json['id']?.toString() ?? '';
    final rideId = json['rideId']?.toString();
    final rideRef = json['rideRef']?.toString() ?? '';
    final amount = (json['amount'] as num?)?.toInt() ?? 0;
    final rawStatus = (json['status'] ?? 'SUCCESS').toString().toUpperCase();
    final isPending = rawStatus == 'PENDING' || rawStatus == 'PROCESSING';
    final providerRef = json['providerRef']?.toString();
    final reason = json['reason']?.toString() ?? '';

    DateTime? created;
    if (json['createdAt'] != null) {
      created = DateTime.tryParse(json['createdAt'].toString());
    }

    DateTime? paid;
    if (json['paidAt'] != null) {
      paid = DateTime.tryParse(json['paidAt'].toString());
    }

    String dateStr = '';
    if (created != null) {
      final local = created.toLocal();
      const months = [
        'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
        'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
      ];
      final monthName = months[(local.month - 1) % 12];
      dateStr = '${local.day} $monthName';
    }

    // Title: use associated ride title if available, otherwise ride reference
    String title = 'Course remboursée';
    if (associatedRide != null && associatedRide.title.isNotEmpty) {
      title = associatedRide.title;
    } else if (rideRef.isNotEmpty) {
      title = 'Course $rideRef';
    }

    // Reason description
    String reasonLabel = 'Course annulée';
    switch (reason) {
      case 'CANCELLED_BY_CLIENT':
        reasonLabel = 'Annulée par vous';
        break;
      case 'NO_DRIVER':
        reasonLabel = 'Aucun chauffeur';
        break;
      case 'NO_SHOW':
        reasonLabel = 'Absence chauffeur';
        break;
      case 'NETWORK':
        reasonLabel = 'Incident réseau';
        break;
      case 'INTOUCH_DEPOSIT_NOT_CONFIGURED':
        reasonLabel = 'Dépôt en attente';
        break;
      default:
        reasonLabel = 'Course annulée';
    }

    // Subtitle includes date, reason, and Orange provider reference if present
    String subtitle;
    if (providerRef != null && providerRef.isNotEmpty) {
      subtitle = dateStr.isNotEmpty
          ? '$dateStr · $reasonLabel · Réf. $providerRef'
          : '$reasonLabel · Réf. $providerRef';
    } else {
      subtitle = dateStr.isNotEmpty ? '$dateStr · $reasonLabel' : reasonLabel;
    }

    String statusText;
    switch (rawStatus) {
      case 'SUCCESS':
        statusText = 'Remboursée';
        break;
      case 'FAILED':
        statusText = 'Échouée';
        break;
      case 'PENDING':
      case 'PROCESSING':
        statusText = 'En cours';
        break;
      default:
        statusText = rawStatus;
    }

    return ActivityRefundItem(
      id: id,
      title: title,
      subtitle: subtitle,
      amount: amount,
      amountText: '+${ActivityRideItem.formatPrice(amount)}',
      status: statusText,
      isPending: isPending,
      associatedRide: associatedRide,
      rideId: rideId,
      rideRef: rideRef,
      providerRef: providerRef,
      reason: reason,
      createdAt: created,
      paidAt: paid,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        subtitle,
        amountText,
        status,
        isPending,
        associatedRide,
        rideId,
        rideRef,
        providerRef,
        amount,
        reason,
        createdAt,
        paidAt,
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
