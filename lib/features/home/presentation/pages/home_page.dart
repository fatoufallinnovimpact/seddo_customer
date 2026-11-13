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
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/features/home/presentation/widgets/user_position_bottom_sheet.dart';
import 'package:seddo/features/ride/data/services/active_ride_offline_storage.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/utils/active_ride_navigation_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_modal_sheet.dart';
import 'package:seddo/services/network_connectivity_service.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';
import 'package:seddo/features/saved_places/presentation/pages/saved_places_page.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_page.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/services/realtime_service.dart';
import 'package:seddo/features/home/presentation/widgets/home_promo_banners_widget.dart';

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
        final short = res.mainText.isNotEmpty ? res.mainText : _currentAddressShort;
        final details = res.secondaryText.isNotEmpty ? res.secondaryText : _currentAddressDetails;

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
      // En mode hors-ligne : la localisation GPS satellite reste 100% active
      if (mounted) {
        setState(() {
          _currentUserLocation = location;
          if (_currentAddressShort.isEmpty ||
              _currentAddressShort == 'Chargement...') {
            _currentAddressShort = 'Position GPS actuelle';
            _currentAddressDetails = 'Mode hors-ligne (signal satellite)';
          }
        });
      }
    }
  }

  /// Ouvre le modal "VOTRE POSITION" au clic sur le logo Seddo ou l'adresse
  Future<void> _openUserPositionModal(BuildContext context) async {
    final state = context.read<HomeBloc>().state;
    final loc = _currentUserLocation ?? state.userLocation;

    final result = await UserPositionBottomSheet.show(
      context,
      userLocation: loc,
      mainAddress: _currentAddressShort,
      secondaryAddress: _currentAddressDetails,
      placesService: _placesService,
    );

    if (result != null && mounted) {
      _applyNewUserPosition(result);
    }
  }

  /// Applique la nouvelle position sélectionnée depuis la carte plein écran ou la recherche
  void _applyNewUserPosition(PlaceSearchResult place) {
    final newLoc = LatLng(place.latitude, place.longitude);
    final short = place.mainText.isNotEmpty
        ? place.mainText
        : (place.fullAddress.isNotEmpty ? place.fullAddress : 'Position sélectionnée');
    final details = place.secondaryText.isNotEmpty
        ? place.secondaryText
        : 'Dakar, Sénégal';

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
        onRetry: () => _openDestinationSearch(),
      );
      return;
    }

    final homeBloc = context.read<HomeBloc>();
    final PlaceSearchResult? selectedPlace =
        await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: PlaceSearchPage(
          currentUserLocation: _currentUserLocation ?? homeBloc.state.userLocation,
          initialPickup: _currentAddressShort,
        ),
      ),
    );

    if (selectedPlace != null && mounted) {
      await RecentTripStorage.saveLastRecentTrip(selectedPlace);
      homeBloc.add(
        HomeSelectDestinationEvent(
          destinationLocation: LatLng(
            selectedPlace.latitude,
            selectedPlace.longitude,
          ),
          destinationAddress: selectedPlace.fullAddress,
        ),
      );
    }

    if (mounted) {
      _fetchSuggestions();
      _checkActiveRide();
    }
  }

  /// Ouvre la recherche pré-remplie vers l'Aéroport Blaise Diagne (AIBD)
  Future<void> _openAeroportReservation() async {
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
        onRetry: () => _openAeroportReservation(),
      );
      return;
    }

    final homeBloc = context.read<HomeBloc>();
    final PlaceSearchResult? selectedPlace =
        await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: PlaceSearchPage(
          currentUserLocation:
              _currentUserLocation ?? homeBloc.state.userLocation,
          initialPickup: _currentAddressShort,
          initialDestination: 'Aéroport Blaise Diagne (AIBD)',
        ),
      ),
    );

    if (selectedPlace != null && mounted) {
      await RecentTripStorage.saveLastRecentTrip(selectedPlace);
      homeBloc.add(
        HomeSelectDestinationEvent(
          destinationLocation: LatLng(
            selectedPlace.latitude,
            selectedPlace.longitude,
          ),
          destinationAddress: selectedPlace.fullAddress,
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

    await Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: PlaceSearchPage(
          initialDepartureResult: departureResult,
          initialDestinationResult: place,
          initialPickup: _currentAddressShort,
          initialDestination: place.mainText,
          currentUserLocation: pickupLocation,
        ),
      ),
    );

    if (mounted) {
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 36.0),
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

                  // 2. Services : Course (voiture) & Transpo (bus AFTU)
                  _buildServiceCards(context),
                  const SizedBox(height: 24),

                  // 3. Search card aérée : "Où allez-vous ?"
                  _buildSearchBar(context),
                  const SizedBox(height: 20),

                  // 4. Bannières automatiques promotionnelles (Seddo en direct, Parrainage, Aéroport, Fidélité)
                  HomePromoBannersWidget(
                    onOpenSeddoDirect: _openDestinationSearch,
                    onOpenAeroport: _openAeroportReservation,
                  ),
                  const SizedBox(height: 26),

                  // 5. Suggestions section : trajets récents listés par ligne aérée
                  _buildSuggestionsSection(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Top Bar aérée : SEDDO Logo + Position de la rue en dessous (cliquables) + Burger Menu
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
          // Logo SEDDO + Vraie position cliquable (ouvre le modal Votre position)
          GestureDetector(
            key: const ValueKey('seddo_logo_and_location_header'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _openUserPositionModal(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo SEDDO (style affirmé inspiré de Yango aux couleurs Seddo)
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
                const SizedBox(height: 5),

                // Vraie localisation de la personne : "Rue YF-557, 20 ›"
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

          // Menu burger à droite (ouvre le drawer sans GlobalKey)
          Builder(
            builder: (scaffoldContext) => _buildTopCircleButton(
              icon: Icons.menu_rounded,
              onTap: () => Scaffold.of(scaffoldContext).openEndDrawer(),
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

  // Barre de recherche aérée "Où allez-vous ?"
  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: _openDestinationSearch,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingTwenty),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: AppColors.slateLightBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.neutralInputBorder,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 24,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'home.where_to'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
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

    // Assurer au moins 2 trajets récents (Dakar)
    final defaultRecents = [
      const RecentSuggestionModel(
        id: 'rec_sea_plaza',
        label: 'Sea Plaza',
        address: 'Corniche Ouest, Dakar',
        lat: 14.6934,
        lng: -17.4729,
      ),
      const RecentSuggestionModel(
        id: 'rec_plateau',
        label: "Place de l'Indépendance",
        address: 'Dakar-Plateau, Dakar',
        lat: 14.6713,
        lng: -17.4326,
      ),
      const RecentSuggestionModel(
        id: 'rec_almadies',
        label: 'Route des Almadies',
        address: 'Almadies, Dakar',
        lat: 14.7450,
        lng: -17.5180,
      ),
    ];

    for (final def in defaultRecents) {
      if (recents.length >= 2) break;
      if (!recents.any((r) => r.label == def.label || r.address == def.address)) {
        recents.add(def);
      }
    }

    final displayRecents = recents.take(2).toList();
    final placesList = _suggestions?.places ?? [];
    final SavedPlaceModel? savedItem =
        placesList.isNotEmpty ? placesList.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingTwenty),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'home.suggestions'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (savedItem != null)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      SlideRightToLeftRoute(
                        page: const SavedPlacesPage(),
                      ),
                    );
                  },
                  child: Text(
                    'home.see_all'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontSm,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Trajets récents listés avec espacement généreux et séparateur léger
          for (int i = 0; i < displayRecents.length; i++) ...[
            _buildRecentTripCard(
              context: context,
              item: displayRecents[i],
              index: i,
            ),
            if (i < displayRecents.length - 1 || savedItem != null)
              const Padding(
                padding: EdgeInsets.only(left: 56, right: 8),
                child: Divider(
                  height: 12,
                  thickness: 0.8,
                  color: AppColors.slateLightBg,
                ),
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
    return InkWell(
      key: ValueKey('recent_suggestion_${item.id}_$index'),
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      onTap: () {
        final place = PlaceSearchResult(
          id: 'recent_${item.id}',
          mainText: item.label,
          secondaryText: item.address,
          fullAddress: item.address.isNotEmpty ? item.address : item.label,
          latitude: item.lat,
          longitude: item.lng,
          category: 'recent',
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
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.slateLightBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.neutralIconGrey,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontMd,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: AppConstants.userPositionLetterSpacingSnug,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.address.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacingXxs),
                    Text(
                      item.address,
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
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.peachContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForPlaceKind(item.kind),
                color: AppColors.primary,
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

  // Nouveaux boutons de service en haut : Course (voiture) et Transpo (bus AFTU)
  Widget _buildServiceCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingTwenty),
      child: Row(
        children: [
          // 1. Service Course
          Expanded(
            child: _buildServiceItem(
              context: context,
              key: const ValueKey('home_service_card_course'),
              title: 'Course',
              imagePath: 'assets/images/seddo_car.png',
              imageHeight: 62,
              onTap: _openDestinationSearch,
            ),
          ),
          const SizedBox(width: 16),
          // 2. Service Transpo
          Expanded(
            child: _buildServiceItem(
              context: context,
              key: const ValueKey('home_service_card_transpo'),
              title: 'Transport en commun',
              imagePath: 'assets/transit/aftu.png',
              imageHeight: 66,
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
    );
  }

  Widget _buildServiceItem({
    required BuildContext context,
    required Key key,
    required String title,
    required String imagePath,
    required VoidCallback onTap,
    double imageHeight = 60,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 104,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.neutralInputBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.neutralInputBorder,
                  width: AppConstants.strokeWidthBorder,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowFaintBlack,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              alignment: Alignment.center,
              child: Image.asset(
                imagePath,
                height: imageHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.directions_car_rounded,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
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

  IconData _iconForPlaceKind(String? kindOrIcon) {
    final norm = (kindOrIcon ?? '').toUpperCase();
    if (norm == 'HOME' || norm.contains('MAISON')) {
      return Icons.home_rounded;
    }
    if (norm == 'WORK' || norm.contains('TRAVAIL') || norm.contains('BUREAU')) {
      return Icons.work_rounded;
    }
    if (norm.contains('AIRPORT') || norm.contains('AEROPORT')) {
      return Icons.flight_takeoff_rounded;
    }
    return Icons.star_rounded;
  }
}





