import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/home_page.dart';
import 'package:seddo/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/active_ride_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_approaching_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_search_page.dart';
import 'package:seddo/services/route_service.dart';

/// Splash page showing solid Seddo orange background and an animated SEDDO logo reveal.
/// Checks GET /v1/rides/current at app startup if the user is authenticated.
class SplashPage extends StatefulWidget {
  final AuthRepository? authRepository;
  final RideService? rideService;

  const SplashPage({
    super.key,
    this.authRepository,
    this.rideService,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Fade in animation
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.1, 0.85, curve: Curves.easeOut),
    );

    // Scale animation with gentle ease out
    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.95, curve: Curves.easeOutBack),
      ),
    );

    // Subtle slide up animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // Start reveal animation slightly after initial frame for seamless entry
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _animationController.forward();
      }
    });

    // Navigate to next screen after viewing logo
    _navigationTimer = Timer(
      const Duration(milliseconds: 2800),
      _navigateToNextScreen,
    );
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;
    final authRepo = widget.authRepository ?? AuthRepository();
    final isAuth = await authRepo.isAuthenticated();
    if (!mounted) return;

    final Widget targetPage;
    if (isAuth) {
      // GET /v1/rides/current : Course en cours de l’appelant, ou ride: null (au démarrage de l’app)
      Widget? activePage;
      try {
        final rideService = widget.rideService ?? RideService();
        final currentRideData = await rideService.getCurrentRide();
        final ride = currentRideData?['ride'];
        if (ride != null && ride is Map<String, dynamic>) {
          activePage = _resolveActiveRidePage(ride);
        }
      } catch (_) {}

      targetPage = activePage ?? const HomePage();
    } else {
      // If the user has not completed their profile yet, clear the incomplete session
      // so they restart cleanly from Onboarding and re-enter their number to receive a new OTP.
      await authRepo.clearIncompleteSession();
      targetPage = const OnboardingPage();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  /// Resolves the corresponding screen according to the active ride status
  Widget? _resolveActiveRidePage(Map<String, dynamic> ride) {
    final status = (ride['status'] as String? ?? '').toUpperCase();
    if (status == 'COMPLETED' ||
        status.startsWith('CANCELLED') ||
        status == 'NO_DRIVER' ||
        status == 'NO_SHOW') {
      return null;
    }

    final pickupRaw = ride['pickup'] as Map<String, dynamic>? ?? {};
    final dropoffRaw = ride['dropoff'] as Map<String, dynamic>? ?? {};

    final departure = PlaceSearchResult(
      id: 'pickup',
      mainText: (pickupRaw['address'] as String?)?.split(',').first ?? 'Départ',
      secondaryText: (pickupRaw['address'] as String?) ?? 'Dakar',
      fullAddress: (pickupRaw['address'] as String?) ?? 'Point de départ',
      latitude: (pickupRaw['lat'] as num?)?.toDouble() ?? 14.6937,
      longitude: (pickupRaw['lng'] as num?)?.toDouble() ?? -17.4440,
    );

    final destination = PlaceSearchResult(
      id: 'dropoff',
      mainText: (dropoffRaw['address'] as String?)?.split(',').first ?? 'Destination',
      secondaryText: (dropoffRaw['address'] as String?) ?? 'Dakar',
      fullAddress: (dropoffRaw['address'] as String?) ?? 'Point d\'arrivée',
      latitude: (dropoffRaw['lat'] as num?)?.toDouble() ?? 14.7431,
      longitude: (dropoffRaw['lng'] as num?)?.toDouble() ?? -17.5195,
    );

    final isConfort = (ride['category'] as String? ?? '').toUpperCase() == 'CONFORT';
    final rideType = isConfort ? RideType.confort : RideType.eco;

    // Planned traffic segments
    final plannedTrafficRaw = ride['plannedTraffic'] as List<dynamic>?;
    final List<TrafficSegmentModel> plannedTraffic = plannedTrafficRaw != null
        ? plannedTrafficRaw
            .whereType<Map<String, dynamic>>()
            .map((item) => TrafficSegmentModel.fromJson(item))
            .toList()
        : const [];

    final rideOption = RideOptionModel(
      type: rideType,
      title: isConfort ? 'Seddo Confort' : 'Seddo Eco',
      subtitle: (ride['categoryName'] as String?) ??
          (isConfort ? 'Seddo Confort' : 'Seddo Eco'),
      price: (ride['finalPrice'] ?? ride['price'] ?? 2000) as int,
      capacity: 4,
      estimatedArrival: 'Dans 15 min',
      pickupDuration: '3 min',
      traffic: plannedTraffic,
    );

    if (status == 'SEARCHING' || status == 'PAYMENT_PENDING') {
      return DriverSearchPage(
        departure: departure,
        destination: destination,
        rideOption: rideOption,
      );
    }

    final routeRaw = ride['route'] as Map<String, dynamic>?;
    final phase = (routeRaw?['phase'] as String? ?? '').toUpperCase();
    final startedAt = ride['startedAt'];
    final rideId = ride['id']?.toString();

    // Décodage de la polyline planifiée (du pickup au dropoff)
    List<LatLng> tripPolyline = [];
    final plannedPolylineStr = ride['plannedPolyline'] as String?;
    if (plannedPolylineStr != null && plannedPolylineStr.isNotEmpty) {
      tripPolyline = RouteService.decodePolyline(plannedPolylineStr);
    }

    // Driver information pour approche ou course en cours :
    // DriverModel.fromRideJson extrait fidèlement driver.position, heading,
    // route.polyline (phase APPROACH sur vraies routes), durationS et distanceM
    final driver = DriverModel.fromRideJson(
      ride,
      defaultRideType: rideType,
    );

    final departureCode =
        DriverModel.extractDepartureCode(ride, fallback: '4821');

    // Vérification stricte de la phase et du statut :
    // Tant que la phase est 'APPROACH' ou que startedAt est null (code non encore validé par le chauffeur),
    // l'application DOIT afficher DriverApproachingPage avec le code de départ à 4 chiffres.
    final isTripUnderway = (status == 'IN_PROGRESS' ||
            phase == 'TRIP' ||
            (startedAt != null && startedAt.toString().isNotEmpty)) &&
        phase != 'APPROACH';

    if (isTripUnderway) {
      return ActiveRidePage(
        departure: departure,
        destination: destination,
        rideOption: rideOption,
        driver: driver,
        polylinePoints: tripPolyline,
        autoStartSimulation: false,
        rideId: rideId,
        rideService: widget.rideService,
      );
    }

    // Phase APPROACH (chauffeur en route vers le client ou arrivé au point de rendez-vous)
    return DriverApproachingPage(
      departure: departure,
      destination: destination,
      rideOption: rideOption,
      driver: driver,
      departureCode: departureCode,
      polylinePoints: tripPolyline,
      autoStartSimulation: false,
      rideId: rideId,
      rideService: widget.rideService,
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingXl,
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/seddo_logo_white.svg',
                    width: 260,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
