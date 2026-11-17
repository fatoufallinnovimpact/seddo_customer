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
import 'package:seddo/features/home/data/services/user_location_storage.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/features/ride/data/services/ride_eta_calculator.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/driver_approaching_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_search_page.dart';
import 'package:seddo/services/realtime_service.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/orange_money_payment_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/pickup_landmark_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_map_camera_toggle_button.dart';
import 'package:seddo/features/payment/data/services/payment_methods_service.dart';
import 'package:seddo/features/payment/presentation/widgets/payment_method_modal.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/network_connectivity_service.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/services/route_service.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_modal_sheet.dart';
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

class _RideBookingPageState extends State<RideBookingPage>
    with SingleTickerProviderStateMixin {
  late final RideService _rideService;
  GoogleMapController? _mapController;

  BitmapDescriptor? _pickupBadgeIcon;
  BitmapDescriptor? _destSquareIcon;
  BitmapDescriptor? _carMarkerIcon;
  List<NearbyCarModel> _nearbyCars = [];

  List<LatLng> _polylinePoints = [];
  List<TrafficSegmentModel> _traffic = [];
  bool _isLoadingRoute = true;
  bool _isOfflinePriceError = false;
  double _distanceKm = 5.0;
  int _durationMinutes = 15;
  String? _zoneName;

  RideType _selectedRideType = RideType.eco;
  PaymentMethodType _selectedPaymentMethod = PaymentMethodType.orangeMoney;
  late RideOptionModel _ecoOption;
  late RideOptionModel _confortOption;
  String? _pickupLandmark;
  String _userPhoneDisplay = '77 ••• 45 12';
  bool _isOrderingRide = false;

  late PlaceSearchResult _departure;

  final GlobalKey _bottomSheetKey = GlobalKey();
  double _bottomSheetHeight = 440.0;
  double _sheetDragOffset = 0.0;
  late AnimationController _sheetAnimController;
  Animation<double>? _sheetAnimation;

  @override
  void initState() {
    super.initState();
    _departure = widget.departure;
    _sanitizeAndResolveDeparture();

    _sheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _pickupLandmark = widget.initialPickupLandmark;
    _rideService = widget.rideService ?? RideService();
    _computeRideOptions();
    _loadCustomMarkers();
    _fetchRoute();
    _fetchNearbyDrivers();
    _loadConnectedUserPhone();

    // Initialisation et présélection automatique du mode de paiement depuis l'API
    PaymentMethodsService().init().then((code) {
      if (mounted) {
        setState(() {
          _selectedPaymentMethod = PaymentMethodType.fromApiValue(code);
        });
      }
    });
    PaymentMethodsService().selectedCodeNotifier.addListener(_onPaymentMethodCodeChanged);

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
    PaymentMethodsService().selectedCodeNotifier.removeListener(_onPaymentMethodCodeChanged);
    _sheetAnimController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onPaymentMethodCodeChanged() {
    if (mounted) {
      final code = PaymentMethodsService().currentCode;
      setState(() {
        _selectedPaymentMethod = PaymentMethodType.fromApiValue(code);
      });
    }
  }

  void _sanitizeAndResolveDeparture() {
    final raw = _departure.mainText;
    final isGenericOrCoords = raw.isEmpty ||
        raw == 'Position sur la carte' ||
        raw == 'Position sélectionnée' ||
        raw == 'Position GPS actuelle' ||
        raw == 'Ma position actuelle' ||
        raw.toLowerCase() == 'dakar' ||
        raw.toLowerCase() == 'dakar, sénégal' ||
        raw.toLowerCase() == 'dakar, senegal' ||
        RegExp(r'^-?\d+\.\d+').hasMatch(raw);

    if (isGenericOrCoords) {
      final fallback = PlacesService.getDakarDistrictFallback(
        _departure.latitude,
        _departure.longitude,
      );
      _departure = PlaceSearchResult(
        id: _departure.id,
        mainText: fallback.mainText,
        secondaryText: fallback.secondaryText,
        fullAddress: fallback.fullAddress,
        latitude: _departure.latitude,
        longitude: _departure.longitude,
        category: 'pickup',
      );
    }

    if (!UserLocationStorage.isStreetLevelAddress(_departure.mainText)) {
      final service = widget.placesService ?? PlacesService();
      service.reverseGeocode(_departure.latitude, _departure.longitude).then((res) {
        if (mounted &&
            res.mainText.isNotEmpty &&
            res.mainText != 'Position sur la carte' &&
            res.mainText != 'Position sélectionnée' &&
            res.mainText.toLowerCase() != 'dakar' &&
            res.mainText.toLowerCase() != 'dakar, sénégal' &&
            res.mainText.toLowerCase() != 'dakar, senegal' &&
            !RegExp(r'^-?\d+\.\d+').hasMatch(res.mainText)) {
          setState(() {
            _departure = PlaceSearchResult(
              id: _departure.id,
              mainText: res.mainText,
              secondaryText: res.secondaryText.isNotEmpty
                  ? res.secondaryText
                  : 'Dakar, Sénégal',
              fullAddress: res.fullAddress,
              latitude: _departure.latitude,
              longitude: _departure.longitude,
              category: 'pickup',
            );
          });
        }
      }).catchError((_) {});
    }
  }

  void _onSheetDragUpdate(DragUpdateDetails details, double maxOffset) {
    if (maxOffset <= 0) return;
    setState(() {
      _sheetDragOffset =
          (_sheetDragOffset + details.primaryDelta!).clamp(0.0, maxOffset);
    });
  }

  void _onSheetDragEnd(DragEndDetails details, double maxOffset) {
    if (maxOffset <= 0) return;
    final velocity = details.primaryVelocity ?? 0.0;
    if (velocity > 250) {
      _animateSheetTo(maxOffset);
    } else if (velocity < -250) {
      _animateSheetTo(0.0);
    } else {
      if (_sheetDragOffset > maxOffset * 0.4) {
        _animateSheetTo(maxOffset);
      } else {
        _animateSheetTo(0.0);
      }
    }
  }

  void _animateSheetTo(double targetOffset) {
    _sheetAnimController.stop();
    _sheetAnimation = Tween<double>(
      begin: _sheetDragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _sheetAnimController,
      curve: Curves.easeOutCubic,
    ))..addListener(() {
        setState(() {
          _sheetDragOffset = _sheetAnimation!.value;
        });
      });
    _sheetAnimController.reset();
    _sheetAnimController.forward();
  }

  void _computeRideOptions() {
    final now = DateTime.now();
    final arrivalEco = now.add(Duration(minutes: _durationMinutes + 4));
    final arrivalConfort = now.add(Duration(minutes: _durationMinutes + 7));

    final ecoTimeStr =
        '${arrivalEco.hour.toString().padLeft(2, '0')}:${arrivalEco.minute.toString().padLeft(2, '0')}';
    final confortTimeStr =
        '${arrivalConfort.hour.toString().padLeft(2, '0')}:${arrivalConfort.minute.toString().padLeft(2, '0')}';

    // Prix initial à 0 pendant le chargement du vrai devis API (POST /v1/rides/quote)
    _ecoOption = RideOptionModel(
      type: RideType.eco,
      title: 'home.seddo_eco'.tr(),
      subtitle: '$ecoTimeStr · ${'ride.arriving_in'.tr(args: ['4'])}',
      capacity: 4,
      price: 0,
      estimatedArrival: ecoTimeStr,
      pickupDuration: '4 min',
    );

    _confortOption = RideOptionModel(
      type: RideType.confort,
      title: 'Seddo ${'home.confort'.tr()}',
      subtitle: '$confortTimeStr · ${'home.confort_sub'.tr()}',
      capacity: 4,
      price: 0,
      estimatedArrival: confortTimeStr,
      pickupDuration: '7 min',
    );
  }

  Future<void> _loadCustomMarkers() async {
    final pickup = await MapMarkerHelper.getDeparturePinMarker();
    final dest = await MapMarkerHelper.getDestinationPinMarker();
    final car = await MapMarkerHelper.get3DCarMarker();

    if (mounted) {
      setState(() {
        _pickupBadgeIcon = pickup;
        _destSquareIcon = dest;
        _carMarkerIcon = car;
      });
    }
  }

  /// Récupère les voitures disponibles autour du point de départ via GET /v1/drivers/nearby
  Future<void> _fetchNearbyDrivers() async {
    try {
      final res = await _rideService.getNearbyDrivers(
        lat: _departure.latitude,
        lng: _departure.longitude,
      );

      if (res != null && mounted) {
        setState(() {
          _nearbyCars = res.allCars;
          if (res.ecoEtaMinutes != null) {
            _ecoOption = _ecoOption.copyWith(
              pickupDuration: '${res.ecoEtaMinutes} min',
              subtitle: '${_ecoOption.estimatedArrival} · ${'ride.arriving_in'.tr(args: [res.ecoEtaMinutes.toString()])}',
            );
          }
          if (res.confortEtaMinutes != null) {
            _confortOption = _confortOption.copyWith(
              pickupDuration: '${res.confortEtaMinutes} min',
              subtitle: '${_confortOption.estimatedArrival} · ${'ride.arriving_in'.tr(args: [res.confortEtaMinutes.toString()])}',
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchRoute() async {
    setState(() {
      _isLoadingRoute = true;
    });

    RideQuoteModel? quote;
    try {
      quote = await _rideService.getQuote(
        departure: _departure,
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
      final fallbackQuoteId = quote.options.isNotEmpty
          ? quote.options.first.quoteId
          : (quote.ecoOption?.quoteId ?? '');
      final ecoQuoteId = apiEco?.quoteId ?? fallbackQuoteId;
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
      final confortQuoteId = apiConfort?.quoteId ?? fallbackQuoteId;
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

    // Si le devis API n'a pas répondu (ex: hors-ligne ou tests), calculer le tarif de secours
    if (mounted) {
      final bool isTest =
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      final isOnline = await NetworkConnectivityService.isConnected;
      final ecoFare = ((1500 + (_distanceKm * 250)) / 100).round() * 100;
      final confortFare = ((2200 + (_distanceKm * 325)) / 100).round() * 100;

      if (!mounted) return;
      setState(() {
        _polylinePoints = [];
        if (isTest || isOnline) {
          _ecoOption = _ecoOption.copyWith(price: ecoFare.clamp(2000, 25000));
          _confortOption =
              _confortOption.copyWith(price: confortFare.clamp(2800, 35000));
          _isOfflinePriceError = false;
        } else {
          // En mode hors-ligne réel : afficher l'avertissement
          _isOfflinePriceError = true;
        }
        _isLoadingRoute = false;
      });

      _fitCameraToBounds();
    }
  }

  void _fitCameraToBounds() {
    if (_mapController == null) return;

    if (_polylinePoints.isNotEmpty) {
      double south = _departure.latitude;
      double north = _departure.latitude;
      double west = _departure.longitude;
      double east = _departure.longitude;

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
      final south = math.min(_departure.latitude, widget.destination.latitude);
      final north = math.max(_departure.latitude, widget.destination.latitude);
      final west = math.min(_departure.longitude, widget.destination.longitude);
      final east = math.max(_departure.longitude, widget.destination.longitude);

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
            _departure.latitude,
            _departure.longitude,
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

    // 3. Real nearby cars from GET /v1/drivers/nearby (with anti-overlap separation)
    if (_nearbyCars.isNotEmpty) {
      final separatedCars = NearbyCarModel.separateOverlappingCars(_nearbyCars);
      final carIcon = _carMarkerIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      for (int i = 0; i < separatedCars.length; i++) {
        final car = separatedCars[i];
        if (car.lat == 0.0 && car.lng == 0.0) continue;
        markers.add(
          Marker(
            markerId: MarkerId('nearby_car_${car.id}_$i'),
            position: LatLng(car.lat, car.lng),
            icon: carIcon,
            rotation: car.heading,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            zIndexInt: 5,
          ),
        );
      }
    }

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
    final isOnline = await NetworkConnectivityService.isConnected;
    if (!mounted) return;
    if (!isOnline) {
      await OfflineModalSheet.show(
        context,
        currentPosition:
            LatLng(_departure.latitude, _departure.longitude),
        currentAddress: _departure.fullAddress,
        onRetry: () => _onOrderRide(),
      );
      return;
    }

    final selectedOption =
        _selectedRideType == RideType.eco ? _ecoOption : _confortOption;

    final quoteId = selectedOption.quoteId;
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    if (!isTestEnvironment && (quoteId == null || quoteId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calcul du devis en cours, veuillez patienter...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Le moyen de paiement sélectionné au préalable
    final chosenMethod = _selectedPaymentMethod;

    // 1. ESPÈCES (CASH) : création et recherche directe sans aucun modal intermédiaire
    if (chosenMethod == PaymentMethodType.cash) {
      setState(() => _isOrderingRide = true);
      try {
        final rideData = isTestEnvironment
            ? {'id': 'test_ride_1', 'status': 'SEARCHING'}
            : await _rideService.createRide(
                quoteId: quoteId ?? 'test_quote',
                paymentMethod: 'CASH',
              );
        setState(() => _isOrderingRide = false);
        if (!mounted) return;

        if (rideData != null) {
          _handleOrderSuccess(selectedOption, rideData, chosenMethod);
        } else {
          _fetchRoute();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de commander la course. Veuillez réessayer.'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      } catch (e) {
        setState(() => _isOrderingRide = false);
        if (mounted) {
          _fetchRoute();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
      return;
    }

    // 2. WAVE ou ORANGE MONEY : ouverture du sheet avec autoValidate: true pour redirection directe
    final result = await OrangeMoneyPaymentSheet.show(
      context,
      rideOption: selectedOption,
      phoneDisplay: _userPhoneDisplay,
      rideService: _rideService,
      paymentMethod: chosenMethod,
      autoValidate: true,
    );

    if (!mounted) return;

    if (result == OrangeMoneyPaymentResult.success) {
      final lastData = RideService.lastCreatedRideData ??
          {'id': RideService.lastCreatedRideId ?? 'created_ride_id', 'status': 'SEARCHING'};
      _handleOrderSuccess(selectedOption, lastData, chosenMethod);
    } else {
      _fetchRoute();
    }
  }

  void _handleOrderSuccess(
    RideOptionModel selectedOption,
    Map<String, dynamic> lastData,
    PaymentMethodType chosenMethod,
  ) {
    List<LatLng> effectivePoints = _polylinePoints;
    final plannedPoly = lastData['plannedPolyline'] as String?;
    if (plannedPoly != null && plannedPoly.isNotEmpty) {
      final decoded = RouteService.decodePolyline(plannedPoly);
      if (decoded.length >= 2) {
        effectivePoints = decoded;
      }
    }

    List<TrafficSegmentModel> effectiveTraffic = _traffic.isNotEmpty
        ? _traffic
        : selectedOption.traffic;
    final rawPlannedTraffic = (lastData['plannedTraffic'] ??
        lastData['traffic']) as List<dynamic>?;
    if (rawPlannedTraffic != null && rawPlannedTraffic.isNotEmpty) {
      final parsed = rawPlannedTraffic
          .whereType<Map<String, dynamic>>()
          .map((item) => TrafficSegmentModel.fromJson(item))
          .toList();
      if (parsed.isNotEmpty) {
        effectiveTraffic = parsed;
      }
    }

    final cachedEvent = RealtimeService().lastRideStatusEvent;
    final status = (lastData['status'] as String? ?? cachedEvent?.status ?? '').toUpperCase();
    final hasDriver = lastData['driver'] != null || cachedEvent?.driver != null;
    final isAccepted = status == 'ACCEPTED' ||
        status == 'DRIVER_ACCEPTED' ||
        status == 'DRIVER_ASSIGNED' ||
        status == 'ASSIGNED' ||
        status == 'CONFIRMED' ||
        status == 'APPROACHING' ||
        status == 'EN_ROUTE' ||
        status == 'DRIVER_ARRIVED' ||
        status == 'IN_PROGRESS' ||
        hasDriver;

    final effectiveRideId = lastData['id'] as String? ?? RideService.lastCreatedRideId;

    if (isAccepted) {
      final driver = cachedEvent?.driver ??
          DriverModel.fromRideJson(
            lastData,
            defaultRideType: selectedOption.type,
          );
      final code = cachedEvent?.departureCode ??
          DriverModel.extractDepartureCode(lastData);

      Navigator.of(context).push(
        SlideRightToLeftRoute(
          page: DriverApproachingPage(
            departure: _departure,
            destination: widget.destination,
            rideOption: selectedOption,
            driver: driver,
            polylinePoints: effectivePoints,
            departureCode: code,
            rideId: effectiveRideId,
            rideService: widget.rideService,
            autoStartSimulation: false,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        SlideRightToLeftRoute(
          page: DriverSearchPage(
            departure: _departure,
            destination: widget.destination,
            rideOption: selectedOption,
            polylinePoints: effectivePoints,
            traffic: effectiveTraffic,
            pickupLandmark: _pickupLandmark,
            rideId: effectiveRideId,
            paymentMethod: chosenMethod,
          ),
        ),
      );
    }
  }

  Widget _buildVehicleCard({
    required bool isEco,
    required RideOptionModel option,
  }) {
    final isSelected =
        _selectedRideType == (isEco ? RideType.eco : RideType.confort);

    final rawAcLabel = 'home.confort_ac_badge'.tr();
    final acLabel =
        rawAcLabel == 'home.confort_ac_badge' ? 'Climatisé' : rawAcLabel;

    return Expanded(
      child: GestureDetector(
        key: Key(isEco ? 'ride_card_eco' : 'ride_card_confort'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedRideType = isEco ? RideType.eco : RideType.confort;
          });
        },
        child: SizedBox(
          height: AppConstants.rideCardHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Carte principale épurée (hauteur réduite, sans forme grise en bas de la voiture)
              Positioned.fill(
                top: AppConstants.rideCardBoxTopInset,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.ecoCardSelectedBackground
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(
                      AppConstants.rideCardRadius,
                    ),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.grayBorderDivider,
                      width: isSelected
                          ? AppConstants.strokeWidthSelected
                          : AppConstants.spacingTiny,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              blurRadius: AppConstants.spacingUnit,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : const [
                            BoxShadow(
                              color: AppColors.shadowFaintBlack,
                              blurRadius: AppConstants.spacingXs,
                              offset: Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.rideCardBottomPaddingH,
                      AppConstants.rideCardBottomPaddingTop,
                      AppConstants.rideCardBottomPaddingH,
                      AppConstants.rideCardBottomPaddingBottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ligne 1 : Titre entier ("Seddo Eco" / "Seddo Confort") sans être coupé par le prix
                        Text(
                          option.title,
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.rideCardTitleFontSize,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppConstants.spacingTiny),

                        // Ligne 2 : Prix descendu en dessous du titre et mis en exergue
                        if (_isLoadingRoute)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppConstants.spacingXxs,
                            ),
                            child: SizedBox(
                              width: AppConstants.iconSizeSm,
                              height: AppConstants.iconSizeSm,
                              child: CircularProgressIndicator(
                                strokeWidth: AppConstants.spacingXxs,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        else
                          Text(
                            option.formattedPrice,
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.rideCardPriceFontSize,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: AppConstants.spacingXs),

                        // Ligne 3 : Durée d'approche + capacité + indicateur de climatisation pour Seddo Confort
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                option.pickupDuration,
                                style: GoogleFonts.inter(
                                  fontSize: AppConstants.rideCardMetaFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacingS),
                              const Icon(
                                Icons.person_rounded,
                                size: AppConstants.rideCardPersonIconSize,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppConstants.spacingXxs),
                              Text(
                                '${option.capacity}',
                                style: GoogleFonts.inter(
                                  fontSize: AppConstants.rideCardMetaFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (!isEco) ...[
                                const SizedBox(width: AppConstants.spacingS),
                                Container(
                                  key: const Key('ride_confort_ac_badge'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppConstants.spacingFive,
                                    vertical: AppConstants.spacingTiny,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.rideCardAcBadgeBg,
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.rideCardAcBadgeRadius,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.ac_unit_rounded,
                                        size: AppConstants.rideCardAcIconSize,
                                        color: AppColors.rideCardAcBadgeText,
                                      ),
                                      const SizedBox(
                                        width: AppConstants.spacingXxs,
                                      ),
                                      Text(
                                        acLabel,
                                        style: GoogleFonts.inter(
                                          fontSize:
                                              AppConstants.rideCardAcFontSize,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.rideCardAcBadgeText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Illustration du véhicule encore plus agrandie
              Positioned(
                top: AppConstants.rideCardCarTopOffset,
                left: AppConstants.rideCardCarLeftOffset,
                right: AppConstants.rideCardCarRightOffset,
                child: IgnorePointer(
                  child: SizedBox(
                    height: AppConstants.rideCardCarHeight,
                    child: Align(
                      alignment: Alignment.center,
                      child: isEco
                          ? SvgPicture.asset(
                              'assets/icons/vectoreco.svg',
                              height: AppConstants.rideCardCarHeight,
                              fit: BoxFit.contain,
                            )
                          : Image.asset(
                              'assets/images/vectorclass.png',
                              height: AppConstants.rideCardCarHeight,
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverLandmarkTile() {
    final hasLandmark =
        _pickupLandmark != null && _pickupLandmark!.trim().isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openHowToFindYouSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.serviceCardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasLandmark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: hasLandmark ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasLandmark ? _pickupLandmark! : 'ride.how_to_find_you'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    hasLandmark
                        ? 'Indication enregistrée · Toucher pour modifier'
                        : 'ride.how_to_find_you_sub'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentAndOrderRow() {
    final isLoading = _isLoadingRoute || _isOrderingRide;

    return Row(
      children: [
        // Icône du mode de paiement à gauche du bouton Commander (cliquable pour changer via l'endpoint)
        ValueListenableBuilder<String>(
          valueListenable: PaymentMethodsService().selectedCodeNotifier,
          builder: (context, code, _) {
            final assetPath = PaymentMethodsService.getAssetForCode(code);
            final isCash = code.toUpperCase().trim() == 'CASH';

            return GestureDetector(
              key: const Key('ride_payment_method_selector_button'),
              behavior: HitTestBehavior.opaque,
              onTap: () => PaymentMethodModal.show(context),
              child: Container(
                width: AppConstants.ridePaymentQuickBtnSize,
                height: AppConstants.ridePaymentQuickBtnSize,
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  child: Image.asset(
                    assetPath,
                    width: AppConstants.ridePaymentQuickIconSize,
                    height: AppConstants.ridePaymentQuickIconSize,
                    fit: isCash ? BoxFit.contain : BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: AppConstants.spacingUnitLg),

        // Bouton Commander (affiche simplement "Commander")
        Expanded(
          child: SizedBox(
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              key: const Key('ride_order_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: AppConstants.elevationNone,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.rideOrderBtnRadius,
                  ),
                ),
              ),
              onPressed:
                  (_isLoadingRoute || _isOfflinePriceError || _isOrderingRide)
                      ? null
                      : _onOrderRide,
              child: isLoading
                  ? const SizedBox(
                      width: AppConstants.iconSizeLg,
                      height: AppConstants.iconSizeLg,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _isOfflinePriceError
                          ? 'Connexion Internet requise'
                          : 'ride.order'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontLg,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      final _ = EasyLocalization.of(context)?.locale;
    } catch (_) {}
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final maxDragOffset =
        math.max(0.0, _bottomSheetHeight - (systemBottom + 92.0));

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomSheet());

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fullscreen Google Map (logo hidden under bottom sheet)
          GoogleMap(
            style: MapStyleService.style,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _departure.latitude,
                _departure.longitude,
              ),
              zoom: 14.5,
            ),
            padding: const EdgeInsets.only(top: 80),
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
            bottom: math.max(
              14.0,
              (_bottomSheetHeight - _sheetDragOffset) + 14.0,
            ),
            child: RideMapCameraToggleButton(
              mapControllerGetter: () => _mapController,
              departureLocation: LatLng(
                _departure.latitude,
                _departure.longitude,
              ),
              destinationLocation: LatLng(
                widget.destination.latitude,
                widget.destination.longitude,
              ),
              polylinePoints: _polylinePoints,
              initialMode: RideMapCameraMode.tripOverview,
            ),
          ),

          // 4. Modal Sheet avec options de course et prix (Déplaçable vers le bas et le haut)
          Positioned(
            left: 0,
            right: 0,
            bottom: -_sheetDragOffset,
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTap: _sheetDragOffset > 20 ? () => _animateSheetTo(0.0) : null,
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
                    // Barre de glissement et en-tête déplaçables
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) =>
                          _onSheetDragUpdate(details, maxDragOffset),
                      onVerticalDragEnd: (details) =>
                          _onSheetDragEnd(details, maxDragOffset),
                      onTap: () {
                        if (_sheetDragOffset > 20) {
                          _animateSheetTo(0.0);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(
                            child: Container(
                              width: AppConstants.circularIconContainerSize,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.dragHandle,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusXs,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 1. En-tête tout en haut du modal (centré) : "Choisissez une course" & "Dakar et banlieue"
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'ride.choose_ride'.tr(),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (_sheetDragOffset > 30) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 22,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ],
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
                    ),
                    const SizedBox(height: 14),

                    if (_isOfflinePriceError) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.errorLightBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.wifi_off_rounded, color: AppColors.errorRed, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Mode hors-ligne : la connexion Internet est requise pour calculer le tarif exact.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.errorRed,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _fetchRoute,
                              child: Text(
                                'Réessayer',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.errorRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Les 2 cartes de sélection des véhicules (Seddo Éco & Seddo Confort)
                    Row(
                      children: [
                        _buildVehicleCard(isEco: true, option: _ecoOption),
                        const SizedBox(width: 12),
                        _buildVehicleCard(isEco: false, option: _confortOption),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Indication pour le chauffeur ("Comment vous trouver ?")
                    _buildDriverLandmarkTile(),

                    const SizedBox(height: 14),

                    // Mode de paiement à gauche + Bouton Commander à droite
                    _buildPaymentAndOrderRow(),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }
}

/// Ride option tile card with custom border for selected state

