import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_help_page.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/receipt_pdf_service.dart';
import 'package:seddo/services/route_service.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:share_plus/share_plus.dart';

/// Screen displaying the detailed trip receipt matching the reference design:
/// - Top: Interactive & zoomable Google Map showing the traced route between departure & arrival
/// - Floating circular back button on top-left
/// - Draggable overlay bottom modal sheet:
///   - Date & time with green "✔ Payé" badge
///   - Price ("3 500 F") and ride type ("Seddo Eco · prix fixe")
///   - Route card with departure pin and arrival pin with DIFFERENT colors as requested
///   - Dotted intermediate line with distance & duration ("7,8 km · 22 min")
///   - Driver details (initials avatar, name, rating, license plate badge)
///   - Payment row (Orange Money badge and masked phone)
///   - Orange reference row with working copy-to-clipboard button
///   - "Reçu PDF" button with real working download/share feedback
///   - "Aide" button navigating to the RideHelpPage
///   - "Recommander ce trajet" button navigating to PlaceSearchPage with fields pre-filled
class RideReceiptPage extends StatefulWidget {
  final PlaceSearchResult? departure;
  final PlaceSearchResult? destination;
  final DriverModel? driver;
  final RideOptionModel? rideOption;
  final String departureTime;
  final String arrivalTime;
  final String durationText;
  final String distanceText;
  final String dateText;
  final String paymentPhone;
  final String orangeRef;
  final String? priceText;
  final String statusText;
  final bool isRefunded;
  final String? rideId;
  final RideService? rideService;

  const RideReceiptPage({
    super.key,
    this.departure,
    this.destination,
    this.driver,
    this.rideOption,
    this.priceText,
    this.statusText = 'Payé',
    this.isRefunded = false,
    this.departureTime = '18:19',
    this.arrivalTime = '18:41',
    this.durationText = '22 min',
    this.distanceText = '7,8 km',
    this.dateText = 'Jeudi 15 avril',
    this.paymentPhone = '77 ••• 45 12',
    this.orangeRef = 'CI270415.1819.A3F2',
    this.rideId,
    this.rideService,
  });

  @override
  State<RideReceiptPage> createState() => _RideReceiptPageState();
}

class _RideReceiptPageState extends State<RideReceiptPage> {
  late final RideService _rideService;
  GoogleMapController? _mapController;
  List<LatLng> _polylinePoints = [];
  BitmapDescriptor? _departurePinMarker;
  BitmapDescriptor? _destinationPinMarker;

  static const LatLng _defaultDepartureCoords = LatLng(14.7167, -17.4677); // Sacré-Cœur 3
  static const LatLng _defaultDestinationCoords = LatLng(14.7431, -17.5186); // Almadies

  @override
  void initState() {
    super.initState();
    _rideService = widget.rideService ?? RideService();
    _loadCustomMarkers();
    _loadRoute();
  }

  Future<void> _loadCustomMarkers() async {
    final pickup = await MapMarkerHelper.getDeparturePinMarker();
    final dest = await MapMarkerHelper.getDestinationPinMarker();
    if (mounted) {
      setState(() {
        _departurePinMarker = pickup;
        _destinationPinMarker = dest;
      });
    }
  }

  Future<void> _loadRoute() async {
    final origin = LatLng(
      widget.departure?.latitude ?? _defaultDepartureCoords.latitude,
      widget.departure?.longitude ?? _defaultDepartureCoords.longitude,
    );
    final destination = LatLng(
      widget.destination?.latitude ?? _defaultDestinationCoords.latitude,
      widget.destination?.longitude ?? _defaultDestinationCoords.longitude,
    );

    try {
      final routeDetails = await RouteService().getRoute(
        origin: origin,
        destination: destination,
      );
      if (mounted) {
        setState(() {
          _polylinePoints = routeDetails.polylinePoints;
        });
        _fitBounds();
      }
    } catch (_) {
      // Fallback points
      if (mounted) {
        setState(() {
          _polylinePoints = [origin, destination];
        });
        _fitBounds();
      }
    }
  }

