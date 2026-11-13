import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/home/domain/bloc/home_event.dart';
import 'package:seddo/features/home/domain/bloc/home_state.dart';
import 'package:seddo/services/realtime_service.dart';

/// Carrousel de bannières promotionnelles automatiques sur la page d'accueil (Seddo).
/// Positionné entre la barre de recherche ("Où allez-vous ?") et la section des suggestions.
///
/// Respecte scrupuleusement :
/// 1. L'architecture BLoC ([HomeBloc] / [HomeState]).
/// 2. La synchronisation en temps réel avec le WebSocket ([RealtimeService]).
/// 3. Zéro appel de couleur en dur (toutes les couleurs proviennent de [AppColors]).
/// 4. Le style graphique pêche / orange clair pastel identique pour toutes les cartes,
///    avec la carte "Seddo en direct" en première position.
class HomePromoBannersWidget extends StatefulWidget {
  final VoidCallback? onOpenSeddoDirect;
  final VoidCallback? onOpenParrainage;
  final VoidCallback? onOpenAeroport;
  final VoidCallback? onOpenFidelite;

  const HomePromoBannersWidget({
    super.key,
    this.onOpenSeddoDirect,
    this.onOpenParrainage,
    this.onOpenAeroport,
    this.onOpenFidelite,
  });

  @override
  State<HomePromoBannersWidget> createState() => _HomePromoBannersWidgetState();
}

