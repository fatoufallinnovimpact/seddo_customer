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
/// Interface moderne avec titre i18n dynamique ("Où allons-nous ?"),
/// Real address autocomplete with "Ma position actuelle" GPS shortcut,
/// Origin/Destination input fields with swap button, category filters (Tous, Dem Dikk, AFTU, BRT, TER),
/// vehicle photos, expandable stops list, navigation towards nearest stop,
/// and floating Seddo VTC shortcut card that stays visible over the scrolling list.
class PublicTransportPage extends StatefulWidget {
  final String initialOrigin;
  final String initialDestination;
  final bool autoSearch;

  const PublicTransportPage({
    super.key,
    this.initialOrigin = '',
    this.initialDestination = '',
    this.autoSearch = false,
  });

  @override
  State<PublicTransportPage> createState() => _PublicTransportPageState();
}

class _PublicTransportPageState extends State<PublicTransportPage> {
  final PublicTransportService _service = PublicTransportService();
  final PlacesService _placesService = PlacesService();

  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  // GPS coordinates for Transit v2 backend API (defaults to Dakar center until GPS resolution)
  double _originLat = 14.6937949;
  double _originLng = -17.4914255;
  double _destinationLat = 14.7115399;
  double _destinationLng = -17.47601;

  TcuRouteFilter _selectedRouteFilter = TcuRouteFilter.fastest;
  List<TcuRouteOption> _allOptions = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  // Selected Date and Time for TCU travel matching design
  DateTime _selectedDate = DateTime(2026, 10, 27);
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 10);

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
    final originText = widget.initialOrigin.isNotEmpty
        ? widget.initialOrigin
        : 'Ma position actuelle';
    _originController = TextEditingController(text: originText);
    _destinationController =
        TextEditingController(text: widget.initialDestination);

    if (widget.initialOrigin.isEmpty ||
        widget.initialOrigin == 'Ma position actuelle') {
      _selectCurrentPositionAsOrigin();
    } else {
      _resolvePresetCoordinates(widget.initialOrigin, true);
    }

    if (widget.initialDestination.isNotEmpty) {
      _resolvePresetCoordinates(widget.initialDestination, false);
    }

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

    final now = DateTime.now();
    _selectedDate = now.year >= 2026 ? now : DateTime(2026, 10, 27);

    if (widget.autoSearch && _destinationController.text.isNotEmpty) {
      _hasSearched = true;
      _loadRoutes();
    }
  }

  void _resolvePresetCoordinates(String place, bool isOrigin) {
    final lower = place.toLowerCase();
    double? lat;
    double? lng;
    if (lower.contains('ouakam')) {
      lat = 14.7231;
      lng = -17.4912;
    } else if (lower.contains('plateau')) {
      lat = 14.6738;
      lng = -17.4372;
    } else if (lower.contains('almadies')) {
      lat = 14.7431;
      lng = -17.5195;
    } else if (lower.contains('fann')) {
      lat = 14.6937949;
      lng = -17.4914255;
    } else if (lower.contains('libert')) {
      lat = 14.7115399;
      lng = -17.47601;
    }
    if (lat != null && lng != null) {
      if (isOrigin) {
        _originLat = lat;
        _originLng = lng;
      } else {
        _destinationLat = lat;
        _destinationLng = lng;
      }
    }
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

  String get _formattedDate {
    final d = _selectedDate.day.toString().padLeft(2, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final y = _selectedDate.year.toString();
    return '$d-$m-$y';
  }

  String get _formattedTime {
    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _onSearchPressed() async {
    FocusScope.of(context).unfocus();
    if (_destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez entrer une destination',
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.buttonBlack,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _showSuggestions = false;
      _hasSearched = true;
    });
    await _resolveManualCoordinatesIfNeeded();
    _loadRoutes();
  }

  Future<void> _resolveManualCoordinatesIfNeeded() async {
    // 1. Resolve origin coordinates if typed manually and not 'Ma position actuelle'
    if (_originController.text.trim().isNotEmpty &&
        _originController.text != 'Ma position actuelle') {
      final matches = await _placesService.autocomplete(_originController.text);
      if (matches.isNotEmpty) {
        final m = matches.first;
        if (m.latitude != null && m.longitude != null) {
          _originLat = m.latitude!;
          _originLng = m.longitude!;
        } else {
          try {
            final d = await _placesService.details(m.placeId);
            _originLat = d.lat;
            _originLng = d.lng;
          } catch (_) {}
        }
      }
    } else if (_originController.text == 'Ma position actuelle') {
      try {
        final coords = await _placesService.getCurrentCoordinates();
        if (coords != null) {
          _originLat = coords.latitude;
          _originLng = coords.longitude;
        }
      } catch (_) {}
    }

    // 2. Resolve destination coordinates if typed manually
    if (_destinationController.text.trim().isNotEmpty) {
      final matches =
          await _placesService.autocomplete(_destinationController.text);
      if (matches.isNotEmpty) {
        final m = matches.first;
        if (m.latitude != null && m.longitude != null) {
          _destinationLat = m.latitude!;
          _destinationLng = m.longitude!;
        } else {
          try {
            final d = await _placesService.details(m.placeId);
            _destinationLat = d.lat;
            _destinationLng = d.lng;
          } catch (_) {}
        }
      }
    }
  }

  List<TcuRouteOption> get _filteredOptions {
    if (_allOptions.isEmpty) return [];
    switch (_selectedRouteFilter) {
      case TcuRouteFilter.fastest:
        final list = List<TcuRouteOption>.from(_allOptions);
        list.sort((a, b) => a.estimatedDurationMinutes
            .compareTo(b.estimatedDurationMinutes));
        return list;
      case TcuRouteFilter.alternative:
        final list = _allOptions
            .where((o) =>
                o.type == TcuTransportType.aftu ||
                o.type == TcuTransportType.brt)
            .toList();
        return list.isNotEmpty ? list : _allOptions;
      case TcuRouteFilter.panoramic:
        final list = _allOptions
            .where((o) =>
                o.type == TcuTransportType.ddd ||
                o.type == TcuTransportType.ter)
            .toList();
        return list.isNotEmpty ? list : _allOptions;
    }
  }

  String _getFilterDuration(TcuRouteFilter filter) {
    switch (filter) {
      case TcuRouteFilter.fastest:
        return '26 min';
      case TcuRouteFilter.alternative:
        return '33 min';
      case TcuRouteFilter.panoramic:
        return '30 min';
    }
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    final options = await _service.getRouteOptions(
      origin: _originController.text,
      destination: _destinationController.text,
      departureLat: _originLat,
      departureLon: _originLng,
      destinationLat: _destinationLat,
      destinationLon: _destinationLng,
      date: _selectedDate,
      time: _selectedTime,
      maxDistanceFrom: 2000,
      maxDistanceTo: 2000,
      orderByFrom: true,
      filter: TcuTransportType.all,
    );
    if (mounted) {
      setState(() {
        _allOptions = options;
        _isLoading = false;
      });
    }
  }

  void _swapOriginAndDestination() {
    final temp = _originController.text;
    _originController.text = _destinationController.text;
    _destinationController.text = temp;

    final tempLat = _originLat;
    final tempLng = _originLng;
    _originLat = _destinationLat;
    _originLng = _destinationLng;
    _destinationLat = tempLat;
    _destinationLng = tempLng;

    setState(() {
      _showSuggestions = false;
    });
    _originFocusNode.unfocus();
    _destinationFocusNode.unfocus();
    if (_hasSearched) {
      _loadRoutes();
    }
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
      final coords = await _placesService.getCurrentCoordinates();
      if (coords != null && mounted) {
        setState(() {
          _originLat = coords.latitude;
          _originLng = coords.longitude;
        });
      }
    } catch (_) {}

    if (_hasSearched) {
      _loadRoutes();
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final text = suggestion.mainText ?? suggestion.description;
    double? lat = suggestion.latitude;
    double? lng = suggestion.longitude;

    if (lat == null || lng == null) {
      try {
        final details = await _placesService.details(suggestion.placeId);
        lat = details.lat;
        lng = details.lng;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        if (_isEditingOrigin) {
          _originController.text = text;
          if (lat != null && lng != null) {
            _originLat = lat;
            _originLng = lng;
          }
        } else {
          _destinationController.text = text;
          if (lat != null && lng != null) {
            _destinationLat = lat;
            _destinationLng = lng;
          }
        }
        _showSuggestions = false;
      });
    }

    _originFocusNode.unfocus();
    _destinationFocusNode.unfocus();

    if (_hasSearched) {
      _loadRoutes();
    }
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
              // Scrollable entire page content: header, search box, date/time and results all scroll together
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: Back button and "Où allons-nous ?" title with orange underline
                    _buildHeader(context),

                    // Origin & Destination Card with Swap button and autocomplete triggers
                    _buildSearchBox(),

                    // Date, Time & Rechercher Button Bar (from user attachment)
                    _buildDateTimeSearchBar(),

                    // Filter Chips Bar (Plus rapide, Alternative, Panoramique)
                    _buildFilterBar(),

                    // Subtitle counter (e.g. "4 options pour votre trajet")
                    if (_hasSearched)
                      _buildCountSubtitle(),

                    // Route Proposition List OR Pre-search placeholder
                    if (!_hasSearched)
                      _buildPreSearchPlaceholder()
                    else if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    else
                      _buildRoutesList(),

                    // Bottom padding so bottom route cards are not obscured by floating Seddo card
                    SizedBox(
                      height: (_showSeddoCard && _hasSearched)
                          ? 110
                          : AppConstants.spacingLg,
                    ),
                  ],
                ),
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
              if (_showSeddoCard && !_showSuggestions && _hasSearched)
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
                // Trait d'accentuation sous l'onglet actif
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
                    _onSearchPressed();
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
                    hintText: isOrigin
                        ? 'Ma position actuelle'
                        : 'Rechercher une destination...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: AppConstants.fontBase,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
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

  /// Carte flottante de raccourci Seddo VTC.
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
                // Icône véhicule de transport
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

  Widget _buildDateTimeSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: 4,
      ),
      child: Row(
        children: [
          // 1. Date Selector (e.g. 📅 27-10-2026)
          Expanded(
            flex: 4,
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                key: const Key('tcu_date_picker_button'),
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowLight,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formattedDate,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 2. Time Selector (e.g. 12:10)
          Expanded(
            flex: 3,
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                key: const Key('tcu_time_picker_button'),
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowLight,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formattedTime,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 3. Rechercher Button (Orange)
          Expanded(
            flex: 4,
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                key: const Key('tcu_search_button'),
                onTap: _onSearchPressed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'tcu.search'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreSearchPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'tcu.plan_trip'.tr(),
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'tcu.plan_trip_subtitle'.tr(),
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    const filters = [
      TcuRouteFilter.fastest,
      TcuRouteFilter.alternative,
      TcuRouteFilter.panoramic,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedRouteFilter == filter;
          final duration = _getFilterDuration(filter);

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              key: Key('tcu_filter_${filter.name}'),
              onTap: () {
                setState(() {
                  _selectedRouteFilter = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1350B8)
                      : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x331350B8),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      filter.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.white
                            : AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      duration,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? AppColors.white.withValues(alpha: 0.9)
                            : AppColors.textSecondary,
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
    final count = _filteredOptions.length;
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
    final routes = _filteredOptions;
    if (routes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'Aucune option trouvée pour ce trajet',
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontBase,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Column(
        children: routes.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isExpanded = _expandedStopsRouteIds.contains(option.id);

          return _buildRouteTimelineItem(
            option: option,
            isExpanded: isExpanded,
            isLast: index == routes.length - 1,
          );
        }).toList(),
      ),
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
          // Ligne temporelle verticale de l'itinéraire à pied
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

          // Carte principale de proposition de transport
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
          // Visuel du véhicule et référence de la ligne
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

          // Nom de l'arrêt et résumé du trajet piéton
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

          // Métriques de trajet (Prochain départ, Durée, Arrêts)
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

          // Actions rapides : Itinéraire vers l'arrêt et détails des arrêts
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
