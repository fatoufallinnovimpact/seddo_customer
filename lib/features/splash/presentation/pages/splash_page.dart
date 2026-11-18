import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/home/presentation/pages/home_page.dart';
import 'package:seddo/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:seddo/features/ride/data/services/active_ride_offline_storage.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/utils/active_ride_navigation_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late final Future<Widget> _destinationFuture;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // Fade in animation dès le début
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.60, curve: Curves.easeIn),
    );

    // Effet d'échelle bien visible avec rebond élégant (de 55% à 100%)
    _scaleAnimation = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutBack),
      ),
    );

    // Montée dynamique bien visible (slide up)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    // Lancer la résolution de la page cible en arrière-plan pendant l'animation
    _destinationFuture = _resolveTargetPage();

    // Démarrer l'animation immédiatement
    _animationController.forward();

    // Naviguer après l'animation complète et bien visible du logo
    _splashTimer = Timer(
      const Duration(milliseconds: 2300),
      _navigateToNextScreen,
    );
  }

  Future<void> _navigateToNextScreen() async {
    final targetPage = await _destinationFuture;
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

  Future<Widget> _resolveTargetPage() async {
    try {
      final authRepo = widget.authRepository ?? AuthRepository();
      final isAuth = await authRepo.isAuthenticated();
      if (!isAuth) {
        await authRepo.clearIncompleteSession();
        return const OnboardingPage();
      }

      // 1. Restaurer le dernier ID de course terminée en local
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastCompleted = prefs.getString('seddo_last_completed_ride_id');
        if (lastCompleted != null && lastCompleted.isNotEmpty) {
          RideService.lastCompletedRideId = lastCompleted;
        }
      } catch (_) {}

      // 2. GET /v1/rides/current avec timeout pour garantir un lancement instantané sans freeze
      Widget? activePage;
      bool hasOnlineResult = false;
      try {
        final rideService = widget.rideService ?? RideService();
        final currentRideData = await rideService
            .getCurrentRide()
            .timeout(const Duration(milliseconds: 1400));
        if (currentRideData != null) {
          hasOnlineResult = true;
          final ride = currentRideData['ride'];
          if (ride != null && ride is Map<String, dynamic>) {
            activePage = _resolveActiveRidePage(ride);
            if (activePage == null) {
              await ActiveRideOfflineStorage.clearActiveRide();
            }
          } else {
            await ActiveRideOfflineStorage.clearActiveRide();
          }
        }
      } catch (_) {}

      // 3. Récupérer la course sauvegardée en local UNIQUEMENT si le serveur était injoignable
      if (!hasOnlineResult && activePage == null) {
        try {
          final cachedRide = await ActiveRideOfflineStorage.getActiveRide();
          if (cachedRide != null) {
            activePage = _resolveActiveRidePage(cachedRide);
          }
        } catch (_) {}
      }

      return activePage ?? const HomePage();
    } catch (_) {
      return const HomePage();
    }
  }

  /// Resolves the corresponding screen according to the active ride status
  Widget? _resolveActiveRidePage(Map<String, dynamic> ride) {
    return ActiveRideNavigationHelper.resolveActiveRidePage(
      ride,
      rideService: widget.rideService,
    );
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
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
