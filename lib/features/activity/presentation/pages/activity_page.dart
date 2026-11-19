import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/activity/data/models/activity_item_model.dart';
import 'package:seddo/features/activity/domain/bloc/activity_bloc.dart';
import 'package:seddo/features/activity/domain/bloc/activity_event.dart';
import 'package:seddo/features/activity/domain/bloc/activity_state.dart';
import 'package:seddo/features/activity/presentation/utils/ride_status_style_helper.dart';
import 'package:seddo/features/ride/presentation/pages/ride_receipt_page.dart';
import 'package:seddo/features/ride/data/services/ride_eta_calculator.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/network_connectivity_service.dart';

export 'package:seddo/features/activity/domain/bloc/activity_event.dart'
    show ActivityTab;

/// Screen displaying the user's activity history matching the design mockup:
/// - Header with circular back button and "ACTIVITÉ" bold uppercase title
/// - Segmented toggle: "COURSES" (default) & "REMBOURSEMENTS"
///
/// Tab "COURSES":
/// - "RÉCENT": Only the latest course shows a map trajectory preview card with
///   coordinates, tag, Almadies title, driver initials avatar, price and badge.
///   Clicking on this card opens its receipt superimposed on the interactive map.
/// - "PLUS TÔT": Earlier rides list where clicking each ride over its full horizontal
///   width opens its dedicated receipt superposed on the interactive map with coordinates.
/// - Clean pagination controls for browsing earlier rides, built for easy remote API connection.
///
/// Tab "REMBOURSEMENTS":
/// - Hero dark card with orange circular curve, "Total remboursé", and Orange Money account.
/// - "HISTORIQUE" list of refund cards (completed and pending) with amounts and badges.
/// - Descriptive footnote at the bottom.
class ActivityPage extends StatelessWidget {
  final ActivityTab initialTab;
  final ActivityBloc? activityBloc;

  const ActivityPage({
    super.key,
    this.initialTab = ActivityTab.courses,
    this.activityBloc,
  });

  @override
  Widget build(BuildContext context) {
    if (activityBloc != null) {
      return BlocProvider<ActivityBloc>.value(
        value: activityBloc!,
        child: _ActivityPageView(initialTab: initialTab),
      );
    }
    return BlocProvider<ActivityBloc>(
      create: (ctx) => ActivityBloc()..add(ActivityLoadInitialEvent(initialTab: initialTab)),
      child: _ActivityPageView(initialTab: initialTab),
    );
  }
}

class _ActivityPageView extends StatefulWidget {
  final ActivityTab initialTab;

  const _ActivityPageView({required this.initialTab});

  @override
  State<_ActivityPageView> createState() => _ActivityPageViewState();
}

