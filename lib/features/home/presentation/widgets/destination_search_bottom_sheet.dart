import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/data/models/home_suggestions_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/select_on_map_page.dart';
import 'package:seddo/features/saved_places/presentation/pages/saved_places_page.dart';
import 'package:seddo/services/network_connectivity_service.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_modal_sheet.dart';

/// Résultat retourné par le bottom sheet de recherche :
/// Contient le point de départ (potentiellement modifié/rechoisi par l'utilisateur)
/// et la destination finale sélectionnée.
class DestinationSearchSheetResult {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;

  const DestinationSearchSheetResult({
    required this.departure,
    required this.destination,
  });
}

/// Modal Bottom Sheet de recherche de destination conforme à la maquette de référence :
/// - Affichage immédiat et fluide à l'ouverture
/// - Hauteur presque jusqu'en haut de la page (~92% de l'écran)
/// - Point de départ modifiable et supprimable
/// - Quand le point de départ est effacé : affichage de l'icône de prise de position actuelle en noir
/// - Card de saisie Départ & Arrivée sans contour avec un bel effet d'ombre portée
/// - Départ : icône silhouette passager (Icons.hail_rounded) + TextField éditable/supprimable
/// - Arrivée : icône flag orange directe (assets/icons/flag-svgrepo-com.svg) + "Où allez-vous ?" + icône carte
/// - Ligne "Lieux enregistrés" avec l'étoile
/// - Liste des adresses avec cercle gris contenant l'icône pin en gris sombre (darkPinGrey),
///   grand titre du quartier, sous-titre de détail rue et distance en km (sans répétition du titre dans le sous-titre)
/// - Dédoublonnage strict des trajets récents
class DestinationSearchBottomSheet extends StatefulWidget {
  final LatLng? currentUserLocation;
  final String? initialPickup;
  final String? currentAddressDetails;
  final PlacesService? placesService;
  final RideService? rideService;

  const DestinationSearchBottomSheet({
    super.key,
    this.currentUserLocation,
    this.initialPickup,
    this.currentAddressDetails,
    this.placesService,
    this.rideService,
  });

