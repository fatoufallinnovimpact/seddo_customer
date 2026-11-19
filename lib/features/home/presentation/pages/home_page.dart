import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import 'package:seddo/features/home/data/models/home_suggestions_model.dart';
import 'package:seddo/features/home/data/services/user_location_storage.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/home/domain/bloc/home_event.dart';
import 'package:seddo/features/home/domain/bloc/home_state.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/widgets/destination_search_bottom_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/ou_allons_nous_card.dart';
import 'package:seddo/features/home/presentation/widgets/user_position_bottom_sheet.dart';
import 'package:seddo/features/ride/presentation/pages/ride_booking_page.dart';
import 'package:seddo/features/ride/data/services/active_ride_offline_storage.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/utils/active_ride_navigation_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_modal_sheet.dart';
import 'package:seddo/services/network_connectivity_service.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_page.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/services/realtime_service.dart';

/// Main Home Screen of Seddo:
/// - Top Bar: SEDDO logo on left + real user street address beneath it (tapping opens "VOTRE POSITION" modal),
///   and circular hamburger menu on right.
/// - Search Card: "Où allez-vous ?"
/// - Suggestions Section: "Suggestions" with last recent trip and real saved place.
/// - Offer Cards Carousel: Seddo Eco, Seddo Confort, BRT / TCU transit card.
/// - La carte en bas a été supprimée au profit du modal plein écran avec sélecteur animé.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc(),
      child: const _HomePageContent(),
    );
  }
}

class _HomePageContent extends StatefulWidget {
  const _HomePageContent();

