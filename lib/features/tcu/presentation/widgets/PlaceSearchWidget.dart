import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/transit/PlaceModel.dart';
import '../../data/services/transit_place_search_service.dart';

class PlaceSearchWidget extends StatefulWidget {
  final Function(PlaceModel) onLocationSelected;
  final String label;
  final Icon icon;
  final PlaceModel? initPlace;
  final FocusNode? focusNode;
  final String? apiKey;

  const PlaceSearchWidget({
    super.key,
    required this.onLocationSelected,
    required this.label,
    required this.icon,
    this.initPlace,
    this.focusNode,
    this.apiKey,
  });

  @override
  State<PlaceSearchWidget> createState() => _PlaceSearchWidgetState();
}

class _PlaceSearchWidgetState extends State<PlaceSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final TransitPlaceSearchService _searchService = TransitPlaceSearchService();
  bool positionLoader = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusOrTextChanged);
    _controller.addListener(_onFocusOrTextChanged);

    if (widget.initPlace != null) {
      _controller.text = widget.initPlace!.name;
    }
  }

  void _onFocusOrTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PlaceSearchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initPlace != oldWidget.initPlace) {
      final newText = widget.initPlace?.name ?? '';
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusOrTextChanged);
    _controller.removeListener(_onFocusOrTextChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    try {
      setState(() {
        positionLoader = true;
      });
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final place = await _searchService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      _controller.text = place.name;
      widget.onLocationSelected(place);
      _focusNode.unfocus();
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          positionLoader = false;
        });
      }
    }
  }

  Future<List<PlaceModel>> _fetchSuggestions(String query) async {
    final clean = query.trim();
    final results = await _searchService.search(clean);
    return [
      PlaceModel(
        name: 'Ma position actuelle',
        address: 'Utiliser votre position GPS en direct',
        latitude: 0,
        longitude: 0,
      ),
      ...results,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isOrigin = widget.label.toLowerCase().contains('origine');

    return TypeAheadField<PlaceModel>(
      controller: _controller,
      suggestionsCallback: _fetchSuggestions,
      decorationBuilder: (context, child) {
        return Material(
          type: MaterialType.card,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          shadowColor: Colors.black26,
          child: child,
        );
      },
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          cursorColor: const Color(0xFF0D47A1),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black, // Noir pur et parfaitement net
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
            floatingLabelStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D47A1),
            ),
            hintText: isOrigin
                ? 'D\'où partez-vous ? (ex: Ma position, Plateau...)'
                : 'Où allez-vous ? (ex: Almadies, Petersen, Ouakam...)',
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade400,
            ),
            prefixIcon: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: isOrigin ? _useCurrentLocation : null,
              child: Tooltip(
                message: isOrigin ? 'Utiliser ma position actuelle' : widget.label,
                child: positionLoader
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      )
                    : widget.icon,
              ),
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      size: 20,
                      color: Color(0xFF757575),
                    ),
                    splashRadius: 18,
                    tooltip: 'Effacer',
                    onPressed: () {
                      _controller.clear();
                      widget.onLocationSelected(
                        PlaceModel(
                          name: '',
                          address: '',
                          latitude: 0,
                          longitude: 0,
                        ),
                      );
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white, // Blanc net pour éviter l'aspect grisé
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
          ),
          onSubmitted: (value) async {
            final clean = value.trim();
            if (clean.isNotEmpty) {
              final results = await _searchService.search(clean);
              if (results.isNotEmpty) {
                final match = results.first;
                _controller.text = match.name;
                widget.onLocationSelected(match);
              } else {
                widget.onLocationSelected(
                  PlaceModel(
                    name: clean,
                    address: clean,
                    latitude: 14.6937,
                    longitude: -17.444,
                  ),
                );
              }
            }
          },
        );
      },
      itemBuilder: (context, suggestion) {
        final isCurrentLocation =
            suggestion.address == 'Utiliser votre position GPS en direct';
        return ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (isCurrentLocation
                      ? const Color(0xFFD95C18)
                      : const Color(0xFF0D47A1))
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCurrentLocation
                  ? Icons.my_location_rounded
                  : Icons.location_on_rounded,
              color: isCurrentLocation
                  ? const Color(0xFFD95C18)
                  : const Color(0xFF0D47A1),
              size: 18,
            ),
          ),
          title: Text(
            suggestion.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isCurrentLocation
                  ? const Color(0xFFD95C18)
                  : Colors.black, // Haute lisibilité
            ),
          ),
          subtitle: Text(
            suggestion.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        );
      },
      onSelected: (suggestion) async {
        if (suggestion.address == 'Utiliser votre position GPS en direct') {
          await _useCurrentLocation();
        } else {
          _controller.text = suggestion.name;
          widget.onLocationSelected(suggestion);
          _focusNode.unfocus();
        }
      },
      emptyBuilder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Aucun résultat trouvé',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            positionLoader
                ? const CircularProgressIndicator()
                : TextButton.icon(
                    onPressed: _useCurrentLocation,
                    icon: const Icon(Icons.my_location,
                        color: Color(0xFF0D47A1)),
                    label: const Text(
                      'Utiliser ma position actuelle',
                      style: TextStyle(color: Color(0xFF0D47A1)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