  /// Ouvre le Bottom Sheet de façon fluide et retourne le résultat de recherche
  static Future<DestinationSearchSheetResult?> show(
    BuildContext context, {
    LatLng? currentUserLocation,
    String? initialPickup,
    String? currentAddressDetails,
    PlacesService? placesService,
    RideService? rideService,
  }) {
    return showModalBottomSheet<DestinationSearchSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.shadowCardBlack,
      builder: (ctx) => DestinationSearchBottomSheet(
        currentUserLocation: currentUserLocation,
        initialPickup: initialPickup,
        currentAddressDetails: currentAddressDetails,
        placesService: placesService,
        rideService: rideService,
      ),
    );
  }

  /// Nettoie le sous-titre d'adresse pour ne jamais répéter le grand titre dans le détail
  /// et élimine toute répétition accidentelle de "Dakar, Sénégal"
  static String formatPlaceSubtitle(String title, String rawSubtitle) {
    final cleanTitle = title.trim();
    var cleanSub = rawSubtitle.trim();

    if (cleanSub.isEmpty) return '';

    // Si le sous-titre est strictement identique au titre (insensible à la casse)
    if (cleanSub.toLowerCase() == cleanTitle.toLowerCase()) {
      return '';
    }

    // Si le sous-titre commence par le titre (ex: "Liberté 6 Extension, Rue LIB 42, Dakar")
    if (cleanTitle.length > 5 &&
        cleanSub.toLowerCase().startsWith(cleanTitle.toLowerCase())) {
      cleanSub = cleanSub.substring(cleanTitle.length).trim();
      // Supprimer les virgules, tirets ou espaces au début
      cleanSub = cleanSub.replaceFirst(RegExp(r'^[,;\s\-–—]+'), '').trim();
    }

    // Si après nettoyage le sous-titre est vide ou identique au titre, ne rien forcer en doublon
    if (cleanSub.isEmpty ||
        cleanSub.toLowerCase() == cleanTitle.toLowerCase()) {
      return '';
    }

    // Supprimer toute répétition interne de "Dakar, Sénégal" ou "Dakar, Dakar"
    cleanSub = cleanSub.replaceAll(
      RegExp(r'Dakar,\s*Sénégal,\s*Dakar,\s*Sénégal', caseSensitive: false),
      'Dakar, Sénégal',
    );
    cleanSub = cleanSub.replaceAll(
      RegExp(r'Dakar,\s*Dakar', caseSensitive: false),
      'Dakar',
    );

    return cleanSub;
  }

  /// Retourne le grand titre et le sous-titre d'adresse.
  /// Si le titre contient des détails séparés par des virgules (ex: "Grand Yoff, 2527 Rue DD 98, Dakar"),
  /// le premier segment devient le grand titre et le reste le sous-titre.
  /// Élimine toute duplication de "Dakar, Sénégal" sur la même carte.
  static ({String title, String subtitle}) sanitizePlaceHierarchy(
    String rawLabel,
    String rawAddress,
  ) {
    var title = rawLabel.trim();
    var subtitle = rawAddress.trim();

    // Retirer d'éventuels Plus Codes Google Maps (ex: "Point E / MHJ3+JXC" -> "Point E")
    title = title.replaceAll(RegExp(r'\s*/\s*[A-Z0-9]{4}\+[A-Z0-9]{2,}\b'), '').trim();
    title = title.replaceAll(RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,}\s*'), '').trim();

    // Si le titre contient une virgule et que le sous-titre est vide ou identique au titre
    // (ex: "Point E, Rue PE 24, Dakar" ou "Grand Yoff, 2527 Rue DD 98, Dakar")
    // mais ne pas découper "Dakar, Sénégal" qui est le nom complet ville/pays
    final isDakarSenegalTitle = title.toLowerCase() == 'dakar, sénégal' ||
        title.toLowerCase() == 'dakar, senegal';

    if ((subtitle.isEmpty || subtitle.toLowerCase() == title.toLowerCase()) &&
        title.contains(',') &&
        !isDakarSenegalTitle) {
      final parts = title.split(',');
      title = parts.first.trim();
      subtitle = parts.sublist(1).join(',').trim();
    } else if (subtitle.contains(',') &&
        subtitle.toLowerCase() != 'dakar, sénégal' &&
        subtitle.toLowerCase() != 'dakar, senegal' &&
        (title.isEmpty || subtitle.toLowerCase().startsWith(title.toLowerCase()))) {
      // Si l'adresse complète est dans subtitle
      final parts = subtitle.split(',');
      if (title.isEmpty) {
        title = parts.first.trim();
      }
      subtitle = parts.sublist(1).join(',').trim();
    }

    // Si le titre est vide, utiliser l'adresse ou 'Destination'
    if (title.isEmpty) {
      title = subtitle.isNotEmpty ? subtitle : 'Destination';
      subtitle = '';
    }

    // Si le sous-titre est vide ou identique au titre
    if (subtitle.isEmpty || subtitle.toLowerCase() == title.toLowerCase()) {
      // Si le titre est déjà "Dakar, Sénégal" ou "Dakar", ne pas dupliquer en sous-titre
      if (title.toLowerCase() == 'dakar, sénégal' ||
          title.toLowerCase() == 'dakar, senegal' ||
          title.toLowerCase() == 'dakar') {
        subtitle = '';
      } else {
        // Pour tout quartier ou lieu (ex: "Point E", "Almadies"), afficher la ville en sous-titre
        subtitle = 'Dakar, Sénégal';
      }
    }

    // Nettoyer le sous-titre pour éviter les répétitions avec le titre
    final cleanSub = formatPlaceSubtitle(title, subtitle);

    return (
      title: title,
      subtitle: cleanSub,
    );
  }

  @override
  State<DestinationSearchBottomSheet> createState() =>
      _DestinationSearchBottomSheetState();
}

