import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/data/services/activity_data_service.dart';
import 'package:seddo/features/home/domain/models/activity_item_model.dart';
import 'package:seddo/features/home/presentation/pages/ride_receipt_page.dart';

enum ActivityTab {
  courses,
  remboursements,
}

/// Screen displaying the user's activity history matching the design mockup:
/// - Header with circular back button and "ACTIVITÉ" bold uppercase title
/// - Segmented toggle: "COURSES" (default) & "REMBOURSEMENTS"
///
/// Tab "COURSES":
/// - 2 summary metric cards: "Courses payées" (3) and "Total dépensé" (22 900 F)
/// - "RÉCENT": Only the latest course shows a map trajectory preview card with
///   coordinates, tag "Aujourd'hui · 18:19", Almadies title, driver initials avatar, price and badge.
///   Clicking on this card opens its receipt superimposed on the interactive map.
/// - "PLUS TÔT": Earlier rides list where clicking each ride over its full horizontal
///   width opens its dedicated receipt superposed on the interactive map with coordinates.
/// - Clean pagination controls for browsing earlier rides, built for easy remote API connection.
///
/// Tab "REMBOURSEMENTS":
/// - Hero dark card with orange circular curve, "Total remboursé" (2 900 F), and Orange Money account.
/// - "HISTORIQUE" list of refund cards (completed and pending) with amounts and badges.
/// - Descriptive footnote at the bottom.
class ActivityPage extends StatefulWidget {
  final ActivityTab initialTab;

