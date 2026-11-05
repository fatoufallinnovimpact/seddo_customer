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
      // 1. Restaurer le dernier ID de course terminée en local
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastCompleted = prefs.getString('seddo_last_completed_ride_id');
        if (lastCompleted != null && lastCompleted.isNotEmpty) {
          RideService.lastCompletedRideId = lastCompleted;
        }
      } catch (_) {}

      // 2. GET /v1/rides/current : Course en cours de l’appelant, ou ride: null (au démarrage de l’app)
      Widget? activePage;
      bool hasOnlineResult = false;
      try {
        final rideService = widget.rideService ?? RideService();
        final currentRideData = await rideService.getCurrentRide();
        if (currentRideData != null) {
          hasOnlineResult = true;
          final ride = currentRideData['ride'];
          if (ride != null && ride is Map<String, dynamic>) {
            activePage = _resolveActiveRidePage(ride);
            if (activePage == null) {
              // Si la course reçue est terminée/annulée, purger immédiatement le cache local
              await ActiveRideOfflineStorage.clearActiveRide();
            }
          } else {
            // Le serveur confirme expressément qu'aucune course n'est en cours (ride: null)
            await ActiveRideOfflineStorage.clearActiveRide();
          }
        }
      } catch (_) {}

      // 3. Récupérer la course sauvegardée en local UNIQUEMENT si le serveur était injoignable (vrai offline)
      if (!hasOnlineResult && activePage == null) {
        try {
          final cachedRide = await ActiveRideOfflineStorage.getActiveRide();
          if (cachedRide != null) {
            activePage = _resolveActiveRidePage(cachedRide);
          }
        } catch (_) {}
      }

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
    return ActiveRideNavigationHelper.resolveActiveRidePage(
      ride,
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