class _HomePromoBannersWidgetState extends State<HomePromoBannersWidget> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  StreamSubscription? _nearbyDriversWsSub;
  int _currentPage = 0;
  static const int _totalBanners = 4;
  int _liveWsDriversCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // 1. Écoute du flux WebSocket en direct pour rafraîchir le nombre de voitures disponibles
    _nearbyDriversWsSub =
        RealtimeService().nearbyDriversStream.listen((cars) {
      if (mounted) {
        setState(() {
          _liveWsDriversCount = cars.length;
        });
        // Transmission au HomeBloc pour respecter l'architecture BLoC
        context.read<HomeBloc>().add(
              HomeNearbyDriversUpdatedEvent(
                count: cars.length,
              ),
            );
      }
    });

    // 2. Défilement automatique périodique toutes les 4,5 secondes
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % _totalBanners;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _pauseAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _nearbyDriversWsSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Carrousel de cartes à défilement horizontal automatique
        SizedBox(
          height: 110,
          child: Listener(
            onPointerDown: (_) => _pauseAutoScroll(),
            onPointerUp: (_) => _startAutoScroll(),
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                // 1ère bannière : Seddo en direct (voitures disponibles en temps réel via WS & BLoC)
                _buildSeddoDirectBanner(context),

                // 2ème bannière : Parrainage en direct
                _buildParrainageBanner(context),

                // 3ème bannière : Aéroport / Réservation
                _buildAeroportBanner(context),

                // 4ème bannière : Fidélité / Points
                _buildFideliteBanner(context),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 2. Indicateurs de pagination en points / capsule (Image 4)
        _buildPageIndicators(),
      ],
    );
  }

  // --- Bannière 1 : Seddo en direct (Fond orange clair, temps réel) ---
  Widget _buildSeddoDirectBanner(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        // Priorité aux données temps réel du WebSocket ou du BLoC
        final effectiveCount = _liveWsDriversCount > 0
            ? _liveWsDriversCount
            : (state.driversCount > 0 ? state.driversCount : state.drivers.length);

        final String subtitle = effectiveCount > 0
            ? '$effectiveCount chauffeur${effectiveCount > 1 ? "s" : ""} disponible${effectiveCount > 1 ? "s" : ""} maintenant'
            : 'Recherche de chauffeurs à proximité...';

        return _buildBannerContainer(
          key: const Key('home_banner_seddo_direct'),
          onTap: () {
            if (widget.onOpenSeddoDirect != null) {
              widget.onOpenSeddoDirect!();
            }
          },
          title: 'Seddo en direct',
          subtitle: subtitle,
          badge: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.promoBannerIconBadgeBg,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.promoBannerIconShadow,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 6,
                      top: 10,
                      child: Icon(
                        Icons.directions_car_rounded,
                        color: AppColors.peachBorder,
                        size: 20,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 8,
                      child: Icon(
                        Icons.directions_car_rounded,
                        color: AppColors.starGold,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.promoBannerChevronBg,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.promoBannerIconShadow,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Bannière 2 : Parrainage en direct (Image 1) ---
  Widget _buildParrainageBanner(BuildContext context) {
    return _buildBannerContainer(
      key: const Key('home_banner_parrainage'),
      onTap: () {
        if (widget.onOpenParrainage != null) {
          widget.onOpenParrainage!();
        } else {
          _showParrainageBottomSheet(context);
        }
      },
      title: 'Parrainage en direct',
      subtitle: 'Invitez vos amis et gagnez\njusqu\'à 2 000 FCFA',
      badge: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.promoBannerIconBadgeBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: AppColors.promoBannerIconShadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.card_giftcard_rounded,
          color: AppColors.starGold,
          size: 32,
        ),
      ),
    );
  }

  // --- Bannière 3 : Aéroport / Réservation (Image 2) ---
  Widget _buildAeroportBanner(BuildContext context) {
    return _buildBannerContainer(
      key: const Key('home_banner_aeroport'),
      onTap: () {
        if (widget.onOpenAeroport != null) {
          widget.onOpenAeroport!();
        }
      },
      title: 'Aéroport / Réservation',
      subtitle: 'Réservez votre trajet pour\nl\'aéroport',
      badge: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.promoBannerIconBadgeBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: AppColors.promoBannerIconShadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.promoBannerAirportDisc,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.flight_takeoff_rounded,
                color: AppColors.promoBannerAirportPlane,
                size: 16,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 2,
                    color: AppColors.promoBannerAirportGridYellow,
                  ),
                  const SizedBox(width: 2),
                  Container(
                    width: 4,
                    height: 2,
                    color: AppColors.promoBannerAirportGridGreen,
                  ),
                  const SizedBox(width: 2),
                  Container(
                    width: 4,
                    height: 2,
                    color: AppColors.promoBannerAirportGridYellow,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Bannière 4 : Fidélité / Points (Image 3) ---
  Widget _buildFideliteBanner(BuildContext context) {
    return _buildBannerContainer(
      key: const Key('home_banner_fidelite'),
      onTap: () {
        if (widget.onOpenFidelite != null) {
          widget.onOpenFidelite!();
        } else {
          _showFideliteBottomSheet(context);
        }
      },
      title: 'Fidélité / Points',
      subtitle: 'Gagnez des points sur\nchaque trajet SEDDO',
      badge: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.promoBannerIconBadgeBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: AppColors.promoBannerIconShadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: AppColors.starGold,
                    size: 11,
                  ),
                  SizedBox(width: 1),
                  Icon(
                    Icons.star_rounded,
                    color: AppColors.starGold,
                    size: 14,
                  ),
                  SizedBox(width: 1),
                  Icon(
                    Icons.star_rounded,
                    color: AppColors.starGold,
                    size: 11,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 8,
              child: Icon(
                Icons.monetization_on_rounded,
                color: AppColors.starGold,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Structure réutilisable de bannière avec le dégradé orange clair ---
  Widget _buildBannerContainer({
    required Key key,
    required VoidCallback onTap,
    required String title,
    required String subtitle,
    required Widget badge,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingTwenty,
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.promoBannerGradientStart,
              AppColors.promoBannerGradientEnd,
            ],
          ),
          border: Border.all(
            color: AppColors.promoBannerBorder,
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowSubtleBlack,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            badge,
          ],
        ),
      ),
    );
  }

  // --- Indicateur de pagination (Image 4) ---
  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalBanners, (index) {
        final bool isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.promoBannerIndicatorActive
                : AppColors.promoBannerIndicatorInactive,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // --- Bottom Sheet Parrainage ---
  void _showParrainageBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.promoBannerIndicatorInactive,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.promoBannerGradientStart,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: AppColors.starGold,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parrainage Seddo',
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Gagnez 2 000 FCFA par ami parrainé',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.promoBannerGradientStart,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.promoBannerBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VOTRE CODE PARRAINAGE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SEDDO-2024',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: 'SEDDO-2024'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code parrainage copié !'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    // ignore: deprecated_member_use
                    Share.share(
                      'Rejoins-moi sur Seddo pour tes trajets à Dakar ! Télécharge l\'application et utilise mon code SEDDO-2024 pour gagner jusqu\'à 2 000 FCFA : https://seddo.sn',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, color: AppColors.white),
                  label: Text(
                    'Inviter mes amis',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Bottom Sheet Fidélité ---
  void _showFideliteBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.promoBannerIndicatorInactive,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.promoBannerGradientStart,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      color: AppColors.starGold,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Points & Fidélité',
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Cumulez des points sur chaque trajet',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.promoBannerGradientStart,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.promoBannerBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VOTRE SOLDE ACTUEL',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '350 Points',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Statut Gold',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chaque course vous rapporte des points échangeables contre des réductions et des courses offertes.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
