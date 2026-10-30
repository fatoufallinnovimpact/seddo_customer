import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/features/ride/data/services/ride_eta_calculator.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/driver_search_page.dart';
import 'package:seddo/features/ride/presentation/widgets/insufficient_balance_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/orange_money_payment_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/pickup_landmark_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_map_camera_toggle_button.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_option_card_widget.dart';
import 'package:seddo/features/ride/presentation/widgets/select_payment_method_sheet.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/services/route_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen displaying the active route polyline on Google Maps and the ride options bottom sheet
/// matching the exact reference UI mockup:
/// - Full interactive Google Map with route polyline following the quickest path
/// - Pickup marker with "• Prise en charge · 4 min" black badge
/// - Destination marker with orange square anchor
/// - Nearby Seddo driver car on map
/// - Floating top bar with back button and "[Destination] · [Heure] >" badge
/// - Bottom sheet "Choisissez une course" with Seddo Eco and Seddo Confort cards,
///   Orange Money payment method tile, and "Commander Seddo Eco / Confort" button
class RideBookingPage extends StatefulWidget {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final PlacesService? placesService;
  final RouteService? routeService;
  final RideService? rideService;
  final bool showHowToFindYouInitially;
  final String? initialPickupLandmark;

  const RideBookingPage({
    super.key,
    required this.departure,
    required this.destination,
    this.placesService,
    this.routeService,
    this.rideService,
    this.showHowToFindYouInitially = false,
    this.initialPickupLandmark,
  });

  @override
  State<RideBookingPage> createState() => _RideBookingPageState();
}

class _RideBookingPageState extends State<RideBookingPage> {
  late final RideService _rideService;
  GoogleMapController? _mapController;

  BitmapDescriptor? _pickupBadgeIcon;
  BitmapDescriptor? _destSquareIcon;

  List<LatLng> _polylinePoints = [];
  List<TrafficSegmentModel> _traffic = [];
  bool _isLoadingRoute = true;
  double _distanceKm = 5.0;
  int _durationMinutes = 15;
  String? _zoneName;

  RideType _selectedRideType = RideType.eco;
  late RideOptionModel _ecoOption;
  late RideOptionModel _confortOption;
  String? _pickupLandmark;
  String _userPhoneDisplay = '77 ••• 45 12';

  final GlobalKey _bottomSheetKey = GlobalKey();
  double _bottomSheetHeight = 440.0;

