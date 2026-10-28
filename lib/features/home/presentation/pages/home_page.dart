import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import 'package:seddo/features/home/data/models/home_suggestions_model.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/home/domain/bloc/home_event.dart';
import 'package:seddo/features/home/domain/bloc/home_state.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/features/home/presentation/widgets/user_position_bottom_sheet.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';
import 'package:seddo/features/saved_places/presentation/pages/saved_places_page.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_page.dart';
import 'package:seddo/services/places_service.dart';

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

class _HomePageContentState extends State<_HomePageContent> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RideService _rideService = RideService();
  final PlacesService _placesService = PlacesService();
  late final PageController _pageController;

  int _selectedCardIndex = 0;
  Timer? _nearbyDriversPollTimer;

  NearbyDriversResponseModel? _nearbyDrivers;
  LatLng? _lastNearbyFetchPos;
  HomeSuggestionsModel? _suggestions;
  List<RecentSuggestionModel> _localRecentTrips = [];

  String _currentAddressShort = 'Rue YF-557, 20';
  String _currentAddressDetails = 'Yoff, Almadies, Département de Dakar';
  LatLng? _currentUserLocation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);

    // Initialisation après le montage du widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<HomeBloc>();
        _currentUserLocation = bloc.state.userLocation;
        _resolveUserLocationAddress(bloc.state.userLocation);
        _fetchNearbyDrivers(bloc.state.userLocation);
        _fetchSuggestions();
        _initRealUserLocation();
      }
    });

    // Rafraîchissement périodique des chauffeurs à proximité (toutes les 10s)
    _nearbyDriversPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted) {
          final bloc = context.read<HomeBloc>();
          _fetchNearbyDrivers(_lastNearbyFetchPos ?? bloc.state.userLocation);
        }
      },
    );
  }

  @override
  void dispose() {
    _nearbyDriversPollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Initialise la vraie localisation GPS de l'appareil et résout son adresse réelle
  Future<void> _initRealUserLocation() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final loc = LatLng(lastKnown.latitude, lastKnown.longitude);
        _currentUserLocation = loc;
        await _resolveUserLocationAddress(loc);
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
        _currentUserLocation = loc;
        await _resolveUserLocationAddress(loc);
        if (mounted) {
          context.read<HomeBloc>().add(HomeUserLocationUpdatedEvent(loc));
          _fetchNearbyDrivers(loc);
        }
      }
    } catch (_) {}
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
      }
    } catch (_) {}
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
          _nearbyDrivers = res;
          _lastNearbyFetchPos = location;
        });
      }
    } catch (_) {}
  }

  Future<void> _openDestinationSearch(BuildContext context) async {
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
    }
  }

  Future<void> _onSelectSuggestion(PlaceSearchResult place) async {
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

    Navigator.of(context).push(
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
  }

  void _openPublicTransport(BuildContext context) {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: const PublicTransportPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;

    return Scaffold(
      key: _scaffoldKey,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Top bar aérée : Logo SEDDO à gauche + vraie adresse en dessous, menu burger à droite
                          _buildTopBar(context),
                          const SizedBox(height: 12),

                          // 2. Search card aérée : "Où allez-vous ?"
                          _buildSearchBar(context),
                          const SizedBox(height: 20),

                          // 3. Suggestions section : 2 cartes de trajets récents en base
                          _buildSuggestionsSection(context),

                          // 4. Espace dynamique : pousse les cartes d'offres tout en bas de la page
                          const Spacer(),
                          const SizedBox(height: 16),

                          // 5. Offer cards carousel : Seddo Eco, Seddo Confort, BRT / TCU
                          _buildOfferCardsSection(context),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Top Bar aérée : SEDDO Logo + Adresse de la rue (cliquables) + Burger Menu
  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo SEDDO + Vraie adresse cliquable (ouvre le modal Votre position)
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
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    letterSpacing: -0.6,
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
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Menu burger à droite
          _buildTopCircleButton(
            icon: Icons.menu_rounded,
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
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
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: const Color(0xFF18181A),
          size: 24,
        ),
      ),
    );
  }

  // Barre de recherche aérée "Où allez-vous ?"
  Widget _buildSearchBar(BuildContext context) {
    final bool isTcu = _selectedCardIndex == 2;
    final String placeholder =
        isTcu ? 'Où allez-vous en commun ?' : 'Où allez-vous ?';
    final Color buttonColor =
        isTcu ? const Color(0xFF2E57C7) : const Color(0xFFFF5700);

    return GestureDetector(
      onTap: () {
        if (isTcu) {
          _openPublicTransport(context);
        } else {
          _openDestinationSearch(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(16, 7, 7, 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 24,
              color: Color(0xFF18181A),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                placeholder,
                style: GoogleFonts.inter(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9CA3AF),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                'Aller',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section Suggestions avec 2 cartes de trajets récents depuis la base
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

    // Assurer au moins 2 cartes de trajets récents (Dakar)
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF18181A),
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
                    'Voir tout',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 2 cartes pour les trajets récents
          ...displayRecents.map((item) => _buildRecentTripCard(
                context: context,
                item: item,
              )),

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
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFF6B7280),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF18181A),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.address,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForPlaceKind(item.kind),
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF18181A),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.address,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
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

  // Section Carrousel des cartes d'offres : Eco, Confort, TCU
  Widget _buildOfferCardsSection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _pageController,
            itemCount: 3,
            onPageChanged: (index) {
              setState(() {
                _selectedCardIndex = index;
              });
            },
            itemBuilder: (context, index) => _buildCard(index, context),
          ),
        ),
        const SizedBox(height: 8),
        _buildPaginationDots(),
      ],
    );
  }

  Widget _buildCard(int index, BuildContext context) {
    switch (index) {
      case 0:
        return _buildSeddoEcoCard(context);
      case 1:
        return _buildSeddoConfortCard(context);
      case 2:
        return _buildTcuCard(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSeddoEcoCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDestinationSearch(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF18181A),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5700),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ÉCONOMIQUE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Seddo Eco',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Arrive dans ${_nearbyDrivers?.ecoEtaMinutes ?? 2} min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prix bas · À partir de 1 500 F',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFFFF5700)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '4 places',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF5700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/seddo_eco_3d.png',
              width: 140,
              height: 90,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/car.png',
                width: 140,
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeddoConfortCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDestinationSearch(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF232526), Color(0xFF414345)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8A00),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "PLUS D'ESPACE",
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Seddo Confort',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_nearbyDrivers?.confortCount ?? 3} Confort autour · ${_nearbyDrivers?.confortEtaMinutes ?? 4} min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Berlines récentes & Chauffeurs Pro',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFF8A00)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Top chauffeurs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF8A00),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/seddo_confort_3d.png',
              width: 140,
              height: 90,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/car.png',
                width: 140,
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTcuCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPublicTransport(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x301E3A8A),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4C70DC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SANS VOITURE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bus, BRT, ...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Dem Dikk, AFTU, BRT & TER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(220),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildTransitBadge('D', const Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        _buildTransitBadge('A', const Color(0xFF3B82F6)),
                        const SizedBox(width: 4),
                        _buildTransitBadge('B', const Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        _buildTransitBadge('T', const Color(0xFF8B5CF6)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/tcu/ddd_bus.png',
              width: 135,
              height: 85,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/tcu/brt_bus.png',
                width: 135,
                height: 85,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransitBadge(String letter, Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPaginationDots() {
    final Color activeColor =
        _selectedCardIndex == 2 ? const Color(0xFF3257C9) : const Color(0xFFFF5700);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final bool isActive = index == _selectedCardIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? activeColor : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
