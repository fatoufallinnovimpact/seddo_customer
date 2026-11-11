import 'package:flutter/material.dart';
import 'package:seddo/core/maps/seddo_maps.dart';

/// Exemple concret d'intégration dans l'écran de réservation VTC Seddo.
/// Démontre :
/// 1. L'utilisation du widget `AppMapView` unifié (Google ou OpenStreetMap).
/// 2. Le champ `AddressSearchField` avec debounce de 400 ms.
/// 3. Le calcul d'itinéraire automatique (Google Directions ou OSRM).
/// 4. Le badge d'information discret quand OpenStreetMap est actif.
class RideBookingMapExamplePage extends StatefulWidget {
  const RideBookingMapExamplePage({super.key});

  @override
  State<RideBookingMapExamplePage> createState() =>
      _RideBookingMapExamplePageState();
}

class _RideBookingMapExamplePageState extends State<RideBookingMapExamplePage> {
  AppMapController? _mapController;

  final MapLatLng _pickupLocation = const MapLatLng(14.6937, -17.4440); // Plateau
  MapLatLng? _destinationLocation;

  List<MapLatLng> _routePoints = [];
  String _distanceText = '--';
  String _durationText = '--';
  bool _isCalculatingRoute = false;

  final Set<AppMapMarker> _markers = {};

  @override
  void initState() {
    super.initState();
    _updateMarkers();
  }

  void _updateMarkers() {
    _markers.clear();

    // Marqueur Point de Départ (Orange Seddo)
    _markers.add(
      AppMapMarker(
        id: 'pickup_marker',
        position: _pickupLocation,
        widget: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFB5B00),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6),
            ],
          ),
          child: const Center(
            child: Icon(Icons.my_location, color: Colors.white, size: 20),
          ),
        ),
      ),
    );

    // Marqueur Destination (Noir / Drapeau d'arrivée)
    if (_destinationLocation != null) {
      _markers.add(
        AppMapMarker(
          id: 'destination_marker',
          position: _destinationLocation!,
          widget: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6),
              ],
            ),
            child: const Center(
              child: Icon(Icons.flag_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      );
    }
  }

  /// Déclenché quand l'utilisateur choisit une destination dans l'AddressSearchField
  Future<void> _onDestinationSelected(MapPlaceSuggestion suggestion) async {
    setState(() => _isCalculatingRoute = true);

    try {
      double? lat = suggestion.latitude;
      double? lng = suggestion.longitude;

      // Si le fournisseur n'a pas inclus directement la lat/lng, on géocode
      if (lat == null || lng == null) {
        final details = await MapServiceManager.instance.geocode(suggestion.description);
        if (details != null) {
          lat = details.latitude;
          lng = details.longitude;
        }
      }

      if (lat != null && lng != null) {
        final dest = MapLatLng(lat, lng);
        _destinationLocation = dest;
        _updateMarkers();

        // Calcul d'itinéraire unifié (Google Directions ou OSRM selon le provider actif)
        final route = await MapServiceManager.instance.getRoute(_pickupLocation, dest);

        setState(() {
          _routePoints = route.points;
          _distanceText = route.formattedDistance;
          _durationText = route.formattedDuration;
        });

        // Recadrer automatiquement la carte pour afficher le trajet complet
        if (route.points.isNotEmpty) {
          double minLat = _pickupLocation.latitude;
          double maxLat = _pickupLocation.latitude;
          double minLng = _pickupLocation.longitude;
          double maxLng = _pickupLocation.longitude;

          for (final p in route.points) {
            if (p.latitude < minLat) minLat = p.latitude;
            if (p.latitude > maxLat) maxLat = p.latitude;
            if (p.longitude < minLng) minLng = p.longitude;
            if (p.longitude > maxLng) maxLng = p.longitude;
          }

          _mapController?.fitBounds(
            MapLatLng(minLat, minLng),
            MapLatLng(maxLat, maxLng),
            padding: 70,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Vue Cartographique universelle (GoogleMap ou FlutterMap OSM)
          AppMapView(
            initialCenter: _pickupLocation,
            initialZoom: 14.5,
            markers: _markers,
            polylines: {
              if (_routePoints.isNotEmpty)
                AppMapPolyline(
                  id: 'ride_route',
                  points: _routePoints,
                  color: const Color(0xFFFB5B00),
                  width: 5,
                ),
            },
            onMapCreated: (ctrl) => _mapController = ctrl,
          ),

          // 2. Bouton retour en haut à gauche
          Positioned(
            top: 50,
            left: 16,
            child: Material(
              color: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // 3. Panneau de recherche et réservation en bas
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Réserver une course',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Champ de recherche unifié (autocomplétion Google ou Photon/OSM)
                  AddressSearchField(
                    hintText: 'Rechercher votre destination...',
                    biasLocation: _pickupLocation,
                    onSuggestionSelected: _onDestinationSelected,
                  ),

                  if (_isCalculatingRoute) ...[
                    const SizedBox(height: 12),
                    const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],

                  if (_destinationLocation != null && !_isCalculatingRoute) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Distance', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(_distanceText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ],
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          Column(
                            children: [
                              const Text('Durée estimée', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(_durationText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Recherche de chauffeur Seddo en cours...')),
                          );
                        },
                        child: const Text(
                          'Confirmer la commande',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