  @override
  State<_HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<_HomePageContent>
    with WidgetsBindingObserver {
  final RideService _rideService = RideService();
  final PlacesService _placesService = PlacesService();

  Timer? _nearbyDriversPollTimer;
  StreamSubscription<void>? _realtimeReconnectSub;
  StreamSubscription<List<NearbyCarModel>>? _realtimeNearbySub;
  StreamSubscription<RealtimeRideStatusEvent>? _realtimeRideStatusSub;

  Map<String, dynamic>? _activeRideData;

  LatLng? _lastNearbyFetchPos;
  HomeSuggestionsModel? _suggestions;
  List<RecentSuggestionModel> _localRecentTrips = [];

  String _currentAddressShort =
      UserLocationStorage.cached?.addressShort ?? 'Rue YF-557, 20';
  String _currentAddressDetails =
      UserLocationStorage.cached?.addressDetails ?? 'Yoff, Almadies, Département de Dakar';
  LatLng? _currentUserLocation = UserLocationStorage.cached?.location;
  GoogleMapController? _miniMapController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialisation instantanée depuis le cache mémoire et local pour un affichage 100% fluide sans délai
    _suggestions = HomeSuggestionsStorage.cachedSuggestions;
    _localRecentTrips = RecentTripStorage.cachedRecentTrips;

    // Charger immédiatement la dernière position connue depuis SharedPreferences si pas encore en mémoire
    if (UserLocationStorage.cached == null) {
      UserLocationStorage.loadCachedLocation().then((cached) {
        if (cached != null && mounted) {
          setState(() {
            _currentAddressShort = cached.addressShort;
            _currentAddressDetails = cached.addressDetails;
            _currentUserLocation = cached.location;
          });
        }
      });
    }

    HomeSuggestionsStorage.loadSuggestions().then((cached) {
      if (cached != null && mounted && _suggestions == null) {
        setState(() {
          _suggestions = cached;
        });
      }
    });
    RecentTripStorage.getRecentTrips().then((localRecents) {
      if (localRecents.isNotEmpty && mounted && _localRecentTrips.isEmpty) {
        setState(() {
          _localRecentTrips = localRecents;
        });
      }
    });

    // Connexion WebSocket sur l'accueil pour recevoir les chauffeurs proches (PDF Seddo page 7)
    RealtimeService().connect();

    _realtimeNearbySub = RealtimeService().nearbyDriversStream.listen((cars) {
      if (mounted) {
        // Envoi au HomeBloc pour respecter l'architecture BLoC
        context.read<HomeBloc>().add(
              HomeNearbyDriversUpdatedEvent(
                count: cars.length,
              ),
            );
      }
    });

    // Écoute temps réel des changements de statut de course via WebSocket
    _realtimeRideStatusSub = RealtimeService().rideStatusStream.listen((event) {
      if (!mounted) return;
      if (event.status == 'COMPLETED' ||
          event.status.startsWith('CANCEL') ||
          event.status == 'NO_DRIVER') {
        setState(() {
          _activeRideData = null;
        });
      } else {
        _checkActiveRide();
      }
    });

    // Reconnexion WebSocket : synchronisation ponctuelle
    _realtimeReconnectSub = RealtimeService().onReconnect.listen((_) {
      if (mounted) {
        _checkActiveRide();
      }
    });

    // Initialisation après le montage du widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<HomeBloc>();
        _currentUserLocation ??= bloc.state.userLocation;
        // Ne résoudre sur les coordonnées génériques que si aucune adresse n'est connue
        if (UserLocationStorage.cached == null) {
          _resolveUserLocationAddress(_currentUserLocation ?? bloc.state.userLocation);
        }
        _fetchNearbyDrivers(_currentUserLocation ?? bloc.state.userLocation);
        _fetchSuggestions();
        _initRealUserLocation();
        _checkActiveRide();
        AuthRepository().fetchUserProfile();
      }
    });

    // Rafraîchissement périodique passif de secours (uniquement si WebSocket non connecté)
    _nearbyDriversPollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted && !RealtimeService().isConnected) {
          final bloc = context.read<HomeBloc>();
          _fetchNearbyDrivers(_lastNearbyFetchPos ?? bloc.state.userLocation);
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _checkActiveRide();
    }
  }

  StreamSubscription<Position>? _positionStreamSub;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeNearbySub?.cancel();
    _realtimeRideStatusSub?.cancel();
    _realtimeReconnectSub?.cancel();
    _nearbyDriversPollTimer?.cancel();
    _positionStreamSub?.cancel();
    _miniMapController = null;
    super.dispose();
  }

  /// Initialise la vraie localisation GPS de l'appareil, résout son adresse
  /// et écoute en continu les déplacements de l'utilisateur.
  /// Le GPS physique par satellite ne dépend pas d'Internet et s'affiche immédiatement.
  Future<void> _initRealUserLocation() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final loc = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _currentUserLocation = loc;
        });
        _miniMapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: loc,
              zoom: AppConstants.userPositionMapZoom,
            ),
          ),
        );
        final currentCached = UserLocationStorage.cached;
        if (currentCached == null ||
            !UserLocationStorage.isStreetLevelAddress(_currentAddressShort) ||
            Geolocator.distanceBetween(
                  currentCached.location.latitude,
                  currentCached.location.longitude,
                  loc.latitude,
                  loc.longitude,
                ) >
                30) {
          _resolveUserLocationAddress(loc);
        }
      }
    } catch (_) {}

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 7),
        ),
      );
      if (mounted) {
        final loc = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentUserLocation = loc;
        });
        _miniMapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: loc,
              zoom: AppConstants.userPositionMapZoom,
            ),
          ),
        );
        final currentCached = UserLocationStorage.cached;
        if (currentCached == null ||
            !UserLocationStorage.isStreetLevelAddress(_currentAddressShort) ||
            Geolocator.distanceBetween(
                  currentCached.location.latitude,
                  currentCached.location.longitude,
                  loc.latitude,
                  loc.longitude,
                ) >
                30) {
          _resolveUserLocationAddress(loc);
        }
        if (mounted) {
          context.read<HomeBloc>().add(HomeUserLocationUpdatedEvent(loc));
          _fetchNearbyDrivers(loc);
        }
      }

      // Écoute en continu les déplacements physiques
      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (!mounted) return;
        final newLoc = LatLng(pos.latitude, pos.longitude);
        _onUserLocationMoved(newLoc);
      });
    } catch (_) {}
  }

  void _onUserLocationMoved(LatLng newLoc) {
    final oldLoc = _currentUserLocation;
    setState(() {
      _currentUserLocation = newLoc;
    });
    _miniMapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: newLoc,
          zoom: AppConstants.userPositionMapZoom,
        ),
      ),
    );
    if (mounted) {
      context.read<HomeBloc>().add(HomeUserLocationUpdatedEvent(newLoc));
      _fetchNearbyDrivers(newLoc);
    }
    // Si déplacement de plus de 30m, actualiser l'adresse affichée
    if (oldLoc == null ||
        Geolocator.distanceBetween(
              oldLoc.latitude,
              oldLoc.longitude,
              newLoc.latitude,
              newLoc.longitude,
            ) >
            30) {
      _resolveUserLocationAddress(newLoc);
    }
  }

  /// Résout le vrai nom de rue et le quartier pour la position actuelle
  Future<void> _resolveUserLocationAddress(LatLng location) async {
    // 1. Vérifier si l'adresse est déjà en cache mémoire instantané
    final cachedGeocode = UserLocationStorage.getCachedGeocode(location);
    if (cachedGeocode != null) {
      if (mounted) {
        setState(() {
          _currentAddressShort = cachedGeocode.short;
          _currentAddressDetails = cachedGeocode.details;
          _currentUserLocation = location;
        });
      }
      return;
    }

    try {
      final res = await _placesService.reverseGeocode(
        location.latitude,
        location.longitude,
      );
      if (mounted) {
        String short = res.mainText;
        String details = res.secondaryText;

        if (short.isEmpty ||
            short == 'Position sur la carte' ||
            short == 'Position GPS actuelle' ||
            short == 'Position sélectionnée' ||
            short.toLowerCase() == 'dakar' ||
            short.toLowerCase() == 'dakar, sénégal' ||
            short.toLowerCase() == 'dakar, senegal' ||
            RegExp(r'^-?\d+\.\d+').hasMatch(short)) {
          final fallback = PlacesService.getDakarDistrictFallback(
            location.latitude,
            location.longitude,
          );
          short = fallback.mainText;
          details = fallback.secondaryText;
        }

        setState(() {
          _currentAddressShort = short;
          _currentAddressDetails = details;
          _currentUserLocation = location;
        });

        UserLocationStorage.saveLocation(
          addressShort: short,
          addressDetails: details,
          location: location,
        );

        _miniMapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: location,
              zoom: AppConstants.userPositionMapZoom,
            ),
          ),
        );
      }
    } catch (_) {
      // En mode hors-ligne : la localisation GPS satellite reste 100% active avec le quartier Dakar réel
      if (mounted) {
        final fallback = PlacesService.getDakarDistrictFallback(
          location.latitude,
          location.longitude,
        );
        setState(() {
          _currentUserLocation = location;
          if (_currentAddressShort.isEmpty ||
              _currentAddressShort == 'Chargement...' ||
              _currentAddressShort == 'Position sur la carte' ||
              _currentAddressShort == 'Position GPS actuelle' ||
              _currentAddressShort.toLowerCase() == 'dakar' ||
              _currentAddressShort.toLowerCase() == 'dakar, sénégal' ||
              _currentAddressShort.toLowerCase() == 'dakar, senegal' ||
              RegExp(r'^-?\d+\.\d+').hasMatch(_currentAddressShort)) {
            _currentAddressShort = fallback.mainText;
            _currentAddressDetails = fallback.secondaryText;
          }
        });
      }
    }
  }

  /// Ouvre le modal "VOTRE POSITION" au clic sur le logo Seddo ou l'adresse
  Future<void> _openUserPositionModal(BuildContext context) async {
    final state = context.read<HomeBloc>().state;
    final loc = _currentUserLocation ?? state.userLocation;

    String mainAddr = _currentAddressShort;
    String secAddr = _currentAddressDetails;

    if (mainAddr.isEmpty ||
        mainAddr == 'Chargement...' ||
        mainAddr == 'Position sur la carte' ||
        mainAddr == 'Position GPS actuelle' ||
        mainAddr == 'Position sélectionnée' ||
        mainAddr.toLowerCase() == 'dakar' ||
        mainAddr.toLowerCase() == 'dakar, sénégal' ||
        mainAddr.toLowerCase() == 'dakar, senegal' ||
        RegExp(r'^-?\d+\.\d+').hasMatch(mainAddr)) {
      final fallback = PlacesService.getDakarDistrictFallback(
        loc.latitude,
        loc.longitude,
      );
      mainAddr = fallback.mainText;
      secAddr = fallback.secondaryText;
    }

    final result = await UserPositionBottomSheet.show(
      context,
      userLocation: loc,
      mainAddress: mainAddr,
      secondaryAddress: secAddr,
      placesService: _placesService,
    );

    if (result != null && mounted) {
      _applyNewUserPosition(result);
    }
  }

  /// Applique la nouvelle position sélectionnée depuis la carte plein écran ou la recherche
  void _applyNewUserPosition(PlaceSearchResult place) {
    final newLoc = LatLng(place.latitude, place.longitude);
    String short = place.mainText.isNotEmpty
        ? place.mainText
        : (place.fullAddress.isNotEmpty ? place.fullAddress : '');
    String details = place.secondaryText.isNotEmpty
        ? place.secondaryText
        : 'Dakar, Sénégal';

    if (short.isEmpty ||
        short == 'Position sur la carte' ||
        short == 'Position sélectionnée' ||
        short == 'Position GPS actuelle' ||
        RegExp(r'^-?\d+\.\d+').hasMatch(short)) {
      final fallback = PlacesService.getDakarDistrictFallback(
        place.latitude,
        place.longitude,
      );
      short = fallback.mainText;
      details = fallback.secondaryText;
    }

    setState(() {
      _currentAddressShort = short;
      _currentAddressDetails = details;
      _currentUserLocation = newLoc;
    });

    final bloc = context.read<HomeBloc>();
    bloc.add(HomeUserLocationUpdatedEvent(newLoc));
    _fetchNearbyDrivers(newLoc);
  }

  Future<void> _fetchSuggestions() async {
    // 1. Charger immédiatement les données locales sans attendre le réseau
    RecentTripStorage.getRecentTrips().then((localRecents) {
      if (localRecents.isNotEmpty && mounted) {
        if (_localRecentTrips.length != localRecents.length) {
          setState(() {
            _localRecentTrips = localRecents;
          });
        }
      }
    });

    // 2. Mettre à jour en arrière-plan via l'API et rafraîchir le cache
    try {
      final res = await _rideService.getSuggestions();
      if (res != null && mounted) {
        await HomeSuggestionsStorage.saveSuggestions(res);
        if (_suggestions != res) {
          setState(() {
            _suggestions = res;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchNearbyDrivers(LatLng location) async {
    try {
      final res = await _rideService.getNearbyDrivers(
        lat: location.latitude,
        lng: location.longitude,
      );
      if (res != null && mounted) {
        setState(() {
          _lastNearbyFetchPos = location;
        });
        context.read<HomeBloc>().add(
              HomeNearbyDriversUpdatedEvent(
                count: res.totalCount,
              ),
            );
      }
    } catch (_) {}
  }

  /// Interroge le serveur pour vérifier si une course est en cours
  Future<void> _checkActiveRide() async {
    try {
      final res = await _rideService.getCurrentRide();
      if (!mounted) return;
      if (res != null && res['ride'] != null) {
        final ride = res['ride'] as Map<String, dynamic>;
        final status = (ride['status'] as String? ?? '').toUpperCase();
        if (status != 'COMPLETED' &&
            !status.startsWith('CANCEL') &&
            status != 'NO_DRIVER' &&
            status != 'NO_SHOW' &&
            status != 'PAYMENT_PENDING' &&
            status != 'PENDING' &&
            status.isNotEmpty) {
          setState(() {
            _activeRideData = ride;
          });
          return;
        } else {
          ActiveRideOfflineStorage.clearActiveRide();
        }
      } else if (res != null && res['ride'] == null) {
        ActiveRideOfflineStorage.clearActiveRide();
      }
      if (_activeRideData != null) {
        setState(() {
          _activeRideData = null;
        });
      }
    } catch (_) {
      // Si la requête réseau échoue (ex: hors-ligne), vérifier la sauvegarde locale
      try {
        final cached = await ActiveRideOfflineStorage.getActiveRide();
        if (cached != null && mounted) {
          setState(() {
            _activeRideData = cached;
          });
        }
      } catch (_) {}
    }
  }

  /// Ouvre l'écran correspondant à la course active (DriverSearch, DriverApproaching ou ActiveRide)
  void _navigateToActiveRide() {
    if (_activeRideData == null) return;
    final page = ActiveRideNavigationHelper.resolveActiveRidePage(
      _activeRideData!,
      rideService: _rideService,
    );
    if (page != null && mounted) {
      Navigator.of(context).push(
        SlideRightToLeftRoute(page: page),
      ).then((_) {
        if (mounted) {
          _checkActiveRide();
        }
      });
    }
  }

  /// Boîte de dialogue avertissant qu'une course est déjà en cours et proposant de la rejoindre
  void _showActiveRideReminderDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Course en cours',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: AppConstants.fontLg,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Vous avez déjà une course active en cours. Souhaitez-vous retourner à la carte pour suivre son avancement ?',
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontSm,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Fermer',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _navigateToActiveRide();
              },
              child: Text(
                'Voir la course',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openDestinationSearch() async {
    // Si une course est déjà active en cache local, afficher le rappel
    if (_activeRideData != null) {
      _showActiveRideReminderDialog(context);
      return;
    }
    // Rafraîchir l'état de la course en arrière-plan sans bloquer l'ouverture
    unawaited(_checkActiveRide());

    final homeBloc = context.read<HomeBloc>();
    final DestinationSearchSheetResult? searchResult =
        await DestinationSearchBottomSheet.show(
      context,
      currentUserLocation: _currentUserLocation ?? homeBloc.state.userLocation,
      initialPickup: _currentAddressShort,
      currentAddressDetails: _currentAddressDetails,
    );

    if (searchResult != null && mounted) {
      final selectedPlace = searchResult.destination;
      final departureResult = searchResult.departure;

      if (departureResult.mainText.isNotEmpty &&
          departureResult.mainText != _currentAddressShort) {
        setState(() {
          _currentAddressShort = departureResult.mainText;
          _currentAddressDetails = departureResult.secondaryText;
        });
      }

      await RecentTripStorage.saveLastRecentTrip(selectedPlace);
      if (!mounted) return;
      homeBloc.add(
        HomeSelectDestinationEvent(
          destinationLocation: LatLng(
            selectedPlace.latitude,
            selectedPlace.longitude,
          ),
          destinationAddress: selectedPlace.fullAddress,
        ),
      );

      RideService.clearActiveRideData();
      RealtimeService().clearLastRideStatus();

      await Navigator.of(context).push(
        SlideRightToLeftRoute(
          page: RideBookingPage(
            departure: departureResult,
            destination: selectedPlace,
            placesService: PlacesService(),
            showHowToFindYouInitially: true,
          ),
        ),
      );
    }

    if (mounted) {
      _fetchSuggestions();
      _checkActiveRide();
    }
  }

  Future<void> _onSelectSuggestion(PlaceSearchResult place) async {
    await _checkActiveRide();
    if (!mounted) return;
    if (_activeRideData != null) {
      _showActiveRideReminderDialog(context);
      return;
    }

    final isOnline = await NetworkConnectivityService.isConnected;
    if (!mounted) return;
    if (!isOnline) {
      await OfflineModalSheet.show(
        context,
        currentPosition: _currentUserLocation,
        currentAddress: '$_currentAddressShort, $_currentAddressDetails',
        onRetry: () => _onSelectSuggestion(place),
      );
      return;
    }

    final homeBloc = context.read<HomeBloc>();
    await RecentTripStorage.saveLastRecentTrip(place);
    if (!mounted) return;

    final pickupLocation = _currentUserLocation ?? homeBloc.state.userLocation;
    final PlaceSearchResult departureResult = PlaceSearchResult(
      id: 'pickup_current',
      mainText: _currentAddressShort,
      secondaryText: _currentAddressDetails,
      fullAddress: '$_currentAddressShort, $_currentAddressDetails',
      latitude: pickupLocation.latitude,
      longitude: pickupLocation.longitude,
      category: 'pickup',
    );

    RideService.clearActiveRideData();
    RealtimeService().clearLastRideStatus();

    await Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: RideBookingPage(
          departure: departureResult,
          destination: place,
          placesService: PlacesService(),
          showHowToFindYouInitially: true,
        ),
      ),
    );

    if (mounted) {
      _fetchSuggestions();
      _checkActiveRide();
    }
  }


  /// Carte d'accès direct bien visible au sommet de l'accueil lorsqu'une course ou recherche est en cours
  Widget _buildActiveRideInlineCard() {
    if (_activeRideData == null) return const SizedBox.shrink();

    final status = (_activeRideData!['status'] as String? ?? '').toUpperCase();
    final isSearching = status == 'SEARCHING' || status == 'PAYMENT_PENDING';
    final title = isSearching
        ? 'Recherche d\'un chauffeur en cours...'
        : (status.contains('ARRIV')
            ? 'Votre chauffeur est arrivé sur place'
            : (status.contains('PROGRESS') || status.contains('TRIP')
                ? 'Course en cours vers votre destination'
                : 'Chauffeur en approche'));
    final subtitle = isSearching
        ? 'Commande active. Appuyez pour suivre la recherche en direct'
        : 'Appuyez pour revenir sur la carte et voir votre chauffeur';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingTwenty),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToActiveRide,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.slateDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSearching ? Icons.radar_rounded : Icons.directions_car_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Voir',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;

    return Scaffold(
      endDrawer: const SeddoDrawerWidget(),
      endDrawerEnableOpenDragGesture: true,
      backgroundColor: Colors.white,
      body: BlocConsumer<HomeBloc, HomeState>(
        listenWhen: (prev, curr) => prev.userLocation != curr.userLocation,
        listener: (context, state) {
          _resolveUserLocationAddress(state.userLocation);
          if (_lastNearbyFetchPos == null ||
              _lastNearbyFetchPos != state.userLocation) {
            _fetchNearbyDrivers(state.userLocation);
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.white,
              onRefresh: () async {
                final loc = _currentUserLocation;
                if (loc != null) {
                  _resolveUserLocationAddress(loc);
                  _fetchNearbyDrivers(loc);
                }
                await _fetchSuggestions();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 60.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top bar aérée : Logo SEDDO à gauche, menu burger à droite
                    _buildTopBar(context),
                    const SizedBox(height: 28),

                    // Si une course ou recherche est en cours, encart proéminent pour y retourner
                    if (_activeRideData != null) ...[
                      _buildActiveRideInlineCard(),
                      const SizedBox(height: 22),
                    ],

                    // 2. Services : Livraison & Transport à gauche, Courses à droite
                    _buildServiceCards(context),
                    const SizedBox(height: 24),

                    // 3. Search card aérée : "Où allez-vous ?"
                    _buildSearchBar(context),
                    const SizedBox(height: 24),

                    // 4. Suggestions section : trajets récents listés par ligne aérée
                    _buildSuggestionsSection(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Top Bar aérée : SEDDO Logo + Position de la rue juste en dessous (cliquables) + Burger Menu
  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingTwenty,
        AppConstants.spacingUnitXl,
        AppConstants.spacingTwenty,
        AppConstants.spacingSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo SEDDO + Position actuelle juste en dessous (ouvre le modal Votre position)
          GestureDetector(
            key: const ValueKey('seddo_logo_and_location_header'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _openUserPositionModal(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo SEDDO
                Text(
                  'SEDDO',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontTitleLarge,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    letterSpacing: AppConstants.titleLetterSpacing,
                  ),
                ),
                const SizedBox(height: 4),

                // Ma position actuelle juste en bas du logo SEDDO
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                      ),
                      child: Text(
                        _currentAddressShort,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 17,
                      height: 17,
                      decoration: const BoxDecoration(
                        color: AppColors.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.white,
                        size: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Menu burger à droite (ouvre la page Mon compte en plein écran)
          Builder(
            builder: (scaffoldContext) => _buildTopCircleButton(
              icon: Icons.menu_rounded,
              onTap: () => Navigator.of(scaffoldContext).push(
                SlideRightToLeftRoute(
                  page: const SeddoDrawerWidget(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppConstants.circularPickerSize,
        height: AppConstants.circularPickerSize,
        decoration: const BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowCardBlack,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: AppColors.textPrimary,
          size: AppConstants.iconSizeLg,
        ),
      ),
    );
  }

  // Barre de recherche "Où allons-nous ?" avec voiture animée carr.png et route défilante
  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingTwenty),
      child: OuAllonsNousCard(
        label: 'home.where_to'.tr(),
        onTap: _openDestinationSearch,
      ),
    );
  }

  // Section Suggestions : trajets récents listés par ligne (sans container carte)
  Widget _buildSuggestionsSection(BuildContext context) {
    final List<RecentSuggestionModel> recents = [];

    if (_suggestions?.recent != null) {
      recents.addAll(_suggestions!.recent);
    }

    for (final local in _localRecentTrips) {
      if (!recents.any((r) =>
          r.label == local.label ||
          (r.lat == local.lat && r.lng == local.lng))) {
        recents.add(local);
      }
    }

    // Assurer au moins 2 trajets récents de référence (Dakar)
    final defaultRecents = [
      const RecentSuggestionModel(
        id: 'rec_liberte_6',
        label: 'Liberté 6 Extension',
        address: 'Rue LIB 42, Dakar',
        lat: 14.7214,
        lng: -17.4619,
      ),
      const RecentSuggestionModel(
        id: 'rec_8_ave_place_116',
        label: 'Place 116',
        address: '8 Avenue Place 116, Dakar',
        lat: 14.6980,
        lng: -17.4520,
      ),
      const RecentSuggestionModel(
        id: 'rec_2527_rue_dd_98',
        label: 'Grand Yoff',
        address: '2527 Rue DD 98, Dakar',
        lat: 14.7350,
        lng: -17.4480,
      ),
    ];

    for (final def in defaultRecents) {
      if (recents.length >= 3) break;
      final defKey = def.label.trim().toLowerCase();
      if (!recents.any((r) => r.label.trim().toLowerCase() == defKey)) {
        recents.add(def);
      }
    }

    final displayRecents = recents.take(3).toList();
    final placesList = _suggestions?.places ?? [];
    final SavedPlaceModel? savedItem =
        placesList.isNotEmpty ? placesList.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingTwenty),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trajets récents listés avec espacement élégant sans trait séparateur
          for (int i = 0; i < displayRecents.length; i++) ...[
            _buildRecentTripCard(
              context: context,
              item: displayRecents[i],
              index: i,
            ),
          ],

          // Lieu enregistré si disponible
          if (savedItem != null) ...[
            _buildSavedPlaceCard(
              context: context,
              item: savedItem,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentTripCard({
    required BuildContext context,
    required RecentSuggestionModel item,
    required int index,
  }) {
    final hierarchy = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
      item.label,
      item.address,
    );
    final title = hierarchy.title;
    final subtitle = hierarchy.subtitle;

    final isHome = title.trim().toLowerCase() == 'maison' ||
        title.trim().toLowerCase().startsWith('maison ') ||
        subtitle.trim().toLowerCase() == 'maison';
    final isWork = title.trim().toLowerCase() == 'travail' ||
        title.trim().toLowerCase().startsWith('travail ') ||
        subtitle.trim().toLowerCase() == 'travail';

    return InkWell(
      key: ValueKey('recent_suggestion_${item.id}_$index'),
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      onTap: () {
        final place = PlaceSearchResult(
          id: 'recent_${item.id}',
          mainText: title,
          secondaryText: subtitle,
          fullAddress: item.address.isNotEmpty ? item.address : item.label,
          latitude: item.lat,
          longitude: item.lng,
          category: 'recent',
        );
        _onSelectSuggestion(place);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: AppConstants.spacingXs,
        ),
        child: Row(
          children: [
            if (isHome)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.home_outlined,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              )
            else if (isWork)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.work_outline_rounded,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.recentTripIconGrey,
                  size: 22,
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontMd,
                      fontWeight: FontWeight.w700,
                      color: AppColors.nearBlack,
                      letterSpacing: AppConstants.userPositionLetterSpacingSnug,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacingXxs),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPlaceCard({
    required BuildContext context,
    required SavedPlaceModel item,
  }) {
    return InkWell(
      key: ValueKey('saved_place_${item.id}'),
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      onTap: () {
        final place = PlaceSearchResult(
          id: 'saved_${item.id}',
          mainText: item.name,
          secondaryText: item.address,
          fullAddress: item.address,
          latitude: item.latitude,
          longitude: item.longitude,
        );
        _onSelectSuggestion(place);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: AppConstants.spacingXs,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                _iconForPlaceKind(item.kind, item.iconType),
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.address,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nouveaux boutons de service en haut : Livraison & Transport (colonne gauche) et Courses (grand card à droite)
  Widget _buildServiceCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingTwenty),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Colonne de gauche : 2 cartes carrées empilées (Livraison en haut, Transport en bas)
            // Format équilibré et compact avec la carte Course
            Expanded(
              flex: 44,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Carte Livraison (sans redirection) : la moto dépasse en haut dans la partie blanche
                  Expanded(
                    child: _buildSmallServiceCard(
                      context: context,
                      key: const ValueKey('home_service_card_livraison'),
                      title: 'Livraison',
                      imagePath: 'assets/images/livraison.png',
                      fallbackIcon: Icons.two_wheeler_rounded,
                      isDeliveryMoto: true,
                      onTap: () {
                        // Pas de redirection pour livraison selon la demande utilisateur
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Carte Transport (redirection vers Transport en commun) : le bus sort un peu vers la droite
                  Expanded(
                    child: _buildSmallServiceCard(
                      context: context,
                      key: const ValueKey('home_service_card_transpo'),
                      title: 'Transport',
                      imagePath: 'assets/images/bus-removebg.png',
                      fallbackIcon: Icons.directions_bus_rounded,
                      isTransportBus: true,
                      onTap: () {
                        final homeBloc = context.read<HomeBloc>();
                        Navigator.of(context).push(
                          SlideRightToLeftRoute(
                            page: PublicTransportPage(
                              initialOrigin: _currentAddressShort,
                              initialOriginLocation: _currentUserLocation ?? homeBloc.state.userLocation,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 2. Colonne de droite : Grand card Courses (hauteur égale à la somme livraison + transport)
            // Format réduit harmonieux, la voiture vient du côté droit avec son avant dynamique en 3D
            Expanded(
              flex: 56,
              child: _buildLargeCourseCard(
                context: context,
                key: const ValueKey('home_service_card_course'),
                imagePath: 'assets/images/course_car.png',
                onTap: _openDestinationSearch,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallServiceCard({
    required BuildContext context,
    required Key key,
    required String title,
    required String imagePath,
    required IconData fallbackIcon,
    required VoidCallback onTap,
    bool isDeliveryMoto = false,
    bool isTransportBus = false,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.transparent,
        highlightColor: AppColors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 70,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Conteneur capsule gris unique sans bordure (format réduit)
                  Container(
                    width: double.infinity,
                    height: 58,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: AppColors.serviceCardBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadowFaintBlack,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  if (isDeliveryMoto)
                    // Moto de livraison : proportionnée et dépasse un peu en haut
                    Positioned(
                      top: -8,
                      bottom: 4,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          fallbackIcon,
                          size: 28,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (isTransportBus)
                    // Bus : proportionné et aligné verticalement sur le bord droit de la carte (comme le conteneur de livraison)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 12,
                      bottom: 4,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerRight,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          fallbackIcon,
                          size: 28,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      top: 10,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            fallbackIcon,
                            size: 28,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeCourseCard({
    required BuildContext context,
    required Key key,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.transparent,
        highlightColor: AppColors.transparent,
        child: ClipRect(
          clipper: const _CourseCardRightClipper(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Conteneur capsule gris unique sans bordure (aligné au sommet sur le card de livraison à top: 10)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      margin: const EdgeInsets.fromLTRB(0, 10, 0, 2),
                      decoration: BoxDecoration(
                        color: AppColors.serviceCardBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowFaintBlack,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    // Voiture Course 3D (assets/images/course_car.png) :
                    // Agrandie et remontée pour se positionner visuellement
                    // à la hauteur de l'intervalle entre Livraison et Transport
                    Positioned(
                      left: 12,
                      right: -22,
                      top: 8,
                      bottom: 24,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomLeft,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.directions_car_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Courses',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slateDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                        TextSpan(
                          text: ' • ',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextSpan(
                          text: 'à partir de 4 min',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForPlaceKind(String? kindOrIcon, [String? fallbackIconType]) {
    final norm = (kindOrIcon ?? fallbackIconType ?? '').toUpperCase();
    if (norm == 'HOME' || norm.contains('MAISON')) {
      return Icons.home_outlined;
    }
    if (norm == 'WORK' || norm.contains('TRAVAIL') || norm.contains('BUREAU')) {
      return Icons.work_outline_rounded;
    }
    if (norm.contains('AIRPORT') || norm.contains('AEROPORT')) {
      return Icons.flight_rounded;
    }
    if (norm.contains('HEART') || norm.contains('FAVORIS')) {
      return Icons.favorite_border_rounded;
    }
    if (norm.contains('GYM') || norm.contains('SPORT')) {
      return Icons.fitness_center_rounded;
    }
    return Icons.star_border_rounded;
  }
}

/// Clipper qui coupe strictement le côté droit (x > size.width) pour ne pas déborder hors écran,
/// tout en laissant le bas et la gauche complètement ouverts pour l'effet 3D en relief.
class _CourseCardRightClipper extends CustomClipper<Rect> {
  const _CourseCardRightClipper();

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(-50, -20, size.width + 50, size.height + 70);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}