  void _fitBounds() {
    if (_mapController == null || _polylinePoints.isEmpty) return;

    double minLat = _polylinePoints.first.latitude;
    double maxLat = _polylinePoints.first.latitude;
    double minLng = _polylinePoints.first.longitude;
    double maxLng = _polylinePoints.first.longitude;

    for (final point in _polylinePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  Set<Polyline> _buildPolylines() {
    if (_polylinePoints.isEmpty) return {};

    return {
      Polyline(
        polylineId: const PolylineId('receipt_route'),
        points: _polylinePoints,
        color: AppColors.receiptRouteLine,
        width: 4,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    final origin = LatLng(
      widget.departure?.latitude ?? _defaultDepartureCoords.latitude,
      widget.departure?.longitude ?? _defaultDepartureCoords.longitude,
    );
    final destination = LatLng(
      widget.destination?.latitude ?? _defaultDestinationCoords.latitude,
      widget.destination?.longitude ?? _defaultDestinationCoords.longitude,
    );

    return {
      Marker(
        markerId: const MarkerId('receipt_departure'),
        position: origin,
        icon: _departurePinMarker ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        anchor: const Offset(0.5, 1.0),
        infoWindow: InfoWindow(
          title: widget.departure?.mainText ?? 'Sacré-Cœur 3',
        ),
      ),
      Marker(
        markerId: const MarkerId('receipt_destination'),
        position: destination,
        icon: _destinationPinMarker ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 1.0),
        infoWindow: InfoWindow(
          title: widget.destination?.mainText ?? 'Almadies',
        ),
      ),
    };
  }

  Future<void> _copyOrangeReference() async {
    await Clipboard.setData(ClipboardData(text: widget.orangeRef));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Référence copiée dans le presse-papier : ${widget.orangeRef}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          backgroundColor: AppColors.slateDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
          ),
        ),
      );
    }
  }

  Future<void> _downloadOrSharePdf() async {
    final departureName = widget.departure?.mainText ?? 'Sacré-Cœur 3';
    final arrivalName = widget.destination?.mainText ?? 'Almadies';
    final price = widget.priceText ?? widget.rideOption?.formattedPrice ?? '3 500 F';
    final driverName = widget.driver?.name ?? 'Moussa';
    final carModel = widget.driver?.carModel ?? 'Toyota Corolla';
    final plate = widget.driver?.licensePlate ?? 'DK 4521 AB';
    final rating = '${widget.driver?.rating.toInt() ?? 4}';
    final rideType = widget.rideOption?.title ?? 'Seddo Eco';

    final effectiveRideId = widget.rideId;
    ReceiptSaveResult? saveResult;

    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      final pdfBytes = await _rideService.downloadReceiptPdf(effectiveRideId);
      if (pdfBytes != null && pdfBytes.isNotEmpty) {
        saveResult = await ReceiptPdfService.saveBytesToDevice(
          bytes: pdfBytes,
          fileName: 'Recu_Seddo_$effectiveRideId.pdf',
        );
      }
    }

    if (saveResult == null || !saveResult.success) {
      saveResult = await ReceiptPdfService.saveReceiptToDevice(
        departureName: departureName,
        arrivalName: arrivalName,
        departureTime: widget.departureTime,
        arrivalTime: widget.arrivalTime,
        distanceText: widget.distanceText,
        durationText: widget.durationText,
        dateText: widget.dateText,
        priceText: price,
        rideType: rideType,
        driverName: driverName,
        driverCar: carModel,
        driverPlate: plate,
        driverRating: rating,
        paymentPhone: widget.paymentPhone,
        orangeRef: widget.orangeRef,
      );
    }

    if (!mounted) return;

    if (saveResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reçu PDF téléchargé avec succès dans vos Documents (${saveResult.fileName})',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          backgroundColor: AppColors.slateDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
          ),
          action: SnackBarAction(
            label: 'Partager',
            textColor: AppColors.orangeAccent,
            onPressed: () {
              try {
                if (saveResult?.primaryPath.isNotEmpty == true) {
                  SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(saveResult!.primaryPath)],
                      subject: 'Reçu Seddo - ${widget.orangeRef}',
                    ),
                  );
                }
              } catch (_) {}
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors du téléchargement : ${saveResult.errorMessage ?? 'Erreur de stockage'}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          backgroundColor: AppColors.alert,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
          ),
        ),
      );
    }
  }

  void _openHelpPage() {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: RideHelpPage(
          destination: widget.destination ??
              const PlaceSearchResult(
                id: 'almadies',
                mainText: 'Almadies',
                secondaryText: 'Dakar',
                fullAddress: 'Almadies, Dakar',
                latitude: 14.7431,
                longitude: -17.5186,
              ),
          priceText:
              widget.priceText ?? widget.rideOption?.formattedPrice ?? '3 500 F',
          dateText: '${widget.dateText} · ${widget.statusText}',
        ),
      ),
    );
  }

  void _reorderTrip() {
    final departureName = widget.departure?.mainText ?? 'Sacré-Cœur 3';
    final arrivalName = widget.destination?.mainText ?? 'Almadies';

    Navigator.of(context).pushAndRemoveUntil(
      SlideRightToLeftRoute(
        page: PlaceSearchPage(
          initialPickup: departureName,
          initialDestination: arrivalName,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final departureCoord = LatLng(
      widget.departure?.latitude ?? _defaultDepartureCoords.latitude,
      widget.departure?.longitude ?? _defaultDepartureCoords.longitude,
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 1. Zoomable & Interactive Map in Background
          Positioned.fill(
            child: GoogleMap(
              style: MapStyleService.style,
              initialCameraPosition: CameraPosition(
                target: departureCoord,
                zoom: 14.0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                MapStyleService.applyStyle(controller);
                _fitBounds();
              },
              polylines: _buildPolylines(),
              markers: _buildMarkers(),
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              buildingsEnabled: false,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // 2. Floating Circular Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppConstants.spacingMd,
                top: AppConstants.spacingSm,
              ),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: AppConstants.circularButtonSize,
                  height: AppConstants.circularButtonSize,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.grayBorderDivider,
                      width: AppConstants.strokeWidthBorder,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowSubtleBlack,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.slateDark,
                    size: AppConstants.iconSizeMd,
                  ),
                ),
              ),
            ),
          ),

          // 3. Draggable Overlay Bottom Modal Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.68,
            minChildSize: 0.32,
            maxChildSize: 0.94,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppConstants.radiusSheet),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowCardBlack,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppConstants.spacingUnit),

                      // Drag Handle
                      Center(
                        child: Container(
                          width: AppConstants.handleWidth,
                          height: AppConstants.handleHeight,
                          decoration: BoxDecoration(
                            color: AppColors.dragHandle,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusPill,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppConstants.spacingMd),

                      // Date & Time + Status Pill Row
                      _buildHeaderRow(),

                      const SizedBox(height: AppConstants.spacingSm),

                      // Amount & Ride Category Subtitle
                      _buildAmountSection(),

                      const SizedBox(height: AppConstants.spacingUnitLg),

                      // Main Card: Route, Driver, Payment & Reference
                      _buildMainCard(),

                      const SizedBox(height: AppConstants.spacingUnitLg),

                      // Actions Row: "Reçu PDF" & "Aide"
                      _buildActionButtonsRow(),

                      const SizedBox(height: AppConstants.spacingUnitLg),

                      // Bottom Primary Button: "Recommander ce trajet"
                      _buildReorderButton(),

                      const SizedBox(height: AppConstants.spacingXl),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    final dateDisplay =
        '${widget.dateText} · ${widget.departureTime} – ${widget.arrivalTime}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            dateDisplay,
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontMd,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingUnit,
            vertical: AppConstants.spacingXs,
          ),
          decoration: BoxDecoration(
            color: widget.isRefunded
                ? AppColors.grayBgLight
                : AppColors.receiptPaidBadgeBg,
            borderRadius: BorderRadius.circular(AppConstants.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isRefunded
                    ? Icons.refresh_rounded
                    : Icons.check_circle_rounded,
                size: AppConstants.iconSizeSm,
                color: widget.isRefunded
                    ? AppColors.slateDark
                    : AppColors.receiptPaidBadgeText,
              ),
              const SizedBox(width: AppConstants.spacingXs),
              Text(
                widget.statusText,
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontSm,
                  fontWeight: FontWeight.w700,
                  color: widget.isRefunded
                      ? AppColors.slateDark
                      : AppColors.receiptPaidBadgeText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSection() {
    final amountText =
        widget.priceText ?? widget.rideOption?.formattedPrice ?? '3 500 F';
    final optionTitle = widget.rideOption?.title ?? 'Seddo Eco';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          amountText,
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontHero,
            fontWeight: FontWeight.w900,
            color: AppColors.slateDark,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          '$optionTitle · prix fixe',
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontBase,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMainCard() {
    final departureName = widget.departure?.mainText ?? 'Sacré-Cœur 3';
    final arrivalName = widget.destination?.mainText ?? 'Almadies';
    final driverName = widget.driver?.name ?? 'Moussa';
    final carModel = widget.driver?.carModel ?? 'Toyota Corolla';
    final plate = widget.driver?.licensePlate ?? 'DK 4521 AB';
    final initials = driverName.length >= 2
        ? driverName.substring(0, 2).toUpperCase()
        : 'MS';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.grayBgSubtle,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(
          color: AppColors.grayBorderDivider,
          width: AppConstants.strokeWidthBorder,
        ),
      ),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Departure Point (Silhouette passager Icons.hail_rounded)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.hail_rounded,
                size: AppConstants.iconSizeMd,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppConstants.spacingUnit),
              Expanded(
                child: Text(
                  departureName,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontBase,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                  ),
                ),
              ),
              Text(
                widget.departureTime,
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontMd,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // 2. Dotted vertical route connection & distance/time
          Padding(
            padding: const EdgeInsets.only(left: 9, top: 4, bottom: 4),
            child: Row(
              children: [
                Column(
                  children: List.generate(
                    3,
                    (index) => Container(
                      width: 2,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.grayBorderMedium,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingUnitLg),
                Text(
                  '${widget.distanceText} · ${widget.durationText}',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 3. Arrival Point (Flag icon flag-svgrepo-com.svg - Orange Seddo)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/flag-svgrepo-com.svg',
                width: AppConstants.iconSizeMd,
                height: AppConstants.iconSizeMd,
                colorFilter: const ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnit),
              Expanded(
                child: Text(
                  arrivalName,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontBase,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                  ),
                ),
              ),
              Text(
                widget.arrivalTime,
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontMd,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // Horizontal Dashed Divider
          _buildDashedDivider(),

          const SizedBox(height: AppConstants.spacingMd),

          // 4. Driver Information Row
          Row(
            children: [
              Container(
                width: AppConstants.circularAvatarSize,
                height: AppConstants.circularAvatarSize,
                decoration: const BoxDecoration(
                  color: AppColors.avatarBeige,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontBase,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slateDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontBase,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slateDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppConstants.spacingXs),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$carModel · ',
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontSm,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.star_rounded,
                          size: AppConstants.iconSizeSm,
                          color: AppColors.starGold,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.driver?.rating.toInt() ?? 4}',
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontSm,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slateDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // License Plate Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingUnit,
                  vertical: AppConstants.spacingS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.licensePlateBg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  plate,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingMd),
          const Divider(
            height: 1,
            color: AppColors.grayBorderDivider,
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // 5. Payment Row
          Row(
            children: [
              Text(
                'Paiement',
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontMd,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.pureBlack,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'OM',
                        style: GoogleFonts.inter(
                          color: AppColors.orangeMoneyOrange,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Flexible(
                      child: Text(
                        'Orange Money ${widget.paymentPhone}',
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontMd,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingMd),
          const Divider(
            height: 1,
            color: AppColors.grayBorderDivider,
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // 6. Orange Reference Row with Working Copy Button
          Row(
            children: [
              Text(
                'Réf. Orange',
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontMd,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        widget.orangeRef,
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontMd,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    GestureDetector(
                      onTap: _copyOrangeReference,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                          border: Border.all(
                            color: AppColors.grayBorderDivider,
                            width: AppConstants.strokeWidthBorder,
                          ),
                        ),
                        child: const Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: AppColors.slateDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return const SizedBox(
      height: 1.2,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(),
      ),
    );
  }

  Widget _buildActionButtonsRow() {
    return Row(
      children: [
        // "Reçu PDF" button
        Expanded(
          child: SizedBox(
            height: AppConstants.receiptActionBtnHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grayBgLight,
                foregroundColor: AppColors.slateDark,
                elevation: AppConstants.elevationNone,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusDefault,
                  ),
                ),
              ),
              onPressed: _downloadOrSharePdf,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.file_download_outlined,
                    size: AppConstants.iconSizeMd,
                    color: AppColors.slateDark,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Flexible(
                    child: Text(
                      'Reçu PDF',
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontBase,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slateDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingUnitLg),
        // "Aide" button
        Expanded(
          child: SizedBox(
            height: AppConstants.receiptActionBtnHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grayBgLight,
                foregroundColor: AppColors.slateDark,
                elevation: AppConstants.elevationNone,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusDefault,
                  ),
                ),
              ),
              onPressed: _openHelpPage,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.help_outline_rounded,
                    size: AppConstants.iconSizeMd,
                    color: AppColors.slateDark,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Text(
                    'Aide',
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontBase,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slateDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReorderButton() {
    return SizedBox(
      width: double.infinity,
      height: AppConstants.buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: AppConstants.elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
          ),
        ),
        onPressed: _reorderTrip,
        child: Text(
          'Recommander ce trajet',
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontLg,
            fontWeight: FontWeight.w800,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the horizontal dashed divider in the receipt details card
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.grayBorderMedium
      ..strokeWidth = 1.2;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset((startX + dashWidth).clamp(0, size.width), 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

