import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/presentation/pages/ride_booking_page.dart';
import 'package:seddo/features/saved_places/presentation/pages/saved_places_page.dart';
import 'package:seddo/features/home/presentation/pages/select_on_map_page.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/core/utils/service_area_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/service_unavailable_sheet.dart';

/// Interactive place search screen matching the reference design:
/// - Header: Back arrow + "Votre trajet"
/// - Route card container:
///   - Departure with location.svg + editable text / "Ma position actuelle"
///   - Arrival with location.svg / orange square + editable input + clear button
///   - Floating vertical switch button with switch-vertical-svgrepo-com.svg
///   - Capability for BOTH departure and arrival to use "Ma position actuelle"
/// - Quick actions:
///   - "Lieux enregistrés" with star-svgrepo-com.svg ("Maison, Travail, Aéroport")
///   - "Choisir sur la carte" with map-svgrepo-com.svg ("Placer le point d'arrivée à la main")
/// - Section "Résultats"
/// - Suggestions list with location.svg, bold place title and subtitle with distance
class PlaceSearchPage extends StatefulWidget {
  final PlacesService? placesService;
  final String? initialPickup;
  final String? initialDestination;
  final LatLng? currentUserLocation;

  const PlaceSearchPage({
    super.key,
    this.placesService,
    this.initialPickup,
    this.initialDestination,
    this.currentUserLocation,
  });

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}


class _PlaceSearchPageState extends State<PlaceSearchPage> {
  late final PlacesService _placesService;

  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _arrivalController = TextEditingController();

  final FocusNode _departureFocusNode = FocusNode();
  final FocusNode _arrivalFocusNode = FocusNode();

  PlaceSearchResult? _selectedDepartureResult;
  PlaceSearchResult? _selectedArrivalResult;

  // true if currently typing in arrival, false if typing in departure
  bool _isEditingArrival = true;

  Timer? _debounceTimer;
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;

  static const String currentPositionText = 'Ma position actuelle';

  @override
  void initState() {
    super.initState();
    _placesService = widget.placesService ?? PlacesService();

    _departureController.text =
        widget.initialPickup ?? currentPositionText;
    _arrivalController.text = widget.initialDestination ?? '';

    _arrivalController.addListener(_onArrivalChanged);
    _departureController.addListener(_onDepartureChanged);

    _departureFocusNode.addListener(() {
      if (_departureFocusNode.hasFocus) {
        setState(() {
          _isEditingArrival = false;
        });
        _searchPlaces(_departureController.text);
      }
    });

    _arrivalFocusNode.addListener(() {
      if (_arrivalFocusNode.hasFocus) {
        setState(() {
          _isEditingArrival = true;
        });
        _searchPlaces(_arrivalController.text);
      }
    });

    // Initial search for arrival
    _searchPlaces(_arrivalController.text);

    // Resolve real physical address for current position
    _resolveInitialCurrentPosition();
  }

  Future<void> _resolveInitialCurrentPosition() async {
    if (widget.initialPickup != null &&
        widget.initialPickup != currentPositionText) {
      return;
    }

    try {
      final currentPlace = await _placesService.getCurrentPlace(
        fallbackLocation: widget.currentUserLocation,
      );

      if (currentPlace != null && mounted) {
        if (_departureController.text.isEmpty ||
            _departureController.text == currentPositionText) {
          setState(() {
            _departureController.text = currentPlace.mainText;
            _selectedDepartureResult = currentPlace;
          });
        }
      }
    } catch (_) {}
  }

  void _onArrivalChanged() {
    if (_isEditingArrival) {
      _triggerDebouncedSearch(_arrivalController.text);
    }
  }

  void _onDepartureChanged() {
    if (!_isEditingArrival) {
      _triggerDebouncedSearch(_departureController.text);
    }
  }

