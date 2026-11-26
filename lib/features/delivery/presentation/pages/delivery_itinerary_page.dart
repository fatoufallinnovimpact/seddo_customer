import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/core/utils/map_config.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_destination_search_modal.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/pickup_map_location_picker_page.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/services/app_params_service.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/services/route_service.dart';

/// Résultat retourné après modification de l'itinéraire
class DeliveryItineraryResult {
  final String pickupAddress;
  final LatLng pickupLocation;
  final String destinationAddress;
  final LatLng destinationLocation;

  const DeliveryItineraryResult({
    required this.pickupAddress,
    required this.pickupLocation,
    required this.destinationAddress,
    required this.destinationLocation,
  });
}

/// Page / Affichage plein écran de l'Itinéraire de livraison (conforme à la capture Yango/Seddo) :
/// - Carte Google Map en fond avec tracé vert de l'itinéraire
/// - Marqueur de départ : boîte colis noire (squircle)
/// - Marqueur de destination : badge blanc "1"
/// - Bouton retour en haut à gauche
/// - Bouton de recentrage en bas à droite
/// - Modal inférieur "Itinéraire" avec poignées burger pour modifier chaque adresse et bouton Terminer
class DeliveryItineraryPage extends StatefulWidget {
  final LatLng pickupLocation;
  final String pickupAddress;
  final LatLng destinationLocation;
  final String destinationAddress;
  final PlacesService? placesService;

  const DeliveryItineraryPage({
    super.key,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.destinationLocation,
    required this.destinationAddress,
    this.placesService,
  });

  static Future<DeliveryItineraryResult?> show(
    BuildContext context, {
    required LatLng pickupLocation,
    required String pickupAddress,
    required LatLng destinationLocation,
    required String destinationAddress,
    PlacesService? placesService,
  }) {
    return Navigator.of(context).push<DeliveryItineraryResult>(
      MaterialPageRoute(
        builder: (ctx) => DeliveryItineraryPage(
          pickupLocation: pickupLocation,
          pickupAddress: pickupAddress,
          destinationLocation: destinationLocation,
          destinationAddress: destinationAddress,
          placesService: placesService,
        ),
      ),
    );
  }

  @override
  State<DeliveryItineraryPage> createState() => _DeliveryItineraryPageState();
}

class _DeliveryItineraryPageState extends State<DeliveryItineraryPage> {
  GoogleMapController? _mapController;
  late PlacesService _placesService;
  late final RouteService _routeService;

  late LatLng _pickupLocation;
  late String _pickupAddress;
  late LatLng _destinationLocation;
  late String _destinationAddress;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _destinationMarkerIcon;

