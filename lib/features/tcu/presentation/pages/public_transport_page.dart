import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/features/tcu/data/models/tcu_route_model.dart';
import 'package:seddo/features/tcu/data/services/public_transport_service.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_stop_route_page.dart';
import 'package:seddo/services/places_service.dart';

/// Main Public Transport (TCU) page for Dakar.
/// Matches user screenshots with dynamic i18n title ("Où allons-nous ?"),
/// Real address autocomplete with "Ma position actuelle" GPS shortcut,
/// Origin/Destination input fields with swap button, category filters (Tous, Dem Dikk, AFTU, BRT, TER),
/// vehicle photos, expandable stops list, navigation towards nearest stop,
/// and floating Seddo VTC shortcut card that stays visible over the scrolling list.
class PublicTransportPage extends StatefulWidget {
  final String initialOrigin;
  final String initialDestination;

  const PublicTransportPage({
    super.key,
    this.initialOrigin = 'Fann Hock',
    this.initialDestination = 'Liberté 6',
  });

  @override
  State<PublicTransportPage> createState() => _PublicTransportPageState();
}

class _PublicTransportPageState extends State<PublicTransportPage> {
  final PublicTransportService _service = const PublicTransportService();
  final PlacesService _placesService = PlacesService();

  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  TcuTransportType _selectedFilter = TcuTransportType.all;
  List<TcuRouteOption> _allOptions = [];
  bool _isLoading = true;

  // Track expanded stops lists per route ID
  final Set<String> _expandedStopsRouteIds = {};

  // Autocomplete suggestions state
  bool _isEditingOrigin = false;
  bool _showSuggestions = false;
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounceTimer;

  // Floating Seddo VTC card state (dismissible with close cross)
  bool _showSeddoCard = true;

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController(text: widget.initialOrigin);
    _destinationController =
        TextEditingController(text: widget.initialDestination);

    _originFocusNode.addListener(() {
      if (_originFocusNode.hasFocus) {
        setState(() {
          _isEditingOrigin = true;
          _showSuggestions = true;
        });
        _searchPlaces(_originController.text);
      }
    });

    _destinationFocusNode.addListener(() {
      if (_destinationFocusNode.hasFocus) {
        setState(() {
          _isEditingOrigin = false;
          _showSuggestions = true;
        });
        _searchPlaces(_destinationController.text);
      }
    });

