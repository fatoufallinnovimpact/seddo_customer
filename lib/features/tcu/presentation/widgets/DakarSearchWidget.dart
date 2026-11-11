import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/transit/PlaceModel.dart';
import '../../data/services/transit_place_search_service.dart';

class DakarSearchWidget extends StatefulWidget {
  final Function(PlaceModel) onLocationSelected;
  final String label;
  final Icon icon;
  final PlaceModel? initPlace;
  final FocusNode? focusNode;

  const DakarSearchWidget({
    super.key,
    required this.onLocationSelected,
    required this.label,
    required this.icon,
    this.initPlace,
    this.focusNode,
  });

  @override
  State<DakarSearchWidget> createState() => _DakarSearchWidgetState();
}

class _DakarSearchWidgetState extends State<DakarSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final TransitPlaceSearchService _searchService = TransitPlaceSearchService();
  Timer? _debounceTimer;
  final Duration _debounceDelay = const Duration(milliseconds: 300);
  bool positionLoader = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initPlace != null) {
      _controller.text = widget.initPlace!.name;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
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
    return _searchService.search(query);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TypeAheadField<PlaceModel>(
          suggestionsCallback: _fetchSuggestions,
          builder: (context, controller, focusNode) {
            if (!focusNode.hasFocus && _controller.text != controller.text) {
              controller.text = _controller.text;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            }

            return TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: 'Ex: Plateau, Almadies, Sacré-Cœur...',
                prefixIcon: widget.icon,
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          controller.clear();
                          _controller.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (text) {
                _controller.text = text;
                if (_debounceTimer?.isActive ?? false) {
                  _debounceTimer?.cancel();
                }
                _debounceTimer = Timer(_debounceDelay, () {
                  if (mounted) setState(() {});
                });
              },
            );
          },
          itemBuilder: (context, suggestion) {
            return ListTile(
              dense: true,
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF0D47A1),
                  size: 18,
                ),
              ),
              title: Text(
                suggestion.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                suggestion.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            );
          },
          onSelected: (suggestion) {
            _controller.text = suggestion.name;
            widget.onLocationSelected(suggestion);
            _focusNode.unfocus();
          },
          emptyBuilder: (context) => Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
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
                          icon: const Icon(Icons.my_location, color: Color(0xFF0D47A1)),
                          label: const Text(
                            'Utiliser ma position actuelle',
                            style: TextStyle(color: Color(0xFF0D47A1)),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