  @override
  void initState() {
    super.initState();
    AppParamsService().initParams();
    _placesService = widget.placesService ?? PlacesService();
    _routeService = RouteService();

    _pickupLocation = widget.pickupLocation;
    _pickupAddress = widget.pickupAddress;
    _destinationLocation = widget.destinationLocation;
    _destinationAddress = widget.destinationAddress;

    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final pickupIcon = await MapMarkerHelper.getDeliveryRoutePickupMarker();
      final destIcon =
          await MapMarkerHelper.getDeliveryRouteDestinationMarker(stopNumber: 1);

      if (mounted) {
        setState(() {
          _pickupMarkerIcon = pickupIcon;
          _destinationMarkerIcon = destIcon;
        });
        _updateMapData();
      }
    } catch (_) {
      try {
        final fallbackPickup = await MapMarkerHelper.getDeparturePinMarker();
        final fallbackDest = await MapMarkerHelper.getDestinationPinMarker();
        if (mounted) {
          setState(() {
            _pickupMarkerIcon = fallbackPickup;
            _destinationMarkerIcon = fallbackDest;
          });
          _updateMapData();
        }
      } catch (_) {}
    }
  }

  Future<void> _updateMapData() async {
    final markers = <Marker>{};

    // Marqueur de départ
    markers.add(
      Marker(
        markerId: const MarkerId('itinerary_pickup_marker'),
        position: _pickupLocation,
        icon: _pickupMarkerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.95),
        infoWindow: InfoWindow(
          title: 'Depuis',
          snippet: _pickupAddress,
        ),
      ),
    );

    // Marqueur de destination
    markers.add(
      Marker(
        markerId: const MarkerId('itinerary_dest_marker'),
        position: _destinationLocation,
        icon: _destinationMarkerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 0.95),
        infoWindow: InfoWindow(
          title: 'Vers',
          snippet: _destinationAddress,
        ),
      ),
    );

    // Tracé de l'itinéraire vert (conforme à la capture)
    List<LatLng> routePoints = [_pickupLocation, _destinationLocation];

    try {
      final routeResult = await _routeService.getRoute(
        origin: _pickupLocation,
        destination: _destinationLocation,
      );
      if (routeResult != null && routeResult.polylinePoints.isNotEmpty) {
        routePoints = routeResult.polylinePoints;
      }
    } catch (_) {}

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('itinerary_polyline'),
        points: routePoints,
        color: const Color(0xFF22C55E), // Vert éclatant conforme à l'image
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(markers);
        _polylines.clear();
        _polylines.addAll(polylines);
      });
      _fitBounds();
    }
  }

  void _fitBounds() {
    if (_mapController == null) return;

    final southWestLat =
        math.min(_pickupLocation.latitude, _destinationLocation.latitude);
    final southWestLng =
        math.min(_pickupLocation.longitude, _destinationLocation.longitude);
    final northEastLat =
        math.max(_pickupLocation.latitude, _destinationLocation.latitude);
    final northEastLng =
        math.max(_pickupLocation.longitude, _destinationLocation.longitude);

    final latSpan = northEastLat - southWestLat;
    final adjustedSouth =
        southWestLat - (latSpan > 0.0001 ? latSpan * 0.45 : 0.005);

    final bounds = LatLngBounds(
      southwest: LatLng(adjustedSouth, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60),
    );
  }

  Future<void> _editPickupAddress() async {
    final result = await DeliveryDestinationSearchModal.show(
      context,
      placesService: _placesService,
      pickupLocation: _pickupLocation,
      isPickup: true,
      title: 'Point de départ',
    );

    if (result != null && mounted) {
      setState(() {
        _pickupLocation = LatLng(result.latitude, result.longitude);
        _pickupAddress = result.mainText.isNotEmpty
            ? result.mainText
            : result.fullAddress;
      });
      _updateMapData();
    }
  }

  Future<void> _editDestinationAddress() async {
    final result = await DeliveryDestinationSearchModal.show(
      context,
      placesService: _placesService,
      pickupLocation: _pickupLocation,
    );

    if (result != null && mounted) {
      setState(() {
        _destinationLocation = LatLng(result.latitude, result.longitude);
        _destinationAddress = result.mainText.isNotEmpty
            ? result.mainText
            : result.fullAddress;
      });
      _updateMapData();
    }
  }

  void _finishAndReturn() {
    Navigator.of(context).pop(
      DeliveryItineraryResult(
        pickupAddress: _pickupAddress,
        pickupLocation: _pickupLocation,
        destinationAddress: _destinationAddress,
        destinationLocation: _destinationLocation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeTop =
        math.max(mediaQuery.padding.top, mediaQuery.viewPadding.top);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Google Map en plein écran (clipped vers le bas pour masquer le logo Google sur Android)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: AppConstants.mapLogoClipOffset,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _pickupLocation,
                zoom: 14.5,
              ),
              padding: EdgeInsets.only(
                top: safeTop + 60,
              ),
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                MapStyleService.applyStyle(ctrl);
                _fitBounds();
              },
              markers: _markers,
              polylines: _polylines,
              zoomControlsEnabled: false,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // 2. Bouton retour en haut à gauche
          Positioned(
            top: safeTop > 0 ? safeTop + 8 : 20,
            left: 16,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.18),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Icon(
                    Icons.arrow_back,
                    color: Color(0xFF0F172A),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // 3. Bouton flottant de recentrage au-dessus du modal
          Positioned(
            bottom: 236,
            right: 16,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.18),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _fitBounds,
                child: const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Icon(
                    Icons.near_me,
                    color: Color(0xFF0F172A),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // 4. Modal inférieur "Itinéraire"
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                mediaQuery.padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Itinéraire',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ligne 1 : Depuis (Départ)
                  InkWell(
                    onTap: _editPickupAddress,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFF0F172A),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Depuis',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _pickupAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: _editPickupAddress,
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.menu,
                                color: Color(0xFF94A3B8),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(
                    height: 14,
                    thickness: 0.8,
                    indent: 50,
                    color: Color(0xFFF1F5F9),
                  ),

                  // Ligne 2 : Vers (Destination)
                  InkWell(
                    onTap: _editDestinationAddress,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '1',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vers',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _destinationAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Bouton croix rouge pour supprimer / changer la destination
                          InkWell(
                            onTap: _editDestinationAddress,
                            child: const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(
                                Icons.cancel,
                                color: Color(0xFFEF4444),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Poignée menu burger
                          InkWell(
                            onTap: _editDestinationAddress,
                            child: const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(
                                Icons.menu,
                                color: Color(0xFF94A3B8),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bouton Terminer
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _finishAndReturn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Terminer',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