  const ActivityPage({
    super.key,
    this.initialTab = ActivityTab.courses,
  });

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  late ActivityTab _currentTab;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  late final ActivitySummary _summary;
  late final ActivityRideItem _recentRide;
  late final List<ActivityRideItem> _pastRides;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _summary = ActivityDataService.getSummary();
    _recentRide = ActivityDataService.getRecentRide();
    _pastRides = List<ActivityRideItem>.from(
      ActivityDataService.getPastRides(
        page: 1,
        pageSize: AppConstants.activityItemsPerPage,
      ),
    );
    final total = ActivityDataService.getTotalPastRidesCount();
    _hasMore = _pastRides.length < total;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_currentTab == ActivityTab.courses &&
        !_isLoadingMore &&
        _hasMore &&
        _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 80) {
      _loadMoreRides();
    }
  }

  Future<void> _loadMoreRides() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    // Simulated network delay (ready to connect to real API later)
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final nextPage = _currentPage + 1;
    final newItems = ActivityDataService.getPastRides(
      page: nextPage,
      pageSize: AppConstants.activityItemsPerPage,
    );

    setState(() {
      _isLoadingMore = false;
      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        _currentPage = nextPage;
        _pastRides.addAll(newItems);
        final total = ActivityDataService.getTotalPastRidesCount();
        if (_pastRides.length >= total) {
          _hasMore = false;
        }
      }
    });
  }

  void _openReceipt(ActivityRideItem ride) {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: RideReceiptPage(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar: Circular back button and "ACTIVITÉ"
            _buildTopAppBar(),

            // Segmented pill toggle: COURSES / REMBOURSEMENTS
            _buildSegmentedToggle(),

            // Tab content with mobile infinite scroll listener
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (_currentTab == ActivityTab.courses &&
                      !_isLoadingMore &&
                      _hasMore &&
                      scrollInfo.metrics.pixels >=
                          scrollInfo.metrics.maxScrollExtent - 60) {
                    _loadMoreRides();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd,
                  ),
                  child: _currentTab == ActivityTab.courses
                      ? _buildCoursesTabContent()
                      : _buildRefundsTabContent(),
                ),
              ),
            ),
          ],
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
              'ACTIVITÉ',
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

  Widget _buildSegmentedToggle() {
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
              title: 'COURSES',
              isSelected: _currentTab == ActivityTab.courses,
              onTap: () {
                if (_currentTab != ActivityTab.courses) {
                  setState(() => _currentTab = ActivityTab.courses);
                }
              },
            ),
          ),
          Expanded(
            child: _buildTogglePill(
              title: 'REMBOURSEMENTS',
              isSelected: _currentTab == ActivityTab.remboursements,
              onTap: () {
                if (_currentTab != ActivityTab.remboursements) {
                  setState(() => _currentTab = ActivityTab.remboursements);
                }
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

  Widget _buildCoursesTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Two Summary Metric Cards
        _buildMetricCardsRow(),

        const SizedBox(height: AppConstants.spacingLg),

        // 2. Section "RÉCENT"
        Text(
          'RÉCENT',
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontSm,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),

        // 3. Featured Recent Ride Card with Map preview
        _buildRecentRideCard(_recentRide),

        const SizedBox(height: AppConstants.spacingLg),

        // 4. Section "PLUS TÔT"
        Text(
          'PLUS TÔT',
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontSm,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppConstants.spacingUnitLg),

        // 5. Earlier Rides list (Mobile Infinite Scroll)
        ...List.generate(_pastRides.length, (index) {
          final ride = _pastRides[index];
          final isLast = index == _pastRides.length - 1;
          return Padding(
            padding: EdgeInsets.only(
              bottom: isLast ? 0 : AppConstants.spacingUnitLg,
            ),
            child: _buildPastRideTile(ride),
          );
        }),

        const SizedBox(height: AppConstants.spacingMd),

        // 6. Mobile Pagination Loader
        if (_isLoadingMore)
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
    );
  }

  Widget _buildMetricCardsRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingUnitLg,
            ),
            decoration: BoxDecoration(
              color: AppColors.grayBgLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Courses payées',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  '${_summary.paidRidesCount}',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontNumberBig,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slateDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingUnitLg),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingUnitLg,
            ),
            decoration: BoxDecoration(
              color: AppColors.grayBgLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total dépensé',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  _summary.totalSpentFormatted,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontTitleLarge,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slateDark,
                  ),
                ),
              ],
            ),
          ),
        ),
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
              // Top half: Map Trajectory Preview
              SizedBox(
                height: AppConstants.activityMapPreviewHeight,
                child: Stack(
                  children: [
                    // Embedded Map with route polyline
                    IgnorePointer(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            (ride.departure.latitude + ride.destination.latitude) / 2,
                            (ride.departure.longitude + ride.destination.longitude) / 2,
                          ),
                          zoom: 12.8,
                        ),
                        polylines: {
                          Polyline(
                            polylineId: const PolylineId('recent_preview_line'),
                            points: ride.polylinePoints,
                            color: AppColors.slateDark,
                            width: AppConstants.mapPolylineWidth.toInt(),
                          ),
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('preview_origin'),
                            position: LatLng(
                              ride.departure.latitude,
                              ride.departure.longitude,
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueOrange,
                            ),
                          ),
                          Marker(
                            markerId: const MarkerId('preview_destination'),
                            position: LatLng(
                              ride.destination.latitude,
                              ride.destination.longitude,
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            ),
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
                          Row(
                            children: [
                              Container(
                                width: AppConstants.iconSizeLg,
                                height: AppConstants.iconSizeLg,
                                decoration: const BoxDecoration(
                                  color: AppColors.grayBgLight,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  ride.driverInitials,
                                  style: GoogleFonts.inter(
                                    fontSize: AppConstants.fontXs,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.slateDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacingS),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingUnit,
                            vertical: AppConstants.spacingXs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.receiptPaidBadgeBg,
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusFull),
                          ),
                          child: Text(
                            ride.status,
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontXs,
                              fontWeight: FontWeight.w700,
                              color: AppColors.receiptPaidBadgeText,
                            ),
                          ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingUnit,
                      vertical: AppConstants.spacingXxs,
                    ),
                    decoration: BoxDecoration(
                      color: ride.isRefunded
                          ? AppColors.grayBgLight
                          : AppColors.receiptPaidBadgeBg,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusFull),
                    ),
                    child: Text(
                      ride.status,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontXs,
                        fontWeight: FontWeight.w700,
                        color: ride.isRefunded
                            ? AppColors.slateDark
                            : AppColors.receiptPaidBadgeText,
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



  // ==========================================
  // REMBOURSEMENTS TAB
  // ==========================================

  Widget _buildRefundsTabContent() {
    final refunds = ActivityDataService.getRefunds();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hero Dark Card with Orange Curve
        _buildRefundHeroCard(),

        const SizedBox(height: AppConstants.spacingLg),

        // 2. Section "HISTORIQUE"
        Text(
          'HISTORIQUE',
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontSm,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppConstants.spacingUnitLg),

        // 3. Refunds list
        ...refunds.map((refund) => Padding(
              padding: const EdgeInsets.only(
                bottom: AppConstants.spacingUnitLg,
              ),
              child: _buildRefundItemCard(refund),
            )),

        const SizedBox(height: AppConstants.spacingLg),

        // 4. Footnote text
        Center(
          child: Text(
            'Les remboursements sont renvoyés sur le moyen de paiement utilisé pour la course.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontSm,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacingXl),
      ],
    );
  }

  Widget _buildRefundHeroCard() {
    return Container(
      height: AppConstants.activityRefundCardHeight,
      decoration: BoxDecoration(
        color: AppColors.drawerDark,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowDarkBlack,
            blurRadius: AppConstants.spacingUnit,
            offset: Offset(0, AppConstants.spacingXs),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Orange circle accent positioned strictly in the top-right corner (matching Screenshot 2)
          Positioned(
            top: AppConstants.activityCircleAccentTop,
            right: AppConstants.activityCircleAccentRight,
            child: Container(
              width: AppConstants.activityCircleAccentSize,
              height: AppConstants.activityCircleAccentSize,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Card contents
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingUnitLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total remboursé',
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w500,
                        color: AppColors.white70,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXxs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '2 900',
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontHero,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingXs),
                        Text(
                          'F',
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontTitle,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Orange Money account indicator
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: AppConstants.spacingXxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusXs),
                      ),
                      child: Text(
                        'OM',
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontXs,
                          fontWeight: FontWeight.w900,
                          color: AppColors.drawerDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(
                      child: Text(
                        'Sur ${_summary.refundPaymentAccount}',
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontSm,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundItemCard(ActivityRefundItem refund) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: refund.associatedRide != null
            ? () => _openReceipt(refund.associatedRide!)
            : null,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.grayBgLight,
            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: AppConstants.circularAvatarSize,
                height: AppConstants.circularAvatarSize,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  refund.isPending
                      ? Icons.access_time_rounded
                      : Icons.refresh_rounded,
                  size: AppConstants.iconSizeLg,
                  color: refund.isPending
                      ? AppColors.primary
                      : AppColors.greenSuccess,
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitLg),

              // Title and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      refund.title,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontBase,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slateDark,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXxs),
                    Text(
                      refund.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount & Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    refund.amountText,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontLg,
                      fontWeight: FontWeight.w900,
                      color: refund.isPending
                          ? AppColors.primary
                          : AppColors.greenSuccess,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingUnit,
                      vertical: AppConstants.spacingXxs,
                    ),
                    decoration: BoxDecoration(
                      color: refund.isPending
                          ? AppColors.orangeLightBg
                          : AppColors.refundPillBg,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusFull),
                    ),
                    child: Text(
                      refund.status,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontXs,
                        fontWeight: FontWeight.w700,
                        color: refund.isPending
                            ? AppColors.primary
                            : AppColors.greenSuccess,
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