class _ActivityPageViewState extends State<_ActivityPageView> {
  final ScrollController _scrollController = ScrollController();
  BitmapDescriptor? _originMarkerIcon;
  BitmapDescriptor? _destMarkerIcon;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCustomMarkers();
  }

  Future<void> _loadCustomMarkers() async {
    final origin = await MapMarkerHelper.getDeparturePinMarker();
    final dest = await MapMarkerHelper.getDestinationPinMarker();
    if (mounted) {
      setState(() {
        _originMarkerIcon = origin;
        _destMarkerIcon = dest;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final state = context.read<ActivityBloc>().state;
    if (state is! ActivityLoadedState || !_scrollController.hasClients) return;

    final isNearBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80;
    if (!isNearBottom) return;

    if (state.currentTab == ActivityTab.courses) {
      if (!state.isLoadingMore && state.hasMore) {
        context.read<ActivityBloc>().add(const ActivityLoadMorePastRidesEvent());
      }
    } else if (state.currentTab == ActivityTab.remboursements) {
      if (!state.isLoadingMoreRefunds && state.hasMoreRefunds) {
        context.read<ActivityBloc>().add(const ActivityLoadMoreRefundsEvent());
      }
    }
  }

  void _openReceipt(ActivityRideItem ride) {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: RideReceiptPage(
          rideId: ride.id,
          departure: ride.departure,
          destination: ride.destination,
          driver: ride.driver,
          rideOption: ride.toRideOptionModel(),
          priceText: ride.priceText,
          statusText: ride.status,
          isRefunded: ride.isRefunded,
          departureTime: ride.departureTime,
          arrivalTime: ride.arrivalTime,
          durationText: ride.durationText,
          distanceText: ride.distanceText,
          dateText: ride.dateText,
          orangeRef: ride.orangeRef,
        ),
      ),
    );
  }

  void _openReceiptForRefund(ActivityRefundItem refund) {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: RideReceiptPage(
          rideId: refund.rideId,
          priceText: refund.amountText.replaceAll('+', ''),
          dateText: refund.subtitle.split('·').first.trim(),
          statusText: refund.status,
          orangeRef: refund.providerRef ?? 'CI270415.1819.A3F2',
          isRefunded: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: BlocBuilder<ActivityBloc, ActivityState>(
          builder: (context, state) {
            final currentTab = state is ActivityLoadedState
                ? state.currentTab
                : widget.initialTab;

            return Column(
              children: [
                // Top App Bar: Circular back button and "ACTIVITÉ"
                _buildTopAppBar(),

                // Segmented pill toggle: COURSES / REMBOURSEMENTS
                _buildSegmentedToggle(currentTab),

                // Tab content with mobile infinite scroll listener
                Expanded(
                  child: state is ActivityLoadingState
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : state is ActivityErrorState
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    state.message,
                                    style: GoogleFonts.inter(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: () => context
                                        .read<ActivityBloc>()
                                        .add(const ActivityRefreshEvent()),
                                    child: Text('common.retry'.tr()),
                                  ),
                                ],
                              ),
                            )
                          : state is ActivityLoadedState
                              ? NotificationListener<ScrollNotification>(
                                  onNotification: (scrollInfo) {
                                    if (state.currentTab ==
                                            ActivityTab.courses &&
                                        !state.isLoadingMore &&
                                        state.hasMore &&
                                        scrollInfo.metrics.pixels >=
                                            scrollInfo.metrics.maxScrollExtent -
                                                60) {
                                      context.read<ActivityBloc>().add(
                                            const ActivityLoadMorePastRidesEvent(),
                                          );
                                    }
                                    return false;
                                  },
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppConstants.spacingMd,
                                    ),
                                    child: state.currentTab ==
                                            ActivityTab.courses
                                        ? _buildCoursesTabContent(state)
                                        : _buildRefundsTabContent(state),
                                  ),
                                )
                              : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: AppConstants.circularButtonSize,
              height: AppConstants.circularButtonSize,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.grayBorderDivider,
                  width: AppConstants.strokeWidthBorder,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowSubtleBlack,
                    blurRadius: AppConstants.spacingXs,
                    offset: Offset(0, AppConstants.spacingXxs),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.slateDark,
                size: AppConstants.iconSizeMd,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingUnitLg),
          Expanded(
            child: Text(
              'activity.page_title'.tr(),
              style: GoogleFonts.inter(
                fontSize: AppConstants.fontTitleLarge,
                fontWeight: FontWeight.w900,
                color: AppColors.slateDark,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedToggle(ActivityTab currentTab) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingXs,
        AppConstants.spacingMd,
        AppConstants.spacingMd,
      ),
      padding: const EdgeInsets.all(AppConstants.spacingXs),
      decoration: BoxDecoration(
        color: AppColors.grayBgLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTogglePill(
              title: 'activity.tab_courses'.tr(),
              isSelected: currentTab == ActivityTab.courses,
              onTap: () {
                context
                    .read<ActivityBloc>()
                    .add(const ActivityChangeTabEvent(ActivityTab.courses));
              },
            ),
          ),
          Expanded(
            child: _buildTogglePill(
              title: 'activity.tab_refunds'.tr(),
              isSelected: currentTab == ActivityTab.remboursements,
              onTap: () {
                context.read<ActivityBloc>().add(
                      const ActivityChangeTabEvent(
                          ActivityTab.remboursements),
                    );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTogglePill({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingUnit,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.drawerDark : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontMd,
            fontWeight: FontWeight.w800,
            color: isSelected ? AppColors.white : AppColors.slateDark,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // COURSES TAB
  // ==========================================

  Widget _buildCoursesTabContent(ActivityLoadedState state) {
    if (state.recentRide == null && state.pastRides.isEmpty) {
      return FutureBuilder<bool>(
        future: NetworkConnectivityService.isConnected,
        builder: (context, snap) {
          final isOffline = snap.hasData && snap.data == false;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: (isOffline ? AppColors.warning : AppColors.primary)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOffline
                          ? Icons.wifi_off_rounded
                          : Icons.directions_car_rounded,
                      color: isOffline ? AppColors.warning : AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isOffline
                        ? 'Mode hors-ligne'
                        : 'Aucune course enregistrée',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slateDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOffline
                        ? 'Impossible de charger l\'historique d\'activité sans connexion Internet.'
                        : 'Vos trajets et reçus apparaîtront ici dès votre première course.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (isOffline) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => context
                          .read<ActivityBloc>()
                          .add(const ActivityRefreshEvent()),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text('common.retry'.tr()),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Section "RÉCENT"
        if (state.recentRide != null) ...[
          Text(
            'activity.recent'.tr(),
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontSm,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          _buildRecentRideCard(state.recentRide!),
          if (state.pastRides.isNotEmpty)
            const SizedBox(height: AppConstants.spacingLg),
        ],

        // 2. Section "PLUS TÔT"
        if (state.pastRides.isNotEmpty) ...[
          Text(
            'activity.earlier'.tr(),
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontSm,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppConstants.spacingUnitLg),
          ...List.generate(state.pastRides.length, (index) {
            final ride = state.pastRides[index];
            final isLast = index == state.pastRides.length - 1;
            return Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppConstants.spacingUnitLg,
              ),
              child: _buildPastRideTile(ride),
            );
          }),
          const SizedBox(height: AppConstants.spacingMd),
          if (state.isLoadingMore)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.spacingMd,
              ),
              child: Center(
                child: SizedBox(
                  width: AppConstants.iconSizeXl,
                  height: AppConstants.iconSizeXl,
                  child: const CircularProgressIndicator(
                    strokeWidth: AppConstants.strokeWidthSelected,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: AppConstants.spacingXl),
        ],
      ],
    );
  }



  Widget _buildRecentRideCard(ActivityRideItem ride) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(
          color: AppColors.grayBorderDivider,
          width: AppConstants.strokeWidthBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSubtleBlack,
            blurRadius: AppConstants.spacingSm,
            offset: Offset(0, AppConstants.spacingXxs),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () => _openReceipt(ride),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top half: Map Trajectory Preview (clipped to remove Google logo)
              SizedBox(
                height: AppConstants.activityMapPreviewHeight,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppConstants.radiusCardContainer),
                  ),
                  child: Stack(
                    children: [
                      // Embedded Map with route polyline
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: AppConstants.mapLogoClipOffset,
                        child: SizedBox(
                          height: AppConstants.activityMapPreviewHeight +
                              AppConstants.mapLogoClipExtraHeight,
                          child: IgnorePointer(
                            child: GoogleMap(
                        style: MapStyleService.style,
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            (ride.departure.latitude +
                                    ride.destination.latitude) /
                                2,
                            (ride.departure.longitude +
                                    ride.destination.longitude) /
                                2,
                          ),
                          zoom: 12.8,
                        ),
                        buildingsEnabled: false,
                        onMapCreated: (controller) {
                          MapStyleService.applyStyle(controller);
                          if (ride.polylinePoints.isNotEmpty) {
                            _fitPreviewBounds(controller, ride.polylinePoints);
                          }
                        },
                        polylines: _buildRecentPreviewPolylines(ride),
                        markers: {
                          Marker(
                            markerId: const MarkerId('preview_origin'),
                            position: LatLng(
                              ride.departure.latitude,
                              ride.departure.longitude,
                            ),
                            icon: _originMarkerIcon ??
                                BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueOrange,
                                ),
                            anchor: const Offset(0.5, 1.0),
                          ),
                          Marker(
                            markerId: const MarkerId('preview_destination'),
                            position: LatLng(
                              ride.destination.latitude,
                              ride.destination.longitude,
                            ),
                            icon: _destMarkerIcon ??
                                BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueAzure,
                                ),
                            anchor: const Offset(0.5, 1.0),
                          ),
                        },
                        zoomControlsEnabled: false,
                        zoomGesturesEnabled: false,
                        scrollGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                      ),
                    ),
                  ),
                ),

                    // Date/time tag on top left
                    Positioned(
                      left: AppConstants.spacingUnitLg,
                      top: AppConstants.spacingUnit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingUnitLg,
                          vertical: AppConstants.spacingS,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusFull),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowSoftBlack,
                              blurRadius: AppConstants.spacingXs,
                              offset: Offset(0, AppConstants.spacingXxs),
                            ),
                          ],
                        ),
                        child: Text(
                          ride.dateTag,
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontSm,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slateDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

              // Bottom half: Details
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: AppConstants.spacingUnitLg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride.title,
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontXl,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slateDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingXs),
                          // Route summary: Departure (silhouette) -> Destination (flag)
                          Row(
                            children: [
                              const Icon(
                                Icons.hail_rounded,
                                size: AppConstants.iconSizeSm,
                                color: AppColors.textPrimary,
                              ),
                              const SizedBox(width: AppConstants.spacingXxs),
                              Flexible(
                                child: Text(
                                  ride.departure.mainText,
                                  style: GoogleFonts.inter(
                                    fontSize: AppConstants.fontXs,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacingXs),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 11,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppConstants.spacingXs),
                              SvgPicture.asset(
                                'assets/icons/flag-svgrepo-com.svg',
                                width: AppConstants.iconSizeSm,
                                height: AppConstants.iconSizeSm,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.primary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacingXxs),
                              Flexible(
                                child: Text(
                                  ride.destination.mainText,
                                  style: GoogleFonts.inter(
                                    fontSize: AppConstants.fontXs,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slateDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.spacingXs),
                          Row(
                            children: [
                              if (ride.driverInitials != null &&
                                  ride.driverInitials!.isNotEmpty) ...[
                                Container(
                                  width: AppConstants.iconSizeLg,
                                  height: AppConstants.iconSizeLg,
                                  decoration: const BoxDecoration(
                                    color: AppColors.grayBgLight,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    ride.driverInitials!,
                                    style: GoogleFonts.inter(
                                      fontSize: AppConstants.fontXs,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.slateDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spacingS),
                              ] else ...[
                                Container(
                                  width: AppConstants.iconSizeLg,
                                  height: AppConstants.iconSizeLg,
                                  decoration: const BoxDecoration(
                                    color: AppColors.grayBgLight,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    ride.status == 'Sans chauffeur'
                                        ? Icons.person_off_outlined
                                        : Icons.directions_car_rounded,
                                    size: AppConstants.iconSizeSm,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spacingS),
                              ],
                              Expanded(
                                child: Text(
                                  ride.subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: AppConstants.fontSm,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          ride.priceText,
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontLg,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slateDark,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingXs),
                        Builder(
                          builder: (context) {
                            final statusStyle = RideStatusStyle.forStatus(
                              ride.status,
                              isRefunded: ride.isRefunded,
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingUnit,
                                vertical: AppConstants.spacingXs,
                              ),
                              decoration: BoxDecoration(
                                color: statusStyle.backgroundColor,
                                borderRadius:
                                    BorderRadius.circular(AppConstants.radiusFull),
                              ),
                              child: Text(
                                ride.status,
                                style: GoogleFonts.inter(
                                  fontSize: AppConstants.fontXs,
                                  fontWeight: FontWeight.w700,
                                  color: statusStyle.textColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
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

  Set<Polyline> _buildRecentPreviewPolylines(ActivityRideItem ride) {
    if (ride.polylinePoints.isEmpty) return {};
    if (ride.trafficSegments.isNotEmpty) {
      return RideEtaCalculator.buildTrafficPolylines(
        baseId: 'recent_preview_line',
        points: ride.polylinePoints,
        traffic: ride.trafficSegments,
        width: AppConstants.mapPolylineWidth.toInt(),
      );
    }
    return {
      Polyline(
        polylineId: const PolylineId('recent_preview_line'),
        points: ride.polylinePoints,
        color: AppColors.trafficNormal,
        width: AppConstants.mapPolylineWidth.toInt(),
      ),
    };
  }

  void _fitPreviewBounds(GoogleMapController controller, List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    try {
      controller.moveCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          AppConstants.spacingLg,
        ),
      );
    } catch (_) {}
  }

  Widget _buildPastRideTile(ActivityRideItem ride) {
    IconData iconData;
    Color iconColor;
    Color iconBg;

    switch (ride.iconType) {
      case ActivityRideIconType.airport:
        iconData = Icons.flight_rounded;
        iconColor = AppColors.savedPlaceAirportIcon;
        iconBg = AppColors.savedPlaceAirportBg;
        break;
      case ActivityRideIconType.briefcase:
        iconData = Icons.business_center_rounded;
        iconColor = AppColors.slateDark;
        iconBg = AppColors.grayBgLight;
        break;
      case ActivityRideIconType.car:
        iconData = Icons.directions_car_filled_rounded;
        iconColor = AppColors.slateDark;
        iconBg = AppColors.grayBgLight;
        break;
    }

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => _openReceipt(ride),
        borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.spacingXs,
          ),
          child: Row(
            children: [
              // Circular icon container
              Container(
                width: AppConstants.circularAvatarSize,
                height: AppConstants.circularAvatarSize,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  iconData,
                  size: AppConstants.iconSizeLg,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitLg),

              // Title and date/driver line
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.title,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontBase,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slateDark,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXxs),
                    Text(
                      ride.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Price and status badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ride.priceText,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontLg,
                      fontWeight: FontWeight.w800,
                      color: ride.isCancelled
                          ? AppColors.textSecondary
                          : AppColors.slateDark,
                      decoration: ride.isCancelled
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXs),
                  Builder(
                    builder: (context) {
                      final statusStyle = RideStatusStyle.forStatus(
                        ride.status,
                        isRefunded: ride.isRefunded,
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingUnit,
                          vertical: AppConstants.spacingXxs,
                        ),
                        decoration: BoxDecoration(
                          color: statusStyle.backgroundColor,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusFull),
                        ),
                        child: Text(
                          ride.status,
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontXs,
                            fontWeight: FontWeight.w700,
                            color: statusStyle.textColor,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REMBOURSEMENTS TAB (Design Sobre Blanc, Gris, Noir inspiré Dribbble & Figma)
  // ==========================================

  Widget _buildRefundsTabContent(ActivityLoadedState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),

        // 1. Nouvelle Carte Héro Sobre, Aérée & Statutaire (Blanc, Gris, Noir)
        _buildRefundHeroCard(state.summary, state.refunds.length),

        const SizedBox(height: 28),

        // 2. Section "HISTORIQUE"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'activity.history'.tr(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF9CA3AF),
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '${state.refunds.length} transactions',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3. Liste des remboursements
        ...state.refunds.map((refund) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRefundItemCard(refund),
            )),

        // Loader during pagination
        if (state.isLoadingMoreRefunds)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF111827)),
                ),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // 4. Footnote text élégante avec icône info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'activity.footnote'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildRefundHeroCard(ActivitySummary summary, int refundsCount) {
    final amountNumber = summary.totalRefundedFormatted
        .replaceAll(' F', '')
        .replaceAll('F', '')
        .trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 24.0),
        child: Column(
          children: [
            // 1. Badge supérieur sobre avec icône
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_downward_rounded,
                    size: 14,
                    color: Color(0xFF111827),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'activity.total_refunded'.tr().toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Montant imposant et raffiné
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  amountNumber,
                  style: GoogleFonts.inter(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                    letterSpacing: -1.6,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'F',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. Séparateur très discret
            const Divider(
              height: 1,
              thickness: 0.8,
              color: Color(0xFFF3F4F6),
            ),

            const SizedBox(height: 16),

            // 4. Ligne statutaire sobre avec 2 indicateurs clés (sans carte Orange Money encombrante)
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Transactions',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$refundsCount reçues',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: const Color(0xFFE5E7EB),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Délai moyen',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Instantané',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundItemCard(ActivityRefundItem refund) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () {
          if (refund.associatedRide != null) {
            _openReceipt(refund.associatedRide!);
          } else if (refund.rideId != null && refund.rideId!.isNotEmpty) {
            _openReceiptForRefund(refund);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Conteneur circulaire sobre en gris doux avec icône anthracite
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  refund.isPending
                      ? Icons.hourglass_top_rounded
                      : Icons.arrow_downward_rounded,
                  size: 20,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 14),

              // Titre et sous-titre
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      refund.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      refund.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Montant et capsule de statut sobre
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    refund.amountText,
                    style: GoogleFonts.inter(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      refund.status,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: refund.isPending
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
