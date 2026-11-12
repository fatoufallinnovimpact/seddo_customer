import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';

import '../../data/models/transit/PlaceModel.dart';
import '../widgets/PlaceSearchWidget.dart';
import 'RouteTimelinePage.dart';

/// Public Transport (TCU) page - Design transit-sdo avec sélection date/heure et bouton rechercher.
class PublicTransportPage extends StatefulWidget {
  final String initialOrigin;
  final String initialDestination;
  final LatLng? initialOriginLocation;
  final bool autoSearch;

  const PublicTransportPage({
    super.key,
    this.initialOrigin = '',
    this.initialDestination = '',
    this.initialOriginLocation,
    this.autoSearch = false,
  });

  @override
  State<PublicTransportPage> createState() => _PublicTransportPageState();
}

typedef TransportCommun = PublicTransportPage;

class _PublicTransportPageState extends State<PublicTransportPage> {
  PlaceModel? origine;
  PlaceModel? destination;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _hasSearched = false;
  bool _busesLoaded = false;
  bool _showSeddoCard = true;
  Key _searchKey = UniqueKey();

  @override
  void initState() {
    super.initState();

    // Initial GPS resolution for origin
    if (widget.initialOriginLocation != null) {
      final name = widget.initialOrigin.isNotEmpty
          ? widget.initialOrigin
          : 'Ma position actuelle';
      origine = PlaceModel(
        latitude: widget.initialOriginLocation!.latitude,
        longitude: widget.initialOriginLocation!.longitude,
        name: name,
        address: name,
      );
    } else if (widget.initialOrigin.isNotEmpty &&
        widget.initialOrigin != 'Ma position actuelle') {
      origine = PlaceModel(
        latitude: 14.6937949,
        longitude: -17.4914255,
        name: widget.initialOrigin,
        address: widget.initialOrigin,
      );
      _initCurrentLocation(fallbackName: widget.initialOrigin);
    } else {
      _initCurrentLocation(fallbackName: widget.initialOrigin);
    }

    if (widget.initialDestination.isNotEmpty) {
      destination = PlaceModel(
        latitude: 14.7115399,
        longitude: -17.47601,
        name: widget.initialDestination,
        address: widget.initialDestination,
      );
      if (widget.autoSearch) {
        _hasSearched = true;
      }
    }
  }

