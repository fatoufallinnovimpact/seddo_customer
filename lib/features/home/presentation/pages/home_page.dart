import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/home/domain/bloc/home_event.dart';
import 'package:seddo/features/home/domain/bloc/home_state.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_page.dart';

/// Main Home Screen of Seddo:
/// - Full-screen interactive Google Map with top-down cars from assets/images/car.png
///   and smooth pulsatile orange radar circles around user location.
/// - Butter-smooth gestures (uninterrupted pinch-to-zoom and pan).
/// - Floating Top Bar: Circular Menu button, white SEDDO pill, Circular Notification button.
/// - Floating Bottom Map Controls: Vehicle indicator pill and GPS recenter button.
/// - Bottom Sheet: Rounded container with search bar and offer cards with transparent background images.
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
  late final PageController _pageController;

  GoogleMapController? _mapController;
  int _selectedCardIndex = 0;

  Timer? _pulseTimer;
  int _pulseStep = 0;
  bool _isCameraMoving = false;

  BitmapDescriptor? _userLocationIcon;
  BitmapDescriptor? _userHaloIcon;
  BitmapDescriptor? _ecoCarIcon;
  BitmapDescriptor? _confortCarIcon;
  BitmapDescriptor? _destPinIcon;
  final Map<String, BitmapDescriptor> _transitIcons = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);

    // Gentle pulsating radar effect: updates only ~1.3 times per second
    // and automatically pauses while user is zooming/panning to ensure 120 FPS buttery smoothness
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (mounted && !_isCameraMoving) {
        setState(() {
          _pulseStep = (_pulseStep + 1) % 3;
        });
      }
    });

    _loadCustomMarkers();
  }

  Future<void> _loadCustomMarkers() async {
    // 1. User location marker
    BitmapDescriptor? userLoc;
    try {
      userLoc = await MapMarkerHelper.getUserLocationMarker();
    } catch (_) {}
    final userHalo = await MapMarkerHelper.getUserLocationHaloMarker();

    // 2. Real car.png asset from assets/images/car.png
    BitmapDescriptor? ecoCar;
    BitmapDescriptor? confortCar;

    try {
      final byteData = await rootBundle.load('assets/images/car.png');
      ecoCar = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
    } catch (_) {
      ecoCar = await MapMarkerHelper.getEcoCarMarker();
    }

    try {
      final byteData =
          await rootBundle.load('assets/images/confort_car_marker.png');
      confortCar = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
    } catch (_) {
      confortCar = ecoCar;
    }

    final dest = await MapMarkerHelper.getDestinationPinMarker();

    final stopD = await MapMarkerHelper.getTransitStopLetterMarker(
      letter: 'D',
      color: AppColors.transitDakarDemDikk,
    );
    final stopA = await MapMarkerHelper.getTransitStopLetterMarker(
      letter: 'A',
      color: AppColors.transitAftu,
    );
    final stopB = await MapMarkerHelper.getTransitStopLetterMarker(
      letter: 'B',
      color: AppColors.transitBrt,
    );
    final stopT = await MapMarkerHelper.getTransitStopLetterMarker(
      letter: 'T',
      color: AppColors.transitTer,
    );

    if (mounted) {
      setState(() {
        _userLocationIcon = userLoc ?? userHalo;
        _userHaloIcon = userHalo;
        _ecoCarIcon = ecoCar;
        _confortCarIcon = confortCar;
        _destPinIcon = dest;
        _transitIcons['D'] = stopD;
        _transitIcons['A'] = stopA;
        _transitIcons['B'] = stopB;
        _transitIcons['T'] = stopT;
      });
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _pageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _openDestinationSearch(BuildContext context) async {
    final homeBloc = context.read<HomeBloc>();
    final PlaceSearchResult? selectedPlace =
        await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: PlaceSearchPage(
          currentUserLocation: homeBloc.state.userLocation,
        ),
      ),
    );

    if (selectedPlace != null && mounted) {
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
  }

  void _openPublicTransport(BuildContext context) {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: const PublicTransportPage(),
      ),
    );
  }

  /// Generates the pulsating radar halo circles around user location
  Set<Circle> _buildCircles(HomeState state) {
    final double pulseRadius;
    final double pulseAlpha;

    switch (_pulseStep) {
      case 0:
        pulseRadius = 26.0;
        pulseAlpha = 0.35;
        break;
      case 1:
        pulseRadius = 45.0;
        pulseAlpha = 0.22;
        break;
      case 2:
      default:
        pulseRadius = 64.0;
        pulseAlpha = 0.10;
        break;
    }

    return {
      // Expanding pulsating radar wave
      Circle(
        circleId: const CircleId('user_radar_pulse'),
        center: state.userLocation,
        radius: pulseRadius,
        fillColor: const Color(0xFFFF6B00).withValues(alpha: pulseAlpha),
        strokeColor:
            const Color(0xFFFF6B00).withValues(alpha: pulseAlpha * 1.8),
        strokeWidth: 2,
        zIndex: 1,
      ),
      // Solid inner core halo
      Circle(
        circleId: const CircleId('user_radar_core'),
        center: state.userLocation,
        radius: 16.0,
        fillColor: const Color(0xFFFF6B00).withValues(alpha: 0.25),
        strokeColor: const Color(0xFFFF6B00).withValues(alpha: 0.55),
        strokeWidth: 2,
        zIndex: 2,
      ),
    };
  }

  Set<Marker> _buildMarkers(HomeState state) {
    final Set<Marker> markers = {};

    // 1. User Position Marker
    if (_userLocationIcon != null || _userHaloIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: state.userLocation,
          icon: _userLocationIcon ?? _userHaloIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 10,
        ),
      );
    }

    // 2. Dynamic vehicle or transit markers based on active card
    if (_selectedCardIndex == 0) {
      // Seddo Eco: 5 dark Eco cars from assets/images/car.png
      if (_ecoCarIcon != null) {
        for (final driver in state.drivers.take(5)) {
          markers.add(
            Marker(
              markerId: MarkerId('eco_car_${driver.id}'),
              position: LatLng(driver.latitude, driver.longitude),
              icon: _ecoCarIcon!,
              rotation: driver.heading,
              anchor: const Offset(0.5, 0.5),
              flat: true,
              zIndexInt: 5,
            ),
          );
        }
      }
    } else if (_selectedCardIndex == 1) {
      // Seddo Confort: 3 orange Confort cars
      if (_confortCarIcon != null) {
        final confortDrivers = [
          if (state.drivers.isNotEmpty) state.drivers[0],
          if (state.drivers.length > 1) state.drivers[1],
          if (state.drivers.length > 3) state.drivers[3],
        ];
        for (final driver in confortDrivers) {
          markers.add(
            Marker(
              markerId: MarkerId('confort_car_${driver.id}'),
              position: LatLng(driver.latitude, driver.longitude),
              icon: _confortCarIcon!,
              rotation: driver.heading,
              anchor: const Offset(0.5, 0.5),
              flat: true,
              zIndexInt: 5,
            ),
          );
        }
      }
    } else if (_selectedCardIndex == 2) {
      // TCU: 5 transit stop markers (D, A, A, B, T) around user
      final uLat = state.userLocation.latitude;
      final uLng = state.userLocation.longitude;

      final transitStops = [
        {'id': 'stop_D', 'letter': 'D', 'lat': uLat + 0.0018, 'lng': uLng - 0.0016},
        {'id': 'stop_A1', 'letter': 'A', 'lat': uLat + 0.0022, 'lng': uLng + 0.0007},
        {'id': 'stop_A2', 'letter': 'A', 'lat': uLat + 0.0013, 'lng': uLng + 0.0020},
        {'id': 'stop_B', 'letter': 'B', 'lat': uLat - 0.0014, 'lng': uLng - 0.0019},
        {'id': 'stop_T', 'letter': 'T', 'lat': uLat - 0.0015, 'lng': uLng + 0.0022},
      ];

      for (final stop in transitStops) {
        final letter = stop['letter'] as String;
        final icon = _transitIcons[letter];
        if (icon != null) {
          markers.add(
            Marker(
              markerId: MarkerId(stop['id'] as String),
              position: LatLng(stop['lat'] as double, stop['lng'] as double),
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 5,
            ),
          );
        }
      }
    }

    // 3. Destination Pin (if selected)
    if (state.destinationLocation != null && _destPinIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination_location'),
          position: state.destinationLocation!,
          icon: _destPinIcon!,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 12,
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SeddoDrawerWidget(),
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: 60,
      backgroundColor: Colors.white,
      body: BlocConsumer<HomeBloc, HomeState>(
        listenWhen: (prev, curr) =>
            prev.userLocation != curr.userLocation ||
            prev.destinationLocation != curr.destinationLocation,
        listener: (context, state) {
          if (state.destinationLocation != null) {
            final south = math.min(
              state.userLocation.latitude,
              state.destinationLocation!.latitude,
            );
            final north = math.max(
              state.userLocation.latitude,
              state.destinationLocation!.latitude,
            );
            final west = math.min(
              state.userLocation.longitude,
              state.destinationLocation!.longitude,
            );
            final east = math.max(
              state.userLocation.longitude,
              state.destinationLocation!.longitude,
            );

            final bounds = LatLngBounds(
              southwest: LatLng(south, west),
              northeast: LatLng(north, east),
            );

            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 70),
            );
          }
        },
        builder: (context, state) {
          final markers = _buildMarkers(state);
          final circles = _buildCircles(state);

          return Stack(
            children: [
              // 1. Full-screen Google Map with smooth native gestures (pinch-to-zoom, pan, tilt, rotate)
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: state.userLocation,
                    zoom: 15.6,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onCameraMoveStarted: () {
                    _isCameraMoving = true;
                  },
                  onCameraIdle: () {
                    _isCameraMoving = false;
                  },
                  markers: markers,
                  circles: circles,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 60,
                    bottom: 275,
                  ),
                ),
              ),

              // 2. Floating Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTopCircleButton(
                          icon: Icons.menu_rounded,
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        _buildSeddoPill(),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Floating Bottom Controls + Bottom Sheet
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Floating controls row just above bottom sheet
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(child: _buildVehicleIndicatorPill()),
                          const SizedBox(width: 8),
                          _buildGpsRecenterButton(state.userLocation),
                        ],
                      ),
                    ),

                    // Rounded Bottom Sheet
                    _buildBottomSheet(context, state),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Top Bar Helpers
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

  Widget _buildSeddoPill() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        'SEDDO',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFF5700),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // Floating Map Controls
  Widget _buildVehicleIndicatorPill() {
    Color dotColor;
    String text;

    switch (_selectedCardIndex) {
      case 1:
        dotColor = const Color(0xFFFF6B00);
        text = '3 Confort autour · 4 min';
        break;
      case 2:
        dotColor = const Color(0xFF3B82F6);
        text = '5 arrêts à moins de 500 m';
        break;
      case 0:
      default:
        dotColor = const Color(0xFF22C55E);
        text = '5 Eco autour · 2 min';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF18181A),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsRecenterButton(LatLng userLocation) {
    return GestureDetector(
      onTap: () {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: userLocation, zoom: 15.6),
          ),
        );
      },
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
        child: const Icon(
          Icons.my_location_rounded,
          color: Color(0xFFFF5700),
          size: 22,
        ),
      ),
    );
  }

  // Bottom Sheet
  Widget _buildBottomSheet(BuildContext context, HomeState state) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Search bar
          _buildSearchBar(context),
          const SizedBox(height: 14),

          // Carousel of offer cards
          SizedBox(
            height: 156,
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
          const SizedBox(height: 12),

          // 3-dot Pagination indicator
          _buildPaginationDots(),
          SizedBox(height: 12 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

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
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
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
                  fontSize: isTcu ? 16 : 16.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF18181A),
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(int index, BuildContext context) {
    switch (index) {
      case 0:
        return _buildEcoCard(context);
      case 1:
        return _buildConfortCard(context);
      case 2:
        return _buildTcuCard(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEcoCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDestinationSearch(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ÉCONOMIQUE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withAlpha(200),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Seddo Eco',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Le plus abordable,\ntrajets du quotidien',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(210),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arrive dans 2 min',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/seddo_eco_3d.png',
              width: 135,
              height: 95,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfortCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDestinationSearch(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDE3D2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5CFB8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "PLUS D'ESPACE",
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB54708),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Seddo Confort',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFB54708),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Climatisation,\nvoitures récentes',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFB54708),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arrive dans 4 min',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB54708),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/seddo_confort_3d.png',
              width: 135,
              height: 95,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
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
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF3257C9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
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
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Dem Dikk, AFTU,\nBRT, TER',
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
