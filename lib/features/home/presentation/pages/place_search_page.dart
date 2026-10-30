import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/data/models/home_suggestions_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/presentation/pages/ride_booking_page.dart';
import 'package:seddo/features/saved_places/presentation/pages/saved_places_page.dart';
import 'package:seddo/features/home/presentation/pages/select_on_map_page.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/core/utils/service_area_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/service_unavailable_sheet.dart';

/// Écran de recherche et sélection d'adresses (départ et arrivée) :
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
  final PlaceSearchResult? initialDepartureResult;
  final PlaceSearchResult? initialDestinationResult;

  const PlaceSearchPage({
    super.key,
    this.placesService,
    this.initialPickup,
    this.initialDestination,
    this.currentUserLocation,
    this.initialDepartureResult,
    this.initialDestinationResult,
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
    _arrivalController.text = widget.initialDestination ??
        widget.initialDestinationResult?.mainText ??
        '';
    _selectedDepartureResult = widget.initialDepartureResult;
    _selectedArrivalResult = widget.initialDestinationResult;

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

    // Only search places for arrival if not already prefilled with a concrete destination result
    if (_selectedArrivalResult == null && _arrivalController.text.isNotEmpty) {
      _searchPlaces(_arrivalController.text);
    } else if (_selectedArrivalResult != null) {
      _isEditingArrival = false;
    }

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
          isSelectionMode: true,
        ),
      ),
    );

    if (selectedSavedPlace != null && mounted) {
      setState(() {
        _selectedArrivalResult = selectedSavedPlace;
        _arrivalController.text = selectedSavedPlace.mainText;
        if (_departureController.text.isEmpty ||
            _departureController.text == currentPositionText) {
          _departureController.text = currentPositionText;
        }
        _suggestions = [];
      });
      _resolveInitialCurrentPosition();
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

    await RecentTripStorage.saveLastRecentTrip(arrival);
    if (!mounted) return;

    final bookingResult = await Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: RideBookingPage(
          departure: departure,
          destination: arrival,
          placesService: _placesService,
          showHowToFindYouInitially: true,
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
            // 1. Top Bar: Back Arrow
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
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowSoftBlack,
                          blurRadius: AppConstants.spacingSm,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: AppConstants.iconSizeMd,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.spacingSm),

            // 2. Departure & Arrival Card Container with Switch Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppConstants.spacingUnitXl),
                decoration: BoxDecoration(
                  color: AppColors.peachContainer,
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusHeroBanner,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd,
                    vertical: AppConstants.spacingUnitXl,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusDialog,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowSoftBlack,
                        blurRadius: AppConstants.spacingUnit,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left Column: Icons & Dotted Connecting Line
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Departure Squircle: icône spécifiant la position actuelle (silhouette passager)
                          Container(
                            width: AppConstants.searchIconBoxSize,
                            height: AppConstants.searchIconBoxSize,
                            decoration: const BoxDecoration(
                              color: AppColors.grayBgLight,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.hail_rounded,
                              color: AppColors.textPrimary,
                              size: AppConstants.iconSizeMd,
                            ),
                          ),
                          // Dotted Connecting Line
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppConstants.spacingXs,
                            ),
                            child: Column(
                              children: List.generate(
                                3,
                                (index) => Container(
                                  width: AppConstants.searchDottedDotSize,
                                  height: AppConstants.searchDottedDotSize,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: AppConstants.spacingXxs,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Arrival Squircle: icône drapeau spécifiant le point d'arrivée (flag-svgrepo-com.svg)
                          Container(
                            width: AppConstants.searchIconBoxSize,
                            height: AppConstants.searchIconBoxSize,
                            decoration: const BoxDecoration(
                              color: AppColors.peachContainer,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              'assets/icons/flag-svgrepo-com.svg',
                              width: AppConstants.iconSizeSm,
                              height: AppConstants.iconSizeSm,
                              colorFilter: const ColorFilter.mode(
                                AppColors.primary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: AppConstants.spacingUnitLg),

                      // Center Column: Departure & Arrival Input Fields
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Departure Input
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() => _isEditingArrival = false);
                                _departureFocusNode.requestFocus();
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'search.pickup_caps'.tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: AppConstants.fontXs,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                      letterSpacing:
                                          AppConstants.searchLetterSpacing,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppConstants.spacingXxs,
                                  ),
                                  TextField(
                                    controller: _departureController,
                                    focusNode: _departureFocusNode,
                                    style: GoogleFonts.inter(
                                      fontSize: AppConstants.fontBase,
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
                                ],
                              ),
                            ),

                            const SizedBox(height: AppConstants.spacingUnitXl),

                            // Arrival Input
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() => _isEditingArrival = true);
                                _arrivalFocusNode.requestFocus();
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'search.arrival_caps'.tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: AppConstants.fontXs,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                      letterSpacing:
                                          AppConstants.searchLetterSpacing,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppConstants.spacingXxs,
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _arrivalController,
                                          focusNode: _arrivalFocusNode,
                                          autofocus: true,
                                          style: GoogleFonts.inter(
                                            fontSize: AppConstants.fontBase,
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
                                      if (_arrivalController.text.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            _arrivalController.clear();
                                            _selectedArrivalResult = null;
                                          },
                                          child: Container(
                                            width: AppConstants.iconSizeMd,
                                            height: AppConstants.iconSizeMd,
                                            decoration: const BoxDecoration(
                                              color: AppColors.grayBgLight,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: AppConstants.iconSizeXs +
                                                  2.0,
                                              color: AppColors.textPrimary,
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

                      const SizedBox(width: AppConstants.spacingSm),

                      // Right Column: Floating Swap Vertical Button
                      GestureDetector(
                        onTap: _swapLocations,
                        child: Container(
                          width: AppConstants.circularIconContainerSize,
                          height: AppConstants.circularIconContainerSize,
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowSoftBlack,
                                blurRadius: AppConstants.spacingUnit,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.swap_vert_rounded,
                            color: AppColors.primary,
                            size: AppConstants.iconSizeLg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppConstants.spacingSm),

            // 3. Quick Action Chips Row (Ma position, Lieux enregistrés, Sur la carte)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildQuickActionChip(
                      icon: Icons.my_location_rounded,
                      label: 'search.my_position'.tr(),
                      onTap: _useCurrentPositionForActiveField,
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    _buildQuickActionChip(
                      icon: Icons.star_outline_rounded,
                      label: 'search.saved_places'.tr(),
                      onTap: _openSavedPlaces,
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    _buildQuickActionChip(
                      icon: Icons.map_outlined,
                      onTap: () => _openMapPicker(isArrival: _isEditingArrival),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppConstants.spacingSm),

            // 4. Section Title: "RÉSULTATS"
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingXs,
              ),
              child: Row(
                children: [
                  Text(
                    'search.results_caps'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontSm,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: AppConstants.searchLetterSpacing,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: AppConstants.spacingUnitXl,
                      height: AppConstants.spacingUnitXl,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.spacingXs),

            // 5. Results List
            Expanded(
              child: _suggestions.isEmpty && !_isLoading
                  ? Center(
                      child: Text(
                        'search.no_results'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontMd,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final item = _suggestions[index];
                        final title = item.mainText ?? item.description;
                        final subtitle = _cleanSubtitle(
                          item.secondaryText ?? item.description,
                        );
                        final distance = _getDistanceText(item);

                        return Material(
                          color: AppColors.white,
                          child: InkWell(
                            onTap: () => _onSelectSuggestion(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingMd,
                                vertical: AppConstants.spacingUnitLg,
                              ),
                              child: Row(
                                children: [
                                  // Circular icon container with location outline
                                  Container(
                                    width: AppConstants.circularButtonSize,
                                    height: AppConstants.circularButtonSize,
                                    decoration: const BoxDecoration(
                                      color: AppColors.grayBgLight,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.location_on_outlined,
                                      size: AppConstants.iconSizeMd,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: AppConstants.spacingUnitXl,
                                  ),

                                  // Title with query highlighting & Subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildHighlightedTitle(
                                          title,
                                          _isEditingArrival
                                              ? _arrivalController.text
                                              : _departureController.text,
                                        ),
                                        const SizedBox(
                                          height: AppConstants.spacingXxs,
                                        ),
                                        Text(
                                          subtitle,
                                          style: GoogleFonts.inter(
                                            fontSize:
                                                AppConstants.fontSm + 1.0,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Distance Capsule Badge
                                  if (distance.isNotEmpty) ...[
                                    const SizedBox(
                                      width: AppConstants.spacingSm,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppConstants.spacingUnit,
                                        vertical: AppConstants.spacingXs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.grayBgLight,
                                        borderRadius: BorderRadius.circular(
                                          AppConstants
                                              .searchDistancePillRadius,
                                        ),
                                      ),
                                      child: Text(
                                        distance,
                                        style: GoogleFonts.inter(
                                          fontSize: AppConstants.fontSm,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
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
                AppConstants.spacingXs,
                AppConstants.spacingMd,
                AppConstants.spacingUnitLg,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: AppConstants.elevationNone,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLg,
                      ),
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
                            fontSize: AppConstants.fontBase,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: AppConstants.iconSizeDefault,
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

  Widget _buildQuickActionChip({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        side: const BorderSide(color: AppColors.grayBorderDivider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingUnitXl,
            vertical: AppConstants.spacingSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppConstants.iconSizeDefault,
                color: AppColors.primary,
              ),
              if (label != null) ...[
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontMd - 1.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _cleanSubtitle(String text) {
    final idx = text.indexOf(' · ');
    if (idx != -1) {
      return text.substring(0, idx);
    }
    return text;
  }

  String _getDistanceText(PlaceSuggestion item) {
    if (item.distanceKm != null && item.distanceKm!.isNotEmpty) {
      return item.distanceKm!;
    }
    if (item.secondaryText != null && item.secondaryText!.contains(' · ')) {
      return item.secondaryText!.split(' · ').last;
    }
    return '';
  }

  Widget _buildHighlightedTitle(String title, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return Text(
        title,
        style: GoogleFonts.inter(
          fontSize: AppConstants.fontBase,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerTitle = title.toLowerCase();
    final matchIndex = lowerTitle.indexOf(cleanQuery);
    if (matchIndex == -1) {
      return Text(
        title,
        style: GoogleFonts.inter(
          fontSize: AppConstants.fontBase,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final before = title.substring(0, matchIndex);
    final matched = title.substring(matchIndex, matchIndex + cleanQuery.length);
    final after = title.substring(matchIndex + cleanQuery.length);

    return Text.rich(
      TextSpan(
        style: GoogleFonts.inter(
          fontSize: AppConstants.fontBase,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(
            text: matched,
            style: const TextStyle(color: AppColors.primary),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