    _loadRoutes();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    final options = await _service.getRouteOptions(
      origin: _originController.text,
      destination: _destinationController.text,
      filter: _selectedFilter,
    );
    if (mounted) {
      setState(() {
        _allOptions = options;
        _isLoading = false;
      });
    }
  }

  void _onFilterChanged(TcuTransportType filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
    });
    _loadRoutes();
  }

  void _swapOriginAndDestination() {
    final temp = _originController.text;
    _originController.text = _destinationController.text;
    _destinationController.text = temp;
    setState(() {
      _showSuggestions = false;
    });
    _originFocusNode.unfocus();
    _destinationFocusNode.unfocus();
    _loadRoutes();
  }

  void _toggleStopsExpansion(String routeId) {
    setState(() {
      if (_expandedStopsRouteIds.contains(routeId)) {
        _expandedStopsRouteIds.remove(routeId);
      } else {
        _expandedStopsRouteIds.add(routeId);
      }
    });
  }

  void _openStopNavigation(TcuRouteOption option) {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: PublicTransportStopRoutePage(routeOption: option),
      ),
    );
  }

  void _triggerDebouncedSearch(String input) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchPlaces(input);
    });
  }

  Future<void> _searchPlaces(String query) async {
    final clean = query.trim();
    final results = await _placesService.autocomplete(clean);
    if (mounted) {
      setState(() {
        _suggestions = results;
      });
    }
  }

  Future<void> _selectCurrentPositionAsOrigin() async {
    setState(() {
      _originController.text = 'Ma position actuelle';
      _showSuggestions = false;
    });
    _originFocusNode.unfocus();
    _destinationFocusNode.unfocus();

    try {
      final currentPlace = await _placesService.getCurrentPlace();
      if (currentPlace != null && mounted) {
        setState(() {
          _originController.text = currentPlace.mainText;
        });
      }
    } catch (_) {}

    _loadRoutes();
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    final text = suggestion.mainText ?? suggestion.description;
    if (_isEditingOrigin) {
      _originController.text = text;
    } else {
      _destinationController.text = text;
    }
    setState(() {
      _showSuggestions = false;
    });
    _originFocusNode.unfocus();
    _destinationFocusNode.unfocus();
    _loadRoutes();
  }

  void _openSeddoRideSearch() {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: PlaceSearchPage(
          initialPickup: _originController.text,
          initialDestination: _destinationController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_showSuggestions) {
            setState(() => _showSuggestions = false);
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              // Main content Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Bar: Back button and "Où allons-nous ?" title with orange underline
                  _buildHeader(context),

                  // Origin & Destination Card with Swap button and autocomplete triggers
                  _buildSearchBox(),

                  // Filter Chips Bar (Tous, Dem Dikk, AFTU, BRT, TER)
                  _buildFilterBar(),

                  // Subtitle counter (e.g. "4 options pour votre trajet")
                  _buildCountSubtitle(),

                  // Route Proposition List
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2.5,
                            ),
                          )
                        : _buildRoutesList(),
                  ),
                ],
              ),

              // Autocomplete suggestions dropdown overlay
              if (_showSuggestions)
                Positioned(
                  top: 140,
                  left: AppConstants.spacingMd,
                  right: AppConstants.spacingMd,
                  child: _buildSuggestionsDropdown(),
                ),

              // Floating Seddo VTC card at bottom (stays above page when scrolling)
              if (_showSeddoCard && !_showSuggestions)
                Positioned(
                  left: AppConstants.spacingMd,
                  right: AppConstants.spacingMd,
                  bottom: AppConstants.spacingMd,
                  child: _buildFloatingSeddoCard(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final titleText = 'tcu.title'.tr();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: AppConstants.iconSizeLg,
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'common.back'.tr(),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontTitleLarge,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Distinctive orange accent line matching Screenshot 1
                Container(
                  height: AppConstants.tcuUnderlineHeight,
                  width: AppConstants.tcuUnderlineWidth,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingUnitLg,
        vertical: AppConstants.spacingUnit,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(color: AppColors.tcuFieldBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Column(
            children: [
              // Origin Input Field with GPS shortcut
              _buildLocationField(
                label: 'tcu.origin_label'.tr(),
                controller: _originController,
                focusNode: _originFocusNode,
                isOrigin: true,
                leadingIcon: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textSecondary,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(
                  height: 1,
                  thickness: 0.8,
                  color: AppColors.border,
                ),
              ),
              // Destination Input Field
              _buildLocationField(
                label: 'tcu.destination_label'.tr(),
                controller: _destinationController,
                focusNode: _destinationFocusNode,
                isOrigin: false,
                leadingIcon: const Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
            ],
          ),

          // Swap vertical button on the right
          GestureDetector(
            key: const Key('tcu_swap_button'),
            onTap: _swapOriginAndDestination,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/switch-vertical-svgrepo-com.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Widget leadingIcon,
    required bool isOrigin,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingUnit,
        vertical: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontXs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              if (isOrigin) ...[
                const Spacer(),
                GestureDetector(
                  onTap: _selectCurrentPositionAsOrigin,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ma position',
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontXs,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 36), // Spacing for swap button
              ],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              leadingIcon,
              const SizedBox(width: AppConstants.spacingUnit),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (val) {
                    _isEditingOrigin = isOrigin;
                    _showSuggestions = true;
                    _triggerDebouncedSearch(val);
                  },
                  onSubmitted: (_) {
                    setState(() => _showSuggestions = false);
                    _loadRoutes();
                  },
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontBase,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    suffixIcon: controller.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              controller.clear();
                              _isEditingOrigin = isOrigin;
                              _triggerDebouncedSearch('');
                            },
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40), // Spacing for swap button
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsDropdown() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(color: AppColors.tcuFieldBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          shrinkWrap: true,
          children: [
            // If editing origin, show "Ma position actuelle" as first item
            if (_isEditingOrigin) ...[
              ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0x1AFF5722),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  'Ma position actuelle',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                subtitle: Text(
                  'Position GPS en direct',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontXs,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: _selectCurrentPositionAsOrigin,
              ),
              const Divider(height: 1, thickness: 0.6, color: AppColors.border),
            ],

            // List of autocomplete suggestions
            ..._suggestions.map((suggestion) {
              return ListTile(
                dense: true,
                leading: const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  suggestion.mainText ?? suggestion.description,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  suggestion.secondaryText ?? suggestion.description,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontXs,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _selectSuggestion(suggestion),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Floating dark Seddo VTC card matching user screenshot (media_1792705913474.png).
  /// Stays visible floating over the page during scrolling, dismissible with ✕ button.
  Widget _buildFloatingSeddoCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.only(
        left: 16,
        right: 14,
        top: 14,
        bottom: 14,
      ),
      child: Stack(
        children: [
          // Main interactive card row
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openSeddoRideSearch,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Car icon matching screenshot
                const Icon(
                  Icons.directions_car_outlined,
                  color: AppColors.white,
                  size: 26,
                ),
                const SizedBox(width: 14),

                // Text: "En Seddo : 19 min, porte à porte" & "Prix fixe 3 200 F"
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'En Seddo : 19 min, porte',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'à porte',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Prix fixe 3 200 F',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFA0A0A0),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Orange "Commander" button
                ElevatedButton(
                  key: const Key('tcu_seddo_commander_button'),
                  onPressed: _openSeddoRideSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: AppConstants.elevationNone,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    'Commander',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 24), // Leave space for close button
              ],
            ),
          ),

          // Close button (✕) to dismiss if user wants to hide it
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              key: const Key('tcu_seddo_card_close'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _showSeddoCard = false;
                });
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF444444), width: 1),
                ),
                child: const Icon(
                  Icons.close,
                  size: 13,
                  color: Color(0xFFCCCCCC),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      TcuTransportType.all,
      TcuTransportType.ddd,
      TcuTransportType.aftu,
      TcuTransportType.brt,
      TcuTransportType.ter,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: AppConstants.spacingSm),
            child: GestureDetector(
              onTap: () => _onFilterChanged(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingUnitXl,
                  vertical: AppConstants.spacingUnit,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.buttonBlack : AppColors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.buttonBlack
                        : AppColors.tcuFieldBorder,
                  ),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: AppColors.shadowLight,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (filter != TcuTransportType.all) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: filter.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      filter.displayName,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontMd,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? AppColors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCountSubtitle() {
    final count = _allOptions.length;
    final text = count <= 1
        ? 'tcu.options_count_singular'.tr()
        : 'tcu.options_count'.tr(args: [count.toString()]);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: 4,
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: AppConstants.fontMd,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildRoutesList() {
    if (_allOptions.isEmpty) {
      return Center(
        child: Text(
          'Aucune option trouvée pour ce trajet',
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontBase,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        left: AppConstants.spacingMd,
        right: AppConstants.spacingMd,
        top: AppConstants.spacingSm,
        bottom: _showSeddoCard ? 110 : AppConstants.spacingMd,
      ),
      itemCount: _allOptions.length,
      itemBuilder: (context, index) {
        final option = _allOptions[index];
        final isExpanded = _expandedStopsRouteIds.contains(option.id);

        return _buildRouteTimelineItem(
          option: option,
          isExpanded: isExpanded,
          isLast: index == _allOptions.length - 1,
        );
      },
    );
  }

  Widget _buildRouteTimelineItem({
    required TcuRouteOption option,
    required bool isExpanded,
    required bool isLast,
  }) {
    final stop = option.departureStop;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical Timeline Track on the left (Screenshot 1)
          Column(
            children: [
              // Origin node (orange ring)
              Container(
                width: AppConstants.tcuTimelineDotSize,
                height: AppConstants.tcuTimelineDotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 3.5,
                  ),
                ),
              ),
              // Dotted walking line
              Container(
                width: 2,
                height: 48,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: CustomPaint(
                  painter: _DottedLinePainter(
                    color: AppColors.tcuTimelineTrack,
                    dashHeight: 4,
                    dashSpace: 4,
                  ),
                ),
              ),
              // Transit Stop Icon Badge (Blue square with bus icon)
              Container(
                width: AppConstants.tcuBadgeSize,
                height: AppConstants.tcuBadgeSize,
                decoration: BoxDecoration(
                  color: AppColors.tcuAftuBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(
                    option.isTrain ? Icons.train : Icons.directions_bus,
                    color: AppColors.white,
                    size: 16,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 120,
                  margin: const EdgeInsets.only(top: 4),
                  color: AppColors.tcuTimelineTrack,
                ),
            ],
          ),
          const SizedBox(width: AppConstants.spacingUnitLg),

          // Main Proposition Card on the right (Screenshot 1 & 3)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Origin and walking leg header
                Row(
                  children: [
                    Text(
                      _originController.text,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontBase,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_walk,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stop.walkingDistanceMeters} m  |  ${stop.walkingDurationMinutes} min',
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingUnit),

                // Stop name label
                Text(
                  stop.name,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontMd,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingSm),

                // Proposition Card with vehicle image, metrics and buttons
                _buildOptionCard(
                  option: option,
                  isExpanded: isExpanded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required TcuRouteOption option,
    required bool isExpanded,
  }) {
    final stop = option.departureStop;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(color: AppColors.tcuFieldBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppConstants.spacingUnitLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Image and Line info row (Screenshot 1)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vehicle photo
              SizedBox(
                width: 90,
                height: AppConstants.tcuVehicleImageHeight,
                child: Image.asset(
                  option.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.grayBgLight,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSm),
                    ),
                    child: Icon(
                      option.isTrain ? Icons.train : Icons.directions_bus,
                      color: option.typeColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitLg),

              // Labels: "Ligne de bus : DDD 10" and "Durée estimée: 19 min"
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: '${option.linePrefix} ',
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontSm,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: option.lineCode,
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontBase,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        text:
                            '${'tcu.estimated_duration'.tr(args: ['']).trim()} ',
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontSm,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: option.estimatedDurationText,
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontBase,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingUnitLg),
          const Divider(height: 1, thickness: 0.8, color: AppColors.border),
          const SizedBox(height: AppConstants.spacingUnitLg),

          // Stop name + Walking summary (Screenshot 3)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontBase,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.walkingSummary,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingUnitLg),

          // 3 Column Metrics (Prochain | Durée | Arrêts) (Screenshot 3)
          Row(
            children: [
              // Prochain
              Expanded(
                child: _buildMetricColumn(
                  label: 'tcu.next_departure'.tr(),
                  value: '${stop.nextArrivalMinutes} min',
                  valueColor: AppColors.textPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.border,
              ),
              // Durée (in green)
              Expanded(
                child: _buildMetricColumn(
                  label: 'tcu.duration'.tr(),
                  value: option.estimatedDurationText,
                  valueColor: AppColors.tcuDurationGreen,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.border,
              ),
              // Arrêts
              Expanded(
                child: _buildMetricColumn(
                  label: 'tcu.stops_count'.tr(),
                  value: option.stopsCount.toString(),
                  valueColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingUnitLg),

          // Buttons Row: Orange "Itinéraire vers l'arrêt" & Grey "Arrêts ∨" (Screenshot 3)
          Row(
            children: [
              // "Itinéraire vers l'arrêt"
              Expanded(
                flex: 6,
                child: ElevatedButton(
                  onPressed: () => _openStopNavigation(option),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: AppConstants.elevationNone,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spacingUnitLg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusDefault),
                    ),
                  ),
                  child: Text(
                    'tcu.route_to_stop'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontMd,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),

              // "Arrêts ∨"
              Expanded(
                flex: 4,
                child: OutlinedButton(
                  onPressed: () => _toggleStopsExpansion(option.id),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.tcuStatCardBg,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spacingUnitLg,
                      horizontal: AppConstants.spacingSm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusDefault),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'tcu.stops'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontMd,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Expandable Stops List
          if (isExpanded) ...[
            const SizedBox(height: AppConstants.spacingUnitLg),
            const Divider(height: 1, thickness: 0.8, color: AppColors.border),
            const SizedBox(height: AppConstants.spacingUnitLg),
            Text(
              'tcu.stops_list_title'.tr(),
              style: GoogleFonts.inter(
                fontSize: AppConstants.fontSm,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            ...List.generate(option.stopsList.length, (idx) {
              final stopName = option.stopsList[idx];
              final isFirst = idx == 0;
              final isLastStop = idx == option.stopsList.length - 1;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isFirst || isLastStop
                            ? AppColors.primary
                            : AppColors.tcuTimelineTrack,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingUnit),
                    Expanded(
                      child: Text(
                        stopName,
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontSm,
                          fontWeight: isFirst || isLastStop
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontSm,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for dashed/dotted lines on timeline
class _DottedLinePainter extends CustomPainter {
  final Color color;
  final double dashHeight;
  final double dashSpace;

  const _DottedLinePainter({
    required this.color,
    required this.dashHeight,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double startY = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