  /// 400ms debounce as requested by the user to avoid calling the API on every keystroke
  void _triggerDebouncedSearch(String input) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _searchPlaces(input);
    });
  }

  Future<void> _searchPlaces(String input) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final cleanInput =
        input == currentPositionText ? '' : input.trim();
    final results = await _placesService.autocomplete(cleanInput);

    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    }
  }

  /// Swaps Departure and Arrival locations
  void _swapLocations() {
    final temp = _departureController.text;
    setState(() {
      _departureController.text = _arrivalController.text;
      _arrivalController.text = temp;
    });

    final activeText = _isEditingArrival
        ? _arrivalController.text
        : _departureController.text;
    _searchPlaces(activeText);
  }

  /// Sets real physical address of current position on the currently focused field
  Future<void> _useCurrentPositionForActiveField() async {
    final targetFieldIsArrival = _isEditingArrival;
    final targetController =
        targetFieldIsArrival ? _arrivalController : _departureController;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentPlace = await _placesService.getCurrentPlace(
        fallbackLocation: widget.currentUserLocation,
      );

      if (currentPlace != null && mounted) {
        setState(() {
          targetController.text = currentPlace.mainText;
          if (targetFieldIsArrival) {
            _selectedArrivalResult = currentPlace;
          } else {
            _selectedDepartureResult = currentPlace;
            _isEditingArrival = true;
            _arrivalFocusNode.requestFocus();
          }
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        targetController.text = currentPositionText;
        _isLoading = false;
      });
    }
  }

  Future<void> _openMapPicker({required bool isArrival}) async {
    _departureFocusNode.unfocus();
    _arrivalFocusNode.unfocus();

    LatLng? initialLocation;
    if (isArrival && _selectedArrivalResult != null) {
      initialLocation = LatLng(
        _selectedArrivalResult!.latitude,
        _selectedArrivalResult!.longitude,
      );
    } else if (!isArrival && _selectedDepartureResult != null) {
      initialLocation = LatLng(
        _selectedDepartureResult!.latitude,
        _selectedDepartureResult!.longitude,
      );
    }

    final PlaceSearchResult? result =
        await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: SelectOnMapPage(
          isArrival: isArrival,
          initialLocation: initialLocation,
          placesService: _placesService,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (isArrival) {
          _selectedArrivalResult = result;
          _arrivalController.text = result.mainText;
          _isEditingArrival = true;
        } else {
          _selectedDepartureResult = result;
          _departureController.text = result.mainText;
          // Switch to arrival after choosing departure on map
          _isEditingArrival = true;
          _arrivalFocusNode.requestFocus();
        }
      });
      _searchPlaces(
        isArrival ? _arrivalController.text : _departureController.text,
      );
    }
  }

  Future<void> _openSavedPlaces() async {
    _departureFocusNode.unfocus();
    _arrivalFocusNode.unfocus();

    final PlaceSearchResult? selectedSavedPlace =
        await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: SavedPlacesPage(
          placesService: _placesService,
          currentUserLocation: widget.currentUserLocation,
        ),
      ),
    );

    if (selectedSavedPlace != null && mounted) {
      setState(() {
        if (_isEditingArrival) {
          _selectedArrivalResult = selectedSavedPlace;
          _arrivalController.text = selectedSavedPlace.mainText;
        } else {
          _selectedDepartureResult = selectedSavedPlace;
          _departureController.text = selectedSavedPlace.mainText;
          _isEditingArrival = true;
          _arrivalFocusNode.requestFocus();
        }
        _suggestions = [];
      });
    }
  }

  Future<void> _onSelectSuggestion(PlaceSuggestion suggestion) async {
    setState(() => _isLoading = true);
    final details = await _placesService.details(suggestion.placeId);

    if (!mounted) return;

    final placeResult = PlaceSearchResult(
      id: suggestion.placeId,
      mainText: suggestion.mainText ?? suggestion.description,
      secondaryText: suggestion.secondaryText ?? 'Dakar, Sénégal',
      fullAddress: details.address,
      latitude: details.lat,
      longitude: details.lng,
    );

    if (_isEditingArrival) {
      setState(() {
        _selectedArrivalResult = placeResult;
        _arrivalController.text = placeResult.mainText;
        _isLoading = false;
        _suggestions = [];
      });
      FocusScope.of(context).unfocus();
    } else {
      setState(() {
        _selectedDepartureResult = placeResult;
        _departureController.text = placeResult.mainText;
        _isEditingArrival = true;
        _isLoading = false;
        _suggestions = [];
      });
      _arrivalFocusNode.requestFocus();
      _searchPlaces(_arrivalController.text);
    }
  }

  Future<void> _confirmTrip() async {
    FocusScope.of(context).unfocus();

    // 1. Prepare departure
    PlaceSearchResult departure = _selectedDepartureResult ??
        PlaceSearchResult(
          id: 'departure_current',
          mainText: _departureController.text.isNotEmpty
              ? _departureController.text
              : currentPositionText,
          secondaryText: 'Dakar, Sénégal',
          fullAddress: _departureController.text.isNotEmpty
              ? _departureController.text
              : currentPositionText,
          latitude: widget.currentUserLocation?.latitude ?? 14.7167,
          longitude: widget.currentUserLocation?.longitude ?? -17.4677,
        );

    // 2. Prepare arrival
    PlaceSearchResult arrival = _selectedArrivalResult ??
        PlaceSearchResult(
          id: 'arrival_selected',
          mainText: _arrivalController.text.isNotEmpty
              ? _arrivalController.text
              : 'Destination',
          secondaryText: 'Dakar, Sénégal',
          fullAddress: _arrivalController.text,
          latitude: 14.7450,
          longitude: -17.5180,
        );

    // If destination was typed manually, attempt geocoding
    if (_selectedArrivalResult == null && _arrivalController.text.isNotEmpty) {
      try {
        final suggestions =
            await _placesService.autocomplete(_arrivalController.text);
        if (suggestions.isNotEmpty) {
          final first = suggestions.first;
          final details = await _placesService.details(first.placeId);
          arrival = PlaceSearchResult(
            id: first.placeId,
            mainText: first.mainText ?? _arrivalController.text,
            secondaryText: first.secondaryText ?? 'Dakar, Sénégal',
            fullAddress: details.address,
            latitude: details.lat,
            longitude: details.lng,
          );
        }
      } catch (_) {}
    }

    if (!mounted) return;

    final outsideDeparture = ServiceAreaHelper.getOutsideCityName(
      latitude: departure.latitude,
      longitude: departure.longitude,
      address: '${departure.mainText}, ${departure.secondaryText}',
    );
    final outsideArrival = ServiceAreaHelper.getOutsideCityName(
      latitude: arrival.latitude,
      longitude: arrival.longitude,
      address: '${arrival.mainText}, ${arrival.secondaryText}',
    );

    final outsideCity = outsideArrival ?? outsideDeparture;
    if (outsideCity != null) {
      await ServiceUnavailableSheet.show(
        context,
        cityName: outsideCity,
      );
      return;
    }

    final bookingResult = await Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: RideBookingPage(
          departure: departure,
          destination: arrival,
          placesService: _placesService,
        ),
      ),
    );

    if (bookingResult != null && mounted) {
      Navigator.of(context).pop(
        bookingResult is PlaceSearchResult ? bookingResult : arrival,
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _departureController.dispose();
    _arrivalController.dispose();
    _departureFocusNode.dispose();
    _arrivalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Establishing reactive dependency on EasyLocalization
    final _ = context.locale;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Bar: Back Arrow + "Votre trajet"
            Padding(
              padding: const EdgeInsets.symmetric(
                 horizontal: AppConstants.spacingMd,
                 vertical: AppConstants.spacingSm,
              ),
              child: Row(
                children: [
                  Container(
                    width: AppConstants.circularButtonSize,
                    height: AppConstants.circularButtonSize,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadowSoftBlack,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Text(
                    'search.your_trip'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 2. Card Container for Departure & Arrival with Switch Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warmCream, // Soft cream warm grey background
                    borderRadius: BorderRadius.circular(AppConstants.radiusContainer),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Column: Icons + Connecting Line
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Departure Icon
                        SvgPicture.asset(
                          'assets/icons/location.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            AppColors.textPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                        // Vertical Connecting Line
                        Container(
                          width: 2,
                          height: 32,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: AppColors.inactiveIndicator,
                        ),
                        // Arrival Icon (location.svg as requested)
                        SvgPicture.asset(
                          'assets/icons/location.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            AppColors.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    // Center Column: Departure & Arrival Inputs
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Departure Row
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: !_isEditingArrival
                                  ? AppColors.white
                                  : AppColors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: !_isEditingArrival
                                  ? Border.all(
                                      color: AppColors.textPrimary,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _departureController,
                                    focusNode: _departureFocusNode,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    cursorColor: AppColors.primary,
                                    decoration: InputDecoration(
                                      hintText: 'search.pickup'.tr(),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (_departureController.text.isNotEmpty &&
                                    !_isEditingArrival) ...[
                                  GestureDetector(
                                    onTap: () {
                                      _departureController.clear();
                                      _selectedDepartureResult = null;
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                GestureDetector(
                                  onTap: () =>
                                      _openMapPicker(isArrival: false),
                                  child: SvgPicture.asset(
                                    'assets/icons/map-svgrepo-com.svg',
                                    width: 17,
                                    height: 17,
                                    colorFilter: ColorFilter.mode(
                                      !_isEditingArrival
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Arrival Row (Framed White Card matching reference image)
                          Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isEditingArrival
                                    ? AppColors.textPrimary
                                    : AppColors.cardBorder,
                                width: _isEditingArrival ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _arrivalController,
                                    focusNode: _arrivalFocusNode,
                                    autofocus: true,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    cursorColor: AppColors.primary,
                                    decoration: InputDecoration(
                                      hintText: 'search.where_to'.tr(),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (_arrivalController.text.isNotEmpty) ...[
                                  GestureDetector(
                                    onTap: () {
                                      _arrivalController.clear();
                                      _selectedArrivalResult = null;
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                GestureDetector(
                                  onTap: () =>
                                      _openMapPicker(isArrival: true),
                                  child: SvgPicture.asset(
                                    'assets/icons/map-svgrepo-com.svg',
                                    width: 17,
                                    height: 17,
                                    colorFilter: ColorFilter.mode(
                                      _isEditingArrival
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Right Side: Floating Switch Button (switch-vertical-svgrepo-com.svg)
                    GestureDetector(
                      onTap: _swapLocations,
                      child: Container(
                        width: AppConstants.circularIconContainerSize,
                        height: AppConstants.circularIconContainerSize,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.cardBorder,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowCardBlack,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/icons/switch-vertical-svgrepo-com.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            AppColors.textPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

            const SizedBox(height: 12),

            // Use Current Location Chip / Action (allows using current position for both)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
              ),
              child: GestureDetector(
                onTap: _useCurrentPositionForActiveField,
                child: Row(
                  children: [
                    const Icon(
                      Icons.my_location_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isEditingArrival
                            ? 'search.use_current_position_arrival'.tr()
                            : 'search.use_current_position_departure'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 3. Quick Actions: Lieux enregistrés & Choisir sur la carte
            _QuickActionTile(
              iconSvgPath: 'assets/icons/star-svgrepo-com.svg',
              title: 'drawer.saved_places'.tr(),
              subtitle: 'drawer.saved_places_sub'.tr(),
              onTap: _openSavedPlaces,
            ),

            _QuickActionTile(
              iconSvgPath: 'assets/icons/map-svgrepo-com.svg',
              title: 'search.choose_on_map'.tr(),
              subtitle: _isEditingArrival
                  ? 'search.choose_arrival_on_map'.tr()
                  : 'search.choose_departure_on_map'.tr(),
              onTap: () => _openMapPicker(isArrival: _isEditingArrival),
            ),

            const SizedBox(height: AppConstants.spacingUnitLg),

            // 4. Section Title: "Résultats"
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Text(
                    'search.results'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // 5. Results List
            Expanded(
              child: _suggestions.isEmpty && !_isLoading
                  ? Center(
                      child: Text(
                        'search.no_results'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _suggestions.length,
                      separatorBuilder: (context, index) => const SizedBox(
                        height: AppConstants.spacingXs,
                      ),
                      itemBuilder: (context, index) {
                        final item = _suggestions[index];
                        final title = item.mainText ?? item.description;
                        final subtitle = item.secondaryText ?? item.description;

                        return Material(
                          color: AppColors.white,
                          child: InkWell(
                            onTap: () => _onSelectSuggestion(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingMd,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  // Circular icon container with location.svg
                                  Container(
                                    width: AppConstants.circularIconContainerSize,
                                    height: AppConstants.circularIconContainerSize,
                                    decoration: const BoxDecoration(
                                      color: AppColors.iconCircleBg,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: SvgPicture.asset(
                                      'assets/icons/location.svg',
                                      width: 20,
                                      height: 20,
                                      colorFilter: const ColorFilter.mode(
                                        AppColors.textPrimary,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Title & Subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: _arrivalController.text.isNotEmpty
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                4,
                AppConstants.spacingMd,
                12,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _confirmTrip,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'search.confirm_trip'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : null,
    );
  }
}


class _QuickActionTile extends StatelessWidget {
  final String iconSvgPath;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.iconSvgPath,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: AppConstants.circularIconContainerSize,
                height: AppConstants.circularIconContainerSize,
                decoration: const BoxDecoration(
                  color: AppColors.iconCircleBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  iconSvgPath,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