  Future<void> _initCurrentLocation({String? fallbackName}) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        setState(() {
          final name = (fallbackName != null && fallbackName.isNotEmpty)
              ? fallbackName
              : (origine?.name.isNotEmpty == true
                  ? origine!.name
                  : 'Ma position actuelle');
          origine = PlaceModel(
            latitude: pos.latitude,
            longitude: pos.longitude,
            name: name,
            address: name,
          );
        });
      }
    } catch (_) {
      if (mounted && origine == null) {
        final name = (fallbackName != null && fallbackName.isNotEmpty)
            ? fallbackName
            : 'Ma position actuelle';
        setState(() {
          origine = PlaceModel(
            latitude: 14.6937949,
            longitude: -17.4914255,
            name: name,
            address: name,
          );
        });
      }
    }
  }

  String get _formattedDate {
    final d = _selectedDate.day.toString().padLeft(2, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final y = _selectedDate.year.toString();
    return '$d-$m-$y';
  }

  String get _apiFormattedDate {
    final d = _selectedDate.day.toString().padLeft(2, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final y = _selectedDate.year.toString();
    return '$y$m$d'; // Format YYYYMMDD attendu par l'API find-bus
  }

  String get _formattedTime {
    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get _apiFormattedTime {
    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    return '$h:$m:00'; // Format HH:mm:ss attendu par l'API find-bus
  }

  Future<void> _openDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _openTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _onSearchPressed() {
    FocusScope.of(context).unfocus();
    if (destination == null || destination!.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un lieu de destination.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF0D47A1),
        ),
      );
      return;
    }
    setState(() {
      _hasSearched = true;
      _busesLoaded = false;
      _searchKey = UniqueKey();
    });
  }

  void _swapOriginAndDestination() {
    if (origine != null && destination != null) {
      final PlaceModel backup = origine!;
      setState(() {
        origine = destination;
        destination = backup;
        if (_hasSearched) {
          _busesLoaded = false;
          _searchKey = UniqueKey();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: [
            // 1. En-tête : Flèche retour + Titre (sans aucun menu en haut à droite)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.black, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      "Où allons-nous ?",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Card : Origine, Destination, Bouton Swap + Ligne Date, Heure et Rechercher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Champ Origine
                        PlaceSearchWidget(
                          key: const Key("tcu_origin_search"),
                          initPlace: origine,
                          icon: const Icon(
                            Icons.my_location_rounded,
                            color: Color(0xFF0D47A1),
                            size: 20,
                          ),
                          label: "Origine",
                          onLocationSelected: (PlaceModel location) {
                            setState(() {
                              origine = location;
                            });
                          },
                        ),
                        const SizedBox(height: 10),

                        // Champ Destination
                        PlaceSearchWidget(
                          key: const Key("tcu_destination_search"),
                          initPlace: destination,
                          icon: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFF52D56),
                            size: 22,
                          ),
                          label: "Destination",
                          onLocationSelected: (PlaceModel location) {
                            setState(() {
                              destination = location;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Ligne : Date, Heure & Bouton Rechercher
                        Row(
                          children: [
                            // Sélecteur de Date
                            Expanded(
                              flex: 4,
                              child: InkWell(
                                onTap: _openDatePicker,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.grey.shade300),
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.calendar_month,
                                            size: 16,
                                            color: Color(0xFF0D47A1),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formattedDate,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Sélecteur d'Heure
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: _openTimePicker,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.grey.shade300),
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: Color(0xFF0D47A1),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formattedTime,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Bouton Rechercher (Orange Dakar)
                            Expanded(
                              flex: 4,
                              child: InkWell(
                                key: const Key('tcu_search_button'),
                                onTap: _onSearchPressed,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD95C18),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD95C18)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search,
                                              size: 16, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text(
                                            'Rechercher',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bouton d'inversion des adresses (switch)
                  Positioned(
                    top: 35,
                    right: 28,
                    child: InkWell(
                      onTap: _swapOriginAndDestination,
                      child: SvgPicture.asset(
                        "assets/transit/switch.svg",
                        width: 36,
                        height: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Corps : Résultats de l'itinéraire
            if (_hasSearched && destination != null)
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.only(top: 8),
                child: RouteTimelinePage(
                  key: _searchKey,
                  toPlaceDetails: destination,
                  fromPlaceDetails: origine,
                  date: _apiFormattedDate,
                  time: _apiFormattedTime,
                  physics: const NeverScrollableScrollPhysics(),
                  onRoutesLoaded: () {
                    if (mounted && !_busesLoaded) {
                      setState(() {
                        _busesLoaded = true;
                      });
                    }
                  },
                ),
              ),

            // Espace en bas pour ne pas que le contenu soit masqué par la carte flottante
            SizedBox(
              height: (_showSeddoCard && _hasSearched && _busesLoaded) ? 90 : 24,
            ),
          ],
        ),
      ),

      // Floating Seddo VTC card at bottom (visible uniquement après chargement des bus)
      // Dismissible horizontally (glisser de gauche à droite ou droite à gauche pour faire disparaître)
      if (_showSeddoCard && _hasSearched && _busesLoaded)
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Dismissible(
            key: const Key('tcu_seddo_card_dismissible'),
            direction: DismissDirection.horizontal,
            onDismissed: (_) {
              setState(() {
                _showSeddoCard = false;
              });
            },
            child: _buildFloatingSeddoCard(),
          ),
        ),
          ],
        ),
        ),
      ),
    );
  }

  void _openSeddoRideSearch() {
    final pickupName = (origine?.name.isNotEmpty == true)
        ? origine!.name
        : 'Ma position actuelle';
    final pickupAddress = (origine?.address.isNotEmpty == true)
        ? origine!.address
        : pickupName;
    final pickupLat = (origine != null && origine!.latitude != 0)
        ? origine!.latitude
        : 14.6937949;
    final pickupLng = (origine != null && origine!.longitude != 0)
        ? origine!.longitude
        : -17.4914255;

    final depResult = PlaceSearchResult(
      id: 'tcu_pickup',
      mainText: pickupName,
      secondaryText: pickupAddress,
      fullAddress: pickupAddress,
      latitude: pickupLat,
      longitude: pickupLng,
      category: 'pickup',
    );

    PlaceSearchResult? destResult;
    if (destination != null && destination!.name.isNotEmpty) {
      final destName = destination!.name;
      final destAddress = destination!.address.isNotEmpty
          ? destination!.address
          : destName;
      final destLat = destination!.latitude;
      final destLng = destination!.longitude;

      destResult = PlaceSearchResult(
        id: 'tcu_destination',
        mainText: destName,
        secondaryText: destAddress,
        fullAddress: destAddress,
        latitude: destLat,
        longitude: destLng,
      );
    }

    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: PlaceSearchPage(
          initialPickup: pickupName,
          initialDestination: destResult?.mainText ?? destination?.name ?? '',
          initialDepartureResult: depResult,
          initialDestinationResult: destResult,
          currentUserLocation: LatLng(pickupLat, pickupLng),
        ),
      ),
    );
  }

  /// Floating dark Seddo VTC card inciting the user to order a Seddo car.
  /// Stays visible floating over the page after bus routes have loaded, dismissible with ✕ button or horizontal swipe.
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
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
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
                // Car icon
                const Icon(
                  Icons.directions_car_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),

                // Text: "En Seddo : 19 min, porte à porte" on a single line, fully white
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'En Seddo : 19 min, porte à porte',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Orange "Commander" button
                ElevatedButton(
                  key: const Key('tcu_seddo_commander_button'),
                  onPressed: _openSeddoRideSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: AppConstants.elevationNone,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Commander',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 20), // Space for close button
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
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF444444), width: 1),
                ),
                child: const Icon(
                  Icons.close,
                  size: 11,
                  color: Color(0xFFCCCCCC),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
