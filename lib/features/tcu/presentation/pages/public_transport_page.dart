import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/transit/PlaceModel.dart';
import '../widgets/PlaceSearchWidget.dart';
import 'RouteTimelinePage.dart';

/// Public Transport (TCU) page - Design transit-sdo avec sélection date/heure et bouton rechercher.
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

typedef TransportCommun = PublicTransportPage;

class _PublicTransportPageState extends State<PublicTransportPage> {
  PlaceModel? origine;
  PlaceModel? destination;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _hasSearched = false;
  Key _searchKey = UniqueKey();

  @override
  void initState() {
    super.initState();

    // Initial GPS resolution for origin
    if (widget.initialOrigin.isNotEmpty &&
        widget.initialOrigin != 'Ma position actuelle') {
      origine = PlaceModel(
        latitude: 14.6937949,
        longitude: -17.4914255,
        name: widget.initialOrigin,
        address: widget.initialOrigin,
      );
    } else {
      _initCurrentLocation();
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

  Future<void> _initCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        setState(() {
          origine ??= PlaceModel(
            latitude: pos.latitude,
            longitude: pos.longitude,
            name: 'Ma position actuelle',
            address: 'Ma position actuelle',
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          origine ??= PlaceModel(
            latitude: 14.6937949,
            longitude: -17.4914255,
            name: 'Ma position actuelle',
            address: 'Dakar',
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
}
