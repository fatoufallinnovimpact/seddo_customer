import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import 'package:seddo/features/home/data/models/home_suggestions_model.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/home/domain/bloc/home_event.dart';
import 'package:seddo/features/home/domain/bloc/home_state.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/edit_user_position_page.dart';
import 'package:seddo/features/home/presentation/pages/pickup_map_location_picker_page.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/features/home/presentation/widgets/seddo_share_position_sheet.dart';
import 'package:seddo/features/ride/data/services/active_ride_offline_storage.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/utils/active_ride_navigation_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_modal_sheet.dart';
import 'package:seddo/services/network_connectivity_service.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';
import 'package:seddo/features/saved_places/presentation/pages/saved_places_page.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_page.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/services/map_style_service.dart';
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
  Timer? _activeRidePollTimer;
  StreamSubscription<List<NearbyCarModel>>? _realtimeNearbySub;
  StreamSubscription<RealtimeRideStatusEvent>? _realtimeRideStatusSub;

  Map<String, dynamic>? _activeRideData;

  LatLng? _lastNearbyFetchPos;
  HomeSuggestionsModel? _suggestions;
  List<RecentSuggestionModel> _localRecentTrips = [];

  String _currentAddressShort = 'Rue YF-557, 20';
  String _currentAddressDetails = 'Yoff, Almadies, Département de Dakar';
  LatLng? _currentUserLocation;
  GoogleMapController? _miniMapController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Connexion WebSocket sur l'accueil pour recevoir les chauffeurs proches (PDF Seddo page 7)
    RealtimeService().connect();

    _realtimeNearbySub = RealtimeService().nearbyDriversStream.listen((cars) {
      if (mounted && cars.isNotEmpty) {
        // Chauffeurs proches reçus en temps réel sans requête GET
      }
    });

    // Écoute temps réel des changements de statut de course
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

    // Initialisation après le montage du widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<HomeBloc>();
        _currentUserLocation = bloc.state.userLocation;
        _resolveUserLocationAddress(bloc.state.userLocation);
        _fetchNearbyDrivers(bloc.state.userLocation);
        _fetchSuggestions();
        _initRealUserLocation();
        _checkActiveRide();
      }
    });

    // Rafraîchissement périodique passif de secours (uniquement si WebSocket non connecté)
    _nearbyDriversPollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (mounted && !RealtimeService().isConnected) {
          final bloc = context.read<HomeBloc>();
          _fetchNearbyDrivers(_lastNearbyFetchPos ?? bloc.state.userLocation);
        }
      },
    );

    // Vérification active périodique de course en cours (toutes les 3s)
    // Permet de détecter immédiatement un retour sur l'accueil ou un changement de statut
    _activeRidePollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (mounted) {
          _checkActiveRide();
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
    _nearbyDriversPollTimer?.cancel();
    _activeRidePollTimer?.cancel();
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
        _resolveUserLocationAddress(loc);
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
          timeLimit: Duration(seconds: 5),
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
        _resolveUserLocationAddress(loc);
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
    // Si déplacement de plus de 20m, actualiser l'adresse affichée
    if (oldLoc == null ||
        Geolocator.distanceBetween(
              oldLoc.latitude,
              oldLoc.longitude,
              newLoc.latitude,
              newLoc.longitude,
            ) >
            20) {
      _resolveUserLocationAddress(newLoc);
    }
  }

  /// Résout le vrai nom de rue et le quartier pour la position actuelle
  Future<void> _resolveUserLocationAddress(LatLng location) async {
    try {
      final res = await _placesService.reverseGeocode(
        location.latitude,
        location.longitude,
      );
      if (mounted) {
        setState(() {
          if (res.mainText.isNotEmpty) {
            _currentAddressShort = res.mainText;
          }
          if (res.secondaryText.isNotEmpty) {
            _currentAddressDetails = res.secondaryText;
          }
          _currentUserLocation = location;
        });
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
        _miniMapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: location,
              zoom: AppConstants.userPositionMapZoom,
            ),
          ),
        );
      }
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

    _miniMapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: newLoc,
          zoom: AppConstants.userPositionMapZoom,
        ),
      ),
    );

    final bloc = context.read<HomeBloc>();
    bloc.add(HomeUserLocationUpdatedEvent(newLoc));
    _fetchNearbyDrivers(newLoc);
  }

  Future<void> _fetchSuggestions() async {
    try {
      final res = await _rideService.getSuggestions();
      final localRecents = await RecentTripStorage.getRecentTrips();
      if (mounted) {
        setState(() {
          if (res != null) {
            _suggestions = res;
          }
          _localRecentTrips = localRecents;
        });
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
              color: const Color(0xFF0F172A),
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
              padding: const EdgeInsets.only(bottom: AppConstants.spacingTwenty),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top bar aérée : Logo SEDDO à gauche, menu burger à droite
                  _buildTopBar(context),
                  const SizedBox(height: AppConstants.spacingUnitLg),

                  // Si une course ou recherche est en cours, encart proéminent pour y retourner
                  if (_activeRideData != null) ...[
                    _buildActiveRideInlineCard(),
                    const SizedBox(height: AppConstants.spacingUnitLg),
                  ],

                  // 2. Search card aérée : "Où allez-vous ?"
                  _buildSearchBar(context),
                  const SizedBox(height: AppConstants.spacingUnitLg),

                  // 3. Suggestions section : trajets récents listés par ligne
                  _buildSuggestionsSection(context),
                  const SizedBox(height: AppConstants.spacingMd),

                  // 4. Bannière Transports Urbains (TCU) : Voyagez en toute simplicité
                  _buildTcuBanner(context),
                  const SizedBox(height: AppConstants.spacingMd),

                  // 5. Carte de la position actuelle avec mini-carte, bouton "Modifier" et bouton "Partager"
                  _buildCurrentLocationCard(context, state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Top Bar aérée : SEDDO Logo + Burger Menu
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
          // Logo SEDDO seul (statique, pas d'ouverture de modal)
          Text(
            'SEDDO',
            key: const ValueKey('seddo_logo_and_location_header'),
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontTitleLarge,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: AppColors.primary,
              letterSpacing: AppConstants.titleLetterSpacing,
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
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingUnitXl,
        ),
        decoration: BoxDecoration(
          color: AppColors.grayBgLight,
          borderRadius: BorderRadius.circular(AppConstants.radiusDialog),
          border: Border.all(
            color: AppColors.grayBorderDivider,
            width: AppConstants.strokeWidthBorder,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: AppConstants.iconSizeLg,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: AppConstants.spacingUnitLg),
            Expanded(
              child: Text(
                'home.where_to'.tr(),
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontLg,
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
                    fontSize: AppConstants.fontBase,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: AppConstants.userPositionLetterSpacingTight,
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
          const SizedBox(height: AppConstants.spacingSm),

          // Trajets récents listés par ligne avec index unique garanti
          for (int i = 0; i < displayRecents.length; i++)
            _buildRecentTripCard(
              context: context,
              item: displayRecents[i],
              index: i,
            ),

          // Lieu enregistré si disponible
          if (savedItem != null)
            _buildSavedPlaceCard(
              context: context,
              item: savedItem,
            ),
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
          vertical: AppConstants.spacingSm,
          horizontal: AppConstants.spacingXs,
        ),
        child: Row(
          children: [
            Container(
              width: AppConstants.circularButtonSize,
              height: AppConstants.circularButtonSize,
              decoration: const BoxDecoration(
                color: AppColors.grayBgLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.textSecondary,
                size: AppConstants.iconSizeMd,
              ),
            ),
            const SizedBox(width: AppConstants.spacingUnitLg),
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
          vertical: AppConstants.spacingSm,
          horizontal: AppConstants.spacingXs,
        ),
        child: Row(
          children: [
            Container(
              width: AppConstants.circularButtonSize,
              height: AppConstants.circularButtonSize,
              decoration: const BoxDecoration(
                color: AppColors.peachContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForPlaceKind(item.kind),
                color: AppColors.primary,
                size: AppConstants.iconSizeMd,
              ),
            ),
            const SizedBox(width: AppConstants.spacingUnitLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
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

  // Bannière Transports Urbains (TCU) avec TER Dakar et bouton "Itinéraires"
  Widget _buildTcuBanner(BuildContext context) {
    return Container(
      key: const ValueKey('home_tcu_banner_card'),
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingTwenty),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusContainer),
        border: Border.all(
          color: AppColors.grayBorderLight,
          width: AppConstants.strokeWidthBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSubtleBlack,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              SlideRightToLeftRoute(
                page: PublicTransportPage(
                  initialOrigin: _currentAddressShort,
                ),
              ),
            );
          },
          child: Stack(
            children: [


              // Train TER Dakar sur la droite du card : taille réduite, harmonieuse et compacte
              Positioned(
                right: AppConstants.tcuBannerTrainRightOffset,
                top: AppConstants.spacingXs,
                bottom: AppConstants.spacingXs,
                width: AppConstants.tcuBannerTrainWidth,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/images/tcu/ter_train.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),

              // Contenu gauche compact : titre, sous-titre et bouton "Itinéraires"
              Padding(
                padding: const EdgeInsets.only(
                  left: AppConstants.spacingMd,
                  top: AppConstants.spacingUnitLg,
                  bottom: AppConstants.spacingUnitLg,
                  right: AppConstants.tcuBannerContentRightPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Titre "Voyagez en toute simplicité"
                    Text(
                      'home.tcu_banner_title'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontTitle,
                        fontWeight: FontWeight.w900,
                        color: AppColors.pureBlack,
                        height: AppConstants.titleLineHeight,
                        letterSpacing: AppConstants.titleLetterSpacing,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXs),

                    // Sous-titre "TER, BRT, bus AFTU et DDD : planifiez vos déplacements"
                    Text(
                      'home.tcu_banner_subtitle'.tr(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: AppConstants.bannerLineHeight,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingUnit),

                    // Bouton orange "Itinéraires" avec icône boussole
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingUnitLg,
                        vertical: AppConstants.spacingS,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'home.tcu_banner_button'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: AppConstants.fontSm,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingXs),
                            const Icon(
                              Icons.explore_outlined,
                              color: AppColors.white,
                              size: AppConstants.iconSizeSm,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  // Carte de la position actuelle de l'utilisateur avec mini-carte, bouton "Modifier"
  // et bande blanche avec titre du lieu et bouton "Partager" à droite
  Widget _buildCurrentLocationCard(BuildContext context, HomeState state) {
    final loc = _currentUserLocation ?? state.userLocation;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingTwenty),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusDialog),
        border: Border.all(
          color: AppColors.grayBorderLight,
          width: AppConstants.strokeWidthBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSubtleBlack,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Mini-carte Google Map avec marqueur Seddo et bouton "Modifier" en bas à droite
          SizedBox(
            height: AppConstants.userPositionMapHeight,
            width: double.infinity,
            child: ClipRect(
              child: Stack(
                children: [
                  // Fond beige doux pour garantir un affichage beige instantané
                  Container(color: AppColors.mapBeige),

                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: AppConstants.mapLogoClipOffset,
                    child: SizedBox(
                      height: AppConstants.userPositionMapHeight +
                          AppConstants.mapLogoClipExtraHeight,
                      child: GoogleMap(
                        key: const ValueKey('home_current_location_mini_map'),
                  style: MapStyleService.style,
                  initialCameraPosition: CameraPosition(
                    target: loc,
                    zoom: AppConstants.userPositionMapZoom,
                  ),
                  onMapCreated: (ctrl) {
                    _miniMapController = ctrl;
                    MapStyleService.applyStyle(ctrl);
                    final userLoc = _currentUserLocation;
                    if (userLoc != null) {
                      ctrl.moveCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: userLoc,
                            zoom: AppConstants.userPositionMapZoom,
                          ),
                        ),
                      );
                    }
                  },
                  buildingsEnabled: false,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  gestureRecognizers:
                      const <Factory<OneSequenceGestureRecognizer>>{},
                ),
              ),
            ),

                // Overlay cliquable pour ouvrir la carte plein écran
                Positioned.fill(
                  child: Material(
                    color: AppColors.transparent,
                    child: InkWell(
                      key: const ValueKey('home_mini_map_overlay'),
                      onTap: () => _openFullMapPicker(context),
                    ),
                  ),
                ),

                // Marqueur central Seddo sur la mini-carte
                Center(
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: AppConstants.iconSizeHero,
                          height: AppConstants.iconSizeHero,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusDefault,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadowPinBox,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.hail_rounded,
                            color: AppColors.white,
                            size: AppConstants.iconSizeLg,
                          ),
                        ),
                        Container(
                          width: AppConstants.userPositionStalkWidth,
                          height: AppConstants.userPositionStalkHeight,
                          color: AppColors.mapPinAnchor,
                        ),
                        Container(
                          width: AppConstants.userPositionShadowWidth,
                          height: AppConstants.userPositionShadowHeight,
                          decoration: BoxDecoration(
                            color: AppColors.shadowSoftBlack,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusSm,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bouton "Modifier" flottant en bas à droite de la carte
                Positioned(
                  right: AppConstants.spacingUnit,
                  bottom: AppConstants.spacingUnit,
                  child: Material(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusPill,
                    ),
                    elevation: 2,
                    shadowColor: AppColors.shadowCardBlack,
                    child: InkWell(
                      key: const ValueKey('home_edit_position_button'),
                      onTap: () => _openEditPosition(context),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusPill,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingUnitLg,
                          vertical: AppConstants.spacingS,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/edit-pencil-line-01-svgrepo-com.svg',
                              width: AppConstants.iconSizeSm,
                              height: AppConstants.iconSizeSm,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingS),
                            Text(
                              'common.edit'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: AppConstants.fontMd,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

          // 2. Bande blanche : Titre du lieu et adresse à gauche, Bouton "Partager" à droite du titre
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingUnitLg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Titre et détails de la position actuelle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentAddressShort,
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontLg,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing:
                              AppConstants.userPositionLetterSpacingTight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppConstants.spacingXs),
                      Text(
                        _currentAddressDetails,
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontSm,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConstants.spacingUnit),

                // Bouton "Partager" : icône share en noir avec le texte partager (sans rectangle ni cercle vert)
                InkWell(
                  key: const ValueKey('home_share_position_button'),
                  onTap: () => _shareCurrentLocation(context),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingXs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/share-svgrepo-com.svg',
                          width: AppConstants.iconSizeDefault,
                          height: AppConstants.iconSizeDefault,
                          colorFilter: const ColorFilter.mode(
                            AppColors.textPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          'common.share'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontSm,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditPosition(BuildContext context) async {
    final state = context.read<HomeBloc>().state;
    final loc = _currentUserLocation ?? state.userLocation;

    final result = await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: EditUserPositionPage(
          currentLocation: loc,
          currentMainText: _currentAddressShort,
          currentSecondaryText: _currentAddressDetails,
          placesService: _placesService,
        ),
      ),
    );

    if (result != null && mounted) {
      _applyNewUserPosition(result);
    }
  }

  Future<void> _openFullMapPicker(BuildContext context) async {
    final state = context.read<HomeBloc>().state;
    final loc = _currentUserLocation ?? state.userLocation;

    final result = await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: PickupMapLocationPickerPage(
          initialLocation: loc,
          initialMainText: _currentAddressShort,
          initialSecondaryText: _currentAddressDetails,
          placesService: _placesService,
        ),
      ),
    );

    if (result != null && mounted) {
      _applyNewUserPosition(result);
    }
  }

  void _shareCurrentLocation(BuildContext context) {
    final state = context.read<HomeBloc>().state;
    final loc = _currentUserLocation ?? state.userLocation;

    SeddoSharePositionSheet.show(
      context,
      location: loc,
      mainAddress: _currentAddressShort,
      secondaryAddress: _currentAddressDetails,
    );
  }
}