class _DestinationSearchBottomSheetState
    extends State<DestinationSearchBottomSheet> {
  late final PlacesService _placesService;
  late final RideService _rideService;

  final TextEditingController _departureController = TextEditingController();
  final FocusNode _departureFocusNode = FocusNode();

  final TextEditingController _arrivalController = TextEditingController();
  final FocusNode _arrivalFocusNode = FocusNode();

  PlaceSearchResult? _selectedDeparture;
  bool _isEditingDeparture = false;

  List<RecentSuggestionModel> _recentDestinations = [];
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _placesService = widget.placesService ?? PlacesService();
    _rideService = widget.rideService ?? RideService();

    // 1. Initialiser le point de départ
    final loc = widget.currentUserLocation ?? const LatLng(14.6937, -17.4440);
    final pickup = widget.initialPickup;
    final initialDep = (pickup != null &&
            pickup.trim().isNotEmpty &&
            pickup.trim().toLowerCase() != 'dakar' &&
            pickup.trim().toLowerCase() != 'dakar, sénégal' &&
            pickup.trim().toLowerCase() != 'dakar, senegal')
        ? pickup.trim()
        : PlacesService.getDakarDistrictFallback(loc.latitude, loc.longitude).mainText;
    _departureController.text = initialDep;

    _selectedDeparture = PlaceSearchResult(
      id: 'pickup_initial',
      mainText: initialDep,
      secondaryText: widget.currentAddressDetails ?? '',
      fullAddress: widget.currentAddressDetails != null &&
              widget.currentAddressDetails!.isNotEmpty
          ? '$initialDep, ${widget.currentAddressDetails}'
          : initialDep,
      latitude: loc.latitude,
      longitude: loc.longitude,
      category: 'pickup',
    );

    // 2. Initialisation synchrone des récents avec dédoublonnage strict
    final cached = HomeSuggestionsStorage.cachedSuggestions?.recent;
    _recentDestinations = _deduplicatePlaces(
      cached != null && cached.isNotEmpty ? cached : _defaultDakarPlaces,
    );

    _departureController.addListener(_onDepartureChanged);
    _arrivalController.addListener(_onArrivalChanged);

    _departureFocusNode.addListener(() {
      if (_departureFocusNode.hasFocus && mounted) {
        setState(() {
          _isEditingDeparture = true;
        });
      }
    });

    _arrivalFocusNode.addListener(() {
      if (_arrivalFocusNode.hasFocus && mounted) {
        setState(() {
          _isEditingDeparture = false;
        });
      }
    });

    _loadRecentDestinations();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _departureController.dispose();
    _departureFocusNode.dispose();
    _arrivalController.dispose();
    _arrivalFocusNode.dispose();
    super.dispose();
  }

  /// Dédoublonnage strict par label normalisé pour ne jamais répéter les lieux
  static List<RecentSuggestionModel> _deduplicatePlaces(
    List<RecentSuggestionModel> places,
  ) {
    final seen = <String>{};
    final unique = <RecentSuggestionModel>[];

    for (final item in places) {
      final key = item.label.trim().toLowerCase();
      if (key.isNotEmpty && !seen.contains(key)) {
        seen.add(key);
        unique.add(item);
      }
    }
    return unique;
  }

  void _onDepartureChanged() {
    if (mounted) setState(() {});
    if (!_isEditingDeparture) return;
    final query = _departureController.text.trim();
    _triggerSearch(query);
  }

  void _onArrivalChanged() {
    if (mounted) setState(() {});
    if (_isEditingDeparture) return;
    final query = _arrivalController.text.trim();
    _triggerSearch(query);
  }

  void _triggerSearch(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    final isOnline = await NetworkConnectivityService.isConnected;
    if (!isOnline && mounted) {
      OfflineModalSheet.show(
        context,
        currentPosition: widget.currentUserLocation,
        currentAddress: _departureController.text,
        onRetry: () => _searchPlaces(query),
      );
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final results = await _placesService.autocomplete(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecentDestinations() async {
    // 1. Initialisation depuis le cache mémoire / stockage
    final cached = HomeSuggestionsStorage.cachedSuggestions?.recent;
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _recentDestinations = _deduplicatePlaces(cached);
      });
    } else {
      final local = await RecentTripStorage.getRecentTrips();
      if (local.isNotEmpty && mounted) {
        setState(() {
          _recentDestinations = _deduplicatePlaces(local);
        });
      }
    }

    // 2. Appel serveur en arrière-plan
    try {
      final res = await _rideService.getSuggestions();
      if (res != null && mounted) {
        await HomeSuggestionsStorage.saveSuggestions(res);
        if (res.recent.isNotEmpty) {
          setState(() {
            _recentDestinations = _deduplicatePlaces(res.recent);
          });
        }
      }
    } catch (_) {}

    // 3. Fallback riche avec les lieux de Dakar (sans doublon et sans répétition titre/sous-titre)
    if (_recentDestinations.isEmpty && mounted) {
      setState(() {
        _recentDestinations = _deduplicatePlaces(_defaultDakarPlaces);
      });
    }
  }

  static const List<RecentSuggestionModel> _defaultDakarPlaces = [
    RecentSuggestionModel(
      id: 'rec_liberte_6',
      label: 'Liberté 6 Extension',
      address: 'Rue LIB 42, Dakar',
      lat: 14.7214,
      lng: -17.4619,
    ),
    RecentSuggestionModel(
      id: 'rec_8_ave_place_116',
      label: 'Place 116',
      address: '8 Avenue Place 116, Dakar',
      lat: 14.6980,
      lng: -17.4520,
    ),
    RecentSuggestionModel(
      id: 'rec_2527_rue_dd_98',
      label: 'Grand Yoff',
      address: '2527 Rue DD 98, Dakar',
      lat: 14.7350,
      lng: -17.4480,
    ),
    RecentSuggestionModel(
      id: 'rec_point_e',
      label: 'Point E',
      address: 'Rue PE 24, Dakar',
      lat: 14.6912,
      lng: -17.4589,
    ),
    RecentSuggestionModel(
      id: 'rec_guediawaye',
      label: 'Guédiawaye',
      address: 'Corniche, Région de Dakar',
      lat: 14.7700,
      lng: -17.3900,
    ),
    RecentSuggestionModel(
      id: 'rec_esp',
      label: 'École Supérieure Polytechnique de Dakar',
      address: 'Fann Hock, Dakar',
      lat: 14.6853,
      lng: -17.4682,
    ),
    RecentSuggestionModel(
      id: 'rec_hlm_4',
      label: 'HLM 4',
      address: 'Rue HLM-158, Dakar',
      lat: 14.7081,
      lng: -17.4523,
    ),
    RecentSuggestionModel(
      id: 'rec_police_4',
      label: 'Police 4eme',
      address: 'Rue Mg Aloys Kobes, Médina, Dakar',
      lat: 14.6782,
      lng: -17.4421,
    ),
  ];

  String _calculateDistance(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return '';
    final origin = widget.currentUserLocation ?? const LatLng(14.6937, -17.4440);
    final meters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      lat,
      lng,
    );
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Réinitialise le départ sur la position actuelle de l'utilisateur
  void _resetToCurrentLocation() {
    final loc = widget.currentUserLocation ?? const LatLng(14.6937, -17.4440);
    final pickup = widget.initialPickup;
    final initialDep = (pickup != null &&
            pickup.trim().isNotEmpty &&
            pickup.trim().toLowerCase() != 'dakar' &&
            pickup.trim().toLowerCase() != 'dakar, sénégal' &&
            pickup.trim().toLowerCase() != 'dakar, senegal')
        ? pickup.trim()
        : PlacesService.getDakarDistrictFallback(loc.latitude, loc.longitude).mainText;

    setState(() {
      _departureController.text = initialDep;
      _selectedDeparture = PlaceSearchResult(
        id: 'pickup_current_location',
        mainText: initialDep,
        secondaryText: widget.currentAddressDetails ?? '',
        fullAddress: widget.currentAddressDetails != null &&
                widget.currentAddressDetails!.isNotEmpty
            ? '$initialDep, ${widget.currentAddressDetails}'
            : initialDep,
        latitude: loc.latitude,
        longitude: loc.longitude,
        category: 'pickup',
      );
      _isEditingDeparture = false;
      _suggestions = [];
    });
    _arrivalFocusNode.requestFocus();
  }

  void _onSelectPlace(PlaceSearchResult place) {
    if (_isEditingDeparture) {
      setState(() {
        _selectedDeparture = place;
        _departureController.text = place.mainText;
        _isEditingDeparture = false;
        _suggestions = [];
      });
      _arrivalFocusNode.requestFocus();
    } else {
      _submitSelection(place);
    }
  }

  void _submitSelection(PlaceSearchResult destinationPlace) {
    final dep = _selectedDeparture ??
        PlaceSearchResult(
          id: 'pickup_custom',
          mainText: _departureController.text.trim().isNotEmpty
              ? _departureController.text.trim()
              : 'Rue FN-48, 12',
          secondaryText: widget.currentAddressDetails ?? '',
          fullAddress: _departureController.text.trim().isNotEmpty
              ? _departureController.text.trim()
              : 'Rue FN-48, 12',
          latitude: widget.currentUserLocation?.latitude ?? 14.6937,
          longitude: widget.currentUserLocation?.longitude ?? -17.4440,
          category: 'pickup',
        );

    final result = DestinationSearchSheetResult(
      departure: dep,
      destination: destinationPlace,
    );

    Navigator.of(context).pop(result);
  }

  Future<void> _onSelectRecentItem(RecentSuggestionModel item) async {
    final hierarchy = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
      item.label,
      item.address,
    );
    final place = PlaceSearchResult(
      id: item.id.isNotEmpty ? item.id : 'recent_${item.lat}_${item.lng}',
      mainText: hierarchy.title,
      secondaryText: hierarchy.subtitle,
      fullAddress: item.address.isNotEmpty ? item.address : item.label,
      latitude: item.lat,
      longitude: item.lng,
      category: 'recent',
    );
    _onSelectPlace(place);
  }

  Future<void> _onSelectSuggestionItem(PlaceSuggestion suggestion) async {
    setState(() => _isLoading = true);
    try {
      final details = await _placesService.details(suggestion.placeId);
      final rawTitle = suggestion.mainText ?? suggestion.description;
      final rawSubtitle = suggestion.secondaryText ?? details.address;
      final hierarchy = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
        rawTitle,
        rawSubtitle,
      );

      final place = PlaceSearchResult(
        id: suggestion.placeId,
        mainText: hierarchy.title,
        secondaryText: hierarchy.subtitle,
        fullAddress: details.address,
        latitude: details.lat,
        longitude: details.lng,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        _onSelectPlace(place);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openSelectOnMap() async {
    _arrivalFocusNode.unfocus();
    _departureFocusNode.unfocus();

    final PlaceSearchResult? result =
        await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: SelectOnMapPage(
          isArrival: !_isEditingDeparture,
          initialLocation: _isEditingDeparture
              ? (_selectedDeparture != null
                  ? LatLng(_selectedDeparture!.latitude,
                      _selectedDeparture!.longitude)
                  : widget.currentUserLocation)
              : widget.currentUserLocation,
          placesService: _placesService,
        ),
      ),
    );

    if (result != null && mounted) {
      _onSelectPlace(result);
    }
  }

  Future<void> _openSavedPlaces() async {
    _arrivalFocusNode.unfocus();
    _departureFocusNode.unfocus();

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
      _onSelectPlace(selectedSavedPlace);
    }
  }

  /// Élément pour reprendre la position actuelle en un clic
  Widget _buildCurrentLocationTile() {
    final title = (widget.initialPickup != null &&
            widget.initialPickup!.trim().isNotEmpty)
        ? widget.initialPickup!.trim()
        : 'Votre position actuelle';
    final details = widget.currentAddressDetails?.trim() ?? '';

    // Éviter toute répétition de texte identique (ex: "Dakar, Sénégal • Dakar, Sénégal")
    String displaySubtitle = title;
    if (details.isNotEmpty &&
        details.toLowerCase() != title.toLowerCase() &&
        !title.toLowerCase().contains(details.toLowerCase())) {
      displaySubtitle = '$title, $details';
    }

    return InkWell(
      key: const ValueKey('tile_current_location'),
      onTap: _resetToCurrentLocation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.serviceCardBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: AppColors.nearBlack, // Icône position en noir
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Votre position actuelle',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.nearBlack,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    displaySubtitle,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    // Monte presque jusqu'en haut de la page (~92% de l'écran)
    final sheetHeight = media.size.height * 0.92;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.sheetHandleGrey,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Bloc blanc Départ & Arrivée sans contour avec effet d'ombre portée
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowSoftBlack,
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ligne Départ : icône silhouette passager + TextField modifiable et supprimable
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.hail_rounded,
                          color: AppColors.nearBlack,
                          size: 26,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _departureController,
                            focusNode: _departureFocusNode,
                            autofocus: false,
                            style: GoogleFonts.inter(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.nearBlack,
                              letterSpacing: -0.2,
                            ),
                            cursorColor: AppColors.primary,
                            decoration: InputDecoration(
                              hintText: 'Point de départ',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onTap: () {
                              setState(() {
                                _isEditingDeparture = true;
                              });
                            },
                          ),
                        ),
                        // Quand le départ a du texte : bouton X pour effacer
                        // Quand le départ est vide : icône qui prend ma position en NOIR !
                        if (_departureController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Effacer le point de départ',
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.neutralIconGrey,
                            ),
                            onPressed: () {
                              _departureController.clear();
                              setState(() {
                                _isEditingDeparture = true;
                                _suggestions = [];
                              });
                              _departureFocusNode.requestFocus();
                            },
                          )
                        else
                          IconButton(
                            tooltip: 'Prendre ma position actuelle',
                            icon: const Icon(
                              Icons.my_location_rounded,
                              size: 22,
                              color: AppColors.nearBlack, // Icône en noir
                            ),
                            onPressed: _resetToCurrentLocation,
                          ),
                      ],
                    ),
                  ),

                  // Séparateur horizontal discret
                  const Divider(
                    height: 1,
                    thickness: 0.8,
                    color: AppColors.subtleDivider,
                  ),

                  // Ligne Arrivée : icône flag orange directe (sans boîte orange) + TextField + icône carte
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/flag-svgrepo-com.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                            AppColors.flagRedOrange,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _arrivalController,
                            focusNode: _arrivalFocusNode,
                            autofocus: false,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.nearBlack,
                              letterSpacing: -0.2,
                            ),
                            cursorColor: AppColors.primary,
                            decoration: InputDecoration(
                              hintText: 'Où allez-vous ?',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onTap: () {
                              setState(() {
                                _isEditingDeparture = false;
                              });
                            },
                          ),
                        ),
                        if (_arrivalController.text.isNotEmpty)
                          IconButton(
                            tooltip: "Effacer l'arrivée",
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.neutralIconGrey,
                            ),
                            onPressed: () {
                              _arrivalController.clear();
                              setState(() {
                                _isEditingDeparture = false;
                                _suggestions = [];
                              });
                              _arrivalFocusNode.requestFocus();
                            },
                          ),
                        // Icône Carte
                        IconButton(
                          tooltip: 'Choisir sur la carte',
                          icon: const Icon(
                            Icons.map_outlined,
                            size: 23,
                            color: AppColors.nearBlack,
                          ),
                          onPressed: _openSelectOnMap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Ligne "Lieux enregistrés" avec l'étoile
          InkWell(
            onTap: _openSavedPlaces,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: AppColors.amberHighlightText,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Lieux enregistrés',
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.nearBlack,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          const Divider(
            height: 1,
            thickness: 0.8,
            color: AppColors.subtleDivider,
          ),

          // Indicateur de chargement
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

          // Liste des suggestions en direct ou des adresses récentes
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: _suggestions.isNotEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _suggestions.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 72,
                        thickness: 0.8,
                        color: AppColors.subtleDivider,
                      ),
                      itemBuilder: (context, index) {
                        final item = _suggestions[index];
                        final rawTitle = item.mainText ?? item.description;
                        final rawSubtitle =
                            item.secondaryText ?? '';
                        final hierarchy =
                            DestinationSearchBottomSheet.sanitizePlaceHierarchy(
                          rawTitle,
                          rawSubtitle,
                        );
                        final title = hierarchy.title;
                        final subtitle = hierarchy.subtitle;

                        return InkWell(
                          onTap: () => _onSelectSuggestionItem(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Cercle gris avec icône pin de localisation en gris sombre
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: AppColors.serviceCardBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.darkPinGrey,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Grand titre : Quartier / nom du lieu
                                      Text(
                                        title,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.nearBlack,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        // Sous-titre : Détail sans répétition du titre
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
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _isEditingDeparture &&
                              _departureController.text.isEmpty
                          ? _recentDestinations.length + 1
                          : _recentDestinations.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 72,
                        thickness: 0.8,
                        color: AppColors.subtleDivider,
                      ),
                      itemBuilder: (context, index) {
                        // Si le point de départ a été effacé : afficher la tuile "Votre position actuelle" en premier
                        if (_isEditingDeparture &&
                            _departureController.text.isEmpty) {
                          if (index == 0) {
                            return _buildCurrentLocationTile();
                          }
                          index = index - 1;
                        }

                        final item = _recentDestinations[index];
                        final distance =
                            _calculateDistance(item.lat, item.lng);
                        final hierarchy =
                            DestinationSearchBottomSheet.sanitizePlaceHierarchy(
                          item.label,
                          item.address,
                        );
                        final title = hierarchy.title;
                        final subtitle = hierarchy.subtitle;

                        return InkWell(
                          onTap: () => _onSelectRecentItem(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Cercle gris avec icône pin de localisation en gris sombre
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: AppColors.serviceCardBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.darkPinGrey,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Grand titre : Quartier / nom du lieu
                                      Text(
                                        title,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.nearBlack,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        // Sous-titre : Détail sans répétition du titre
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
                                    ],
                                  ),
                                ),
                                if (distance.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    distance,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