  @override
  void initState() {
    super.initState();
    _pickupLandmark = widget.initialPickupLandmark;
    _rideService = widget.rideService ?? RideService();
    _computeRideOptions();
    _loadCustomMarkers();
    _fetchRoute();
    _loadConnectedUserPhone();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureBottomSheet();
      if (widget.showHowToFindYouInitially && mounted) {
        _openHowToFindYouSheet();
      }
    });
  }

  void _measureBottomSheet() {
    final renderBox =
        _bottomSheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize && mounted) {
      final h = renderBox.size.height;
      if ((_bottomSheetHeight - h).abs() > 3) {
        setState(() {
          _bottomSheetHeight = h;
        });
      }
    }
  }

  Future<void> _loadConnectedUserPhone() async {
    // 1. From active in-memory currentUser
    final currentUser = AuthRepository().currentUser;
    if (currentUser != null && currentUser.maskedPhone.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userPhoneDisplay = currentUser.maskedPhone;
        });
      }
      return;
    }

    // 2. From cached user model in storage
    final cachedUser = await AuthRepository().getCachedUser();
    if (cachedUser != null && cachedUser.maskedPhone.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userPhoneDisplay = cachedUser.maskedPhone;
        });
      }
      return;
    }

    // 3. Fallback from SharedPreferences user_phone or auth_pending_phone
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ??
          prefs.getString('auth_pending_phone');
      if (phone != null && phone.isNotEmpty) {
        final tempUser = UserModel(id: '', phone: phone);
        if (mounted) {
          setState(() {
            _userPhoneDisplay = tempUser.maskedPhone;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openHowToFindYouSheet() async {
    final result = await PickupLandmarkSheet.show(
      context,
      initialLandmark: _pickupLandmark,
    );
    if (result != null && mounted) {
      setState(() {
        _pickupLandmark = result;
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _computeRideOptions() {
    final now = DateTime.now();
    final arrivalEco = now.add(Duration(minutes: _durationMinutes + 4));
    final arrivalConfort = now.add(Duration(minutes: _durationMinutes + 7));

    final ecoTimeStr =
        '${arrivalEco.hour.toString().padLeft(2, '0')}:${arrivalEco.minute.toString().padLeft(2, '0')}';
    final confortTimeStr =
        '${arrivalConfort.hour.toString().padLeft(2, '0')}:${arrivalConfort.minute.toString().padLeft(2, '0')}';

    // Pricing estimation based on Dakar distance (FCFA rounded to nearest 100)
    final ecoFare = ((1500 + (_distanceKm * 250)) / 100).round() * 100;
    final confortFare = ((2200 + (_distanceKm * 325)) / 100).round() * 100;

    _ecoOption = RideOptionModel(
      type: RideType.eco,
      title: 'home.seddo_eco'.tr(),
      subtitle: '$ecoTimeStr · ${'ride.arriving_in'.tr(args: ['4'])}',
      capacity: 4,
      price: ecoFare.clamp(2000, 25000),
      estimatedArrival: ecoTimeStr,
      pickupDuration: '4 min',
    );

    _confortOption = RideOptionModel(
      type: RideType.confort,
      title: 'Seddo ${'home.confort'.tr()}',
      subtitle: '$confortTimeStr · ${'home.confort_sub'.tr()}',
      capacity: 4,
      price: confortFare.clamp(2800, 35000),
      estimatedArrival: confortTimeStr,
      pickupDuration: '7 min',
    );
  }

  Future<void> _loadCustomMarkers() async {
    final pickup = await MapMarkerHelper.getDeparturePinMarker();
    final dest = await MapMarkerHelper.getDestinationPinMarker();

    if (mounted) {
      setState(() {
        _pickupBadgeIcon = pickup;
        _destSquareIcon = dest;
      });
    }
  }

  Future<void> _fetchRoute() async {
    setState(() {
      _isLoadingRoute = true;
    });

    RideQuoteModel? quote;
    try {
      quote = await _rideService.getQuote(
        departure: widget.departure,
        destination: widget.destination,
        pickupNote: _pickupLandmark,
      );
    } catch (_) {
      quote = null;
    }

    if (!mounted) return;

    if (quote != null) {
      // 1. Live quote received from API with exact road polyline & official pricing
      final decodedPoints = quote.decodedPolyline;
      final distanceKm = quote.distanceKm;
      final durationMins = quote.durationMinutes;

      final now = DateTime.now();
      final ecoArrival = now.add(Duration(minutes: durationMins + 4));
      final confortArrival = now.add(Duration(minutes: durationMins + 7));

      final ecoTimeStr =
          '${ecoArrival.hour.toString().padLeft(2, '0')}:${ecoArrival.minute.toString().padLeft(2, '0')}';
      final confortTimeStr =
          '${confortArrival.hour.toString().padLeft(2, '0')}:${confortArrival.minute.toString().padLeft(2, '0')}';

      // 2. Real price for ECO from API options (e.g. 3850 FCFA)
      final apiEco = quote.ecoOption;
      final ecoPrice = apiEco != null
          ? apiEco.price
          : (((1500 + (distanceKm * 250)) / 100).round() * 100).clamp(2000, 25000);
      final ecoQuoteId = apiEco?.quoteId;
      final ecoSeats = apiEco?.seats ?? 4;
      final ecoName = (apiEco != null && apiEco.name.isNotEmpty)
          ? apiEco.name
          : 'home.seddo_eco'.tr();

      // 3. CONFORT option is kept in code/UI as requested.
      // If backend returns CONFORT, use its real price & quoteId.
      // Otherwise calculate from Eco price so user can still see and select it.
      final apiConfort = quote.confortOption;
      final confortPrice = apiConfort != null
          ? apiConfort.price
          : ((ecoPrice * 1.35) / 100).round() * 100;
      final confortQuoteId = apiConfort?.quoteId;
      final confortSeats = apiConfort?.seats ?? 4;
      final confortName = (apiConfort != null && apiConfort.name.isNotEmpty)
          ? apiConfort.name
          : 'Seddo ${'home.confort'.tr()}';

      final ecoEtaS = apiEco?.pickupEtaS ?? quote.pickupEtaS ?? 240;
      final ecoEtaMin = (ecoEtaS / 60.0).ceil();
      final confortEtaS = apiConfort?.pickupEtaS ?? (ecoEtaS + 180);
      final confortEtaMin = (confortEtaS / 60.0).ceil();
      final quoteTraffic = quote.traffic;
      final quoteDistanceM = quote.distanceM;
      final quoteDurationS = quote.durationS;
      final quoteZone = quote.zone;

      setState(() {
        if (decodedPoints.isNotEmpty) {
          _polylinePoints = decodedPoints;
        }
        _traffic = quoteTraffic;
        _distanceKm = distanceKm;
        _durationMinutes = durationMins;
        _zoneName = quoteZone;
        _ecoOption = RideOptionModel(
          type: RideType.eco,
          title: ecoName,
          subtitle: '$ecoTimeStr · ${'ride.arriving_in'.tr(args: [ecoEtaMin.toString()])}',
          capacity: ecoSeats,
          price: ecoPrice,
          estimatedArrival: ecoTimeStr,
          pickupDuration: '$ecoEtaMin min',
          quoteId: ecoQuoteId,
          pickupEtaS: ecoEtaS,
          traffic: quoteTraffic,
          distanceM: quoteDistanceM,
          durationS: quoteDurationS,
        );
        _confortOption = RideOptionModel(
          type: RideType.confort,
          title: confortName,
          subtitle: '$confortTimeStr · ${'home.confort_sub'.tr()}',
          capacity: confortSeats,
          price: confortPrice,
          estimatedArrival: confortTimeStr,
          pickupDuration: '$confortEtaMin min',
          quoteId: confortQuoteId,
          pickupEtaS: confortEtaS,
          traffic: quoteTraffic,
          distanceM: quoteDistanceM,
          durationS: quoteDurationS,
        );
        _isLoadingRoute = false;
      });

      debugPrint(
          '[RideBookingPage] 💰 VRAI PRIX API APPLIQUÉ pour Seddo Eco: $ecoPrice FCFA (quoteId: $ecoQuoteId)');
      debugPrint(
          '[RideBookingPage] 💰 VRAI PRIX API APPLIQUÉ pour Seddo Confort: $confortPrice FCFA (quoteId: $confortQuoteId, depuis API: ${apiConfort != null})');

      _fitCameraToBounds();
      return;
    }

    debugPrint(
        '[RideBookingPage] ⚠️ Devis API non disponible (hors-ligne ou non authentifié)');

    // Pas de tracé simulé par défaut ! Tout doit venir de l'API.
    if (mounted) {
      setState(() {
        _polylinePoints = [];
        _isLoadingRoute = false;
      });

      _fitCameraToBounds();
    }
  }

  void _fitCameraToBounds() {
    if (_mapController == null) return;

    if (_polylinePoints.isNotEmpty) {
      double south = widget.departure.latitude;
      double north = widget.departure.latitude;
      double west = widget.departure.longitude;
      double east = widget.departure.longitude;

      for (final p in _polylinePoints) {
        if (p.latitude < south) south = p.latitude;
        if (p.latitude > north) north = p.latitude;
        if (p.longitude < west) west = p.longitude;
        if (p.longitude > east) east = p.longitude;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 90),
      );
    } else {
      final south = math.min(widget.departure.latitude, widget.destination.latitude);
      final north = math.max(widget.departure.latitude, widget.destination.latitude);
      final west = math.min(widget.departure.longitude, widget.destination.longitude);
      final east = math.max(widget.departure.longitude, widget.destination.longitude);

      final bounds = LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 90),
      );
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // 1. Pickup departure location pin marker
    if (_pickupBadgeIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_marker'),
          position: LatLng(
            widget.departure.latitude,
            widget.departure.longitude,
          ),
          icon: _pickupBadgeIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    // 2. Destination arrival location pin marker
    if (_destSquareIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest_marker'),
          position: LatLng(
            widget.destination.latitude,
            widget.destination.longitude,
          ),
          icon: _destSquareIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    // Pas de fausse voiture simulée par défaut sur la carte ! Tout vient de l'API.
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_polylinePoints.isEmpty) return {};

    return RideEtaCalculator.buildTrafficPolylines(
      baseId: 'route_polyline',
      points: _polylinePoints,
      traffic: _traffic,
      width: 5,
    );
  }

  Future<void> _onOrderRide() async {
    final selectedOption =
        _selectedRideType == RideType.eco ? _ecoOption : _confortOption;

    // 1. Premier modal : Sélection du Mode de paiement (Wave, OM, Espèces)
    final chosenMethod = await SelectPaymentMethodSheet.show(
      context,
      initialMethod: PaymentMethodType.cash,
    );

    if (!mounted || chosenMethod == null) return;

    // 2. Second modal : Confirmation du paiement connecté à l'API
    final result = await OrangeMoneyPaymentSheet.show(
      context,
      rideOption: selectedOption,
      phoneDisplay: _userPhoneDisplay,
      rideService: _rideService,
      paymentMethod: chosenMethod,
    );

    if (!mounted || result == null) return;

    if (result == OrangeMoneyPaymentResult.insufficientBalance) {
      if (mounted) {
        await InsufficientBalanceSheet.show(
          context,
          rideOption: selectedOption,
        );
      }
      return;
    }

    if (result == OrangeMoneyPaymentResult.success) {
      if (mounted) {
        Navigator.of(context).push(
          SlideRightToLeftRoute(
            page: DriverSearchPage(
              departure: widget.departure,
              destination: widget.destination,
              rideOption: selectedOption,
              polylinePoints: _polylinePoints,
              pickupLandmark: _pickupLandmark,
              rideId: RideService.lastCreatedRideId,
              paymentMethod: chosenMethod,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final selectedOption =
        _selectedRideType == RideType.eco ? _ecoOption : _confortOption;

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomSheet());

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 1. Fullscreen Google Map
          GoogleMap(
            style: MapStyleService.style,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.departure.latitude,
                widget.departure.longitude,
              ),
              zoom: 14.5,
            ),
            padding: EdgeInsets.only(top: 80, bottom: _bottomSheetHeight + 10),
            onMapCreated: (controller) {
              _mapController = controller;
              MapStyleService.applyStyle(controller);
              if (_polylinePoints.isNotEmpty) {
                _fitCameraToBounds();
              }
            },
            polylines: _buildPolylines(),
            markers: _buildMarkers(),
            buildingsEnabled: false,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Floating Top Bar: Back Button + Destination Pill Badge
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Circular Back Button
                      Container(
                        width: AppConstants.circularButtonSize,
                        height: AppConstants.circularButtonSize,
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowMarker,
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),

                      const SizedBox(width: AppConstants.spacingSm),

                      // Floating destination pill: "Almadies · 18:42 >"
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusPill,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadowMarker,
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.destination.mainText,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  ' · ${_ecoOption.estimatedArrival} ',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isLoadingRoute)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.transparent,
                        minHeight: 2.5,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Bouton flottant de caméra cyclique (Départ / Arrivée / Trajet complet)
          Positioned(
            right: 16,
            bottom: _bottomSheetHeight + 14,
            child: RideMapCameraToggleButton(
              mapControllerGetter: () => _mapController,
              departureLocation: LatLng(
                widget.departure.latitude,
                widget.departure.longitude,
              ),
              destinationLocation: LatLng(
                widget.destination.latitude,
                widget.destination.longitude,
              ),
              polylinePoints: _polylinePoints,
              initialMode: RideMapCameraMode.tripOverview,
            ),
          ),

          // 4. Modal Sheet avec options de course et prix
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              key: _bottomSheetKey,
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusSheet),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowCardBlack,
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                AppConstants.spacingMd + 4,
                10,
                AppConstants.spacingMd + 4,
                systemBottom + AppConstants.spacingMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Barre de glissement
                  Container(
                    width: AppConstants.circularIconContainerSize,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.dragHandle,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusXs,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. En-tête tout en haut du modal (centré) : "Choisissez une course" & "Dakar et banlieue"
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'ride.choose_ride'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _zoneName != null && _zoneName!.isNotEmpty
                            ? _zoneName!
                            : 'ride.dakar_and_suburbs'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Bloc Départ & Arrivée (sans texte Arrêts)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ligne 1 : Point de départ avec l'icône de silhouette passager
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.hail_rounded,
                                size: 20,
                                color: AppColors.markerIconBlack,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.departure.mainText,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.only(left: 38, top: 8, bottom: 8),
                          child: Divider(height: 1, color: AppColors.neutralDivider),
                        ),

                        // Ligne 2 : Point d'arrivée avec l'icône drapeau flag-svgrepo-com.svg
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                'assets/icons/flag-svgrepo-com.svg',
                                width: 18,
                                height: 18,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.markerIconBlack,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.destination.mainText,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_durationMinutes > 0)
                                    Text(
                                      ' · $_durationMinutes min.',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.only(top: 10, bottom: 12),
                    child: Divider(height: 1, color: AppColors.grayBorderDivider),
                  ),
                  const SizedBox(height: 4),

                  // Pickup Landmark / "Comment vous trouver ?" Banner
                  GestureDetector(
                    onTap: _openHowToFindYouSheet,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingUnitLg,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neutralInputBg,
                        borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                        border: Border.all(
                          color: _pickupLandmark != null && _pickupLandmark!.isNotEmpty
                              ? AppColors.primary.withValues(alpha: 0.35)
                              : AppColors.neutralInputBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.slateLightBg,
                              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.neutralIconGrey,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _pickupLandmark != null && _pickupLandmark!.isNotEmpty
                                      ? _pickupLandmark!
                                      : 'ride.how_to_find_you'.tr(),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _pickupLandmark != null && _pickupLandmark!.isNotEmpty
                                      ? 'Indication enregistrée · Toucher pour modifier'
                                      : 'ride.how_to_find_you_sub'.tr(),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Option 1: Seddo Eco Card (3D Vehicle)
                  RideOptionCardWidget(
                    option: _ecoOption,
                    isSelected: _selectedRideType == RideType.eco,
                    imagePath: 'assets/images/seddo_eco_3d.png',
                    onTap: () => setState(() => _selectedRideType = RideType.eco),
                  ),

                  const SizedBox(height: 10),

                  // Option 2: Seddo Confort Card (3D Vehicle)
                  RideOptionCardWidget(
                    option: _confortOption,
                    isSelected: _selectedRideType == RideType.confort,
                    imagePath: 'assets/images/seddo_confort_3d.png',
                    onTap: () =>
                        setState(() => _selectedRideType = RideType.confort),
                  ),

                  const SizedBox(height: 16),

                  // Big Orange Confirmation Button: "Commander Seddo Eco"
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusLg,
                          ),
                        ),
                      ),
                      onPressed: _onOrderRide,
                      child: Text(
                        '${'ride.order'.tr()} ${selectedOption.title}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ride option tile card with custom border for selected state

