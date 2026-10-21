import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/home/domain/bloc/home_event.dart';
import 'package:seddo/features/home/domain/bloc/home_state.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/features/home/presentation/widgets/circular_menu_button.dart';
import 'package:seddo/features/home/presentation/widgets/circular_notification_button.dart';
import 'package:seddo/features/home/presentation/widgets/home_map_card.dart';
import 'package:seddo/features/home/presentation/widgets/home_recent_item.dart';
import 'package:seddo/features/home/presentation/widgets/home_search_bar.dart';
import 'package:seddo/features/home/presentation/widgets/home_suggestion_card.dart';
import 'package:seddo/features/home/presentation/widgets/seddo_drawer_widget.dart';

/// Main Home Screen of Seddo faithfully reproducing the updated reference design:
/// - Top Bar: Circular Menu button, Orange SEDDO Logo, and Circular Notification Bell with unread dot
/// - Search Card: Orange search icon, destination title & subtitle, orange circular arrow button
/// - Recent Rides ("Mes récentes courses"): Distinct white rounded cards
///   with colored circular icon backgrounds (peach for Almadies home, grey for Travail briefcase)
/// - Suggestions: Header with car front icon, 4 cards using the provided vector SVGs:
///   - Seddo Eco (ecocar.svg, orange border & indicator line)
///   - Confort (confortcar.svg)
///   - Aéroport (airplane-svgrepo-com.svg)
///   - TCU (bus-svgrepo-com.svg)
/// - Interactive Google Map Card (untouched as requested: real GPS & pivoting cars)
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

    if (selectedPlace != null) {
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

  @override
  Widget build(BuildContext context) {
    // Establishing reactive dependency on EasyLocalization
    final _ = context.locale;
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SeddoDrawerWidget(),
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: 60,
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Bar: Hamburger Menu Button, Orange SEDDO Logo, and Notification Bell
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircularMenuButton(
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                  SvgPicture.asset(
                    'assets/icons/seddo_logo_orange.svg',
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                  CircularNotificationButton(
                    hasUnread: true,
                    onPressed: () {
                      SeddoDrawerWidget.openNotificationsSheet(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. Search Card: "Où allez-vous ?" with orange arrow button
              BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  return HomeSearchBar(
                    destinationAddress: state.destinationAddress,
                    onClear: () {
                      context
                          .read<HomeBloc>()
                          .add(const HomeClearDestinationEvent());
                    },
                    onTap: () => _openDestinationSearch(context),
                  );
                },
              ),
              const SizedBox(height: 20),

              // 3. Recent Rides Header: "Mes récentes courses"
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/clock-three-svgrepo-com.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      AppColors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'home.recent_places'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Recent Destination 1: Almadies (Home icon in peach circle container)
              HomeRecentItem(
                icon: SvgPicture.asset(
                  'assets/icons/home-svgrepo-com.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    AppColors.primary,
                    BlendMode.srcIn,
                  ),
                ),
                iconBackgroundColor: AppColors.peachContainer,
                title: 'home.almadies'.tr(),
                subtitle: 'home.almadies_sub'.tr(),
                onTap: () {
                  context.read<HomeBloc>().add(
                        const HomeSelectDestinationEvent(
                          destinationLocation: LatLng(14.7431, -17.5195),
                          destinationAddress: 'Les Almadies, Dakar',
                        ),
                      );
                },
              ),
              const SizedBox(height: 10),

              // 5. Recent Destination 2: Travail (Briefcase icon in grey circle container)
              HomeRecentItem(
                icon: SvgPicture.asset(
                  'assets/icons/work-alt-bag-svgrepo-com.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                iconBackgroundColor: AppColors.greyContainer,
                title: 'home.work'.tr(),
                subtitle: 'home.work_sub'.tr(),
                onTap: () {
                  context.read<HomeBloc>().add(
                        const HomeSelectDestinationEvent(
                          destinationLocation: LatLng(14.6720, -17.4330),
                          destinationAddress: 'Plateau, rue Carnot, Dakar',
                        ),
                      );
                },
              ),
              const SizedBox(height: 20),

              // 6. Suggestions Header: Car Icon + "Suggestions"
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/confortcar.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      AppColors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'home.suggestions'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 7. Suggestions Row: Seddo Eco, Confort, Aéroport, TCU
              BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  return Row(
                    children: [
                      // Seddo Eco
                      HomeSuggestionCard(
                        label: 'home.seddo_eco'.tr(),
                        subtitle: 'home.eco_sub'.tr(),
                        isSelected: state.selectedCategory == 'seddo_eco',
                        icon: Image.asset(
                          'assets/images/seddo_eco_3d.png',
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                        onTap: () {
                          context.read<HomeBloc>().add(
                                const HomeSelectCategoryEvent('seddo_eco'),
                              );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Confort
                      HomeSuggestionCard(
                        label: 'home.confort'.tr(),
                        subtitle: 'home.confort_sub'.tr(),
                        isSelected: state.selectedCategory == 'confort',
                        icon: Image.asset(
                          'assets/images/seddo_confort_3d.png',
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                        onTap: () {
                          context.read<HomeBloc>().add(
                                const HomeSelectCategoryEvent('confort'),
                              );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Aéroport
                      HomeSuggestionCard(
                        label: 'home.airport'.tr(),
                        subtitle: 'home.airport_sub'.tr(),
                        isSelected: state.selectedCategory == 'airport',
                        icon: Image.asset(
                          'assets/images/seddo_airport_3d.png',
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                        onTap: () {
                          context.read<HomeBloc>().add(
                                const HomeSelectCategoryEvent('airport'),
                              );
                        },
                      ),
                      const SizedBox(width: 8),

                      // TCU
                      HomeSuggestionCard(
                        label: 'home.tcu'.tr(),
                        subtitle: 'home.tcu_sub'.tr(),
                        isSelected: state.selectedCategory == 'tcu',
                        icon: Image.asset(
                          'assets/images/seddo_bus_3d.png',
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                        onTap: () {
                          context.read<HomeBloc>().add(
                                const HomeSelectCategoryEvent('tcu'),
                              );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // 8. Interactive Google Map Card
              const HomeMapCard(height: 290),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
