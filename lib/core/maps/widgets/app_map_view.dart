import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:seddo/core/maps/manager/map_service_manager.dart';
import 'package:seddo/core/maps/models/map_models.dart';
import 'package:seddo/core/maps/models/map_provider.dart';

/// Contrôleur unifié permettant de piloter la caméra indépendamment du fournisseur sous-jacent.
class AppMapController {
  gmaps.GoogleMapController? _googleController;
  fmap.MapController? _osmController;

  void attachGoogle(gmaps.GoogleMapController controller) {
    _googleController = controller;
  }

  void attachOsm(fmap.MapController controller) {
    _osmController = controller;
  }

  /// Anime la caméra vers une coordonnée GPS cible
  Future<void> animateCamera(MapLatLng target, {double? zoom}) async {
    if (_googleController != null) {
      await _googleController!.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: target.toGoogle(),
            zoom: zoom ?? 15.0,
          ),
        ),
      );
    } else if (_osmController != null) {
      _osmController!.move(
        target.toOsm(),
        zoom ?? _osmController!.camera.zoom,
      );
    }
  }

  /// Ajuste le cadrage pour englober deux bornes GPS (départ / arrivée)
  Future<void> fitBounds(
    MapLatLng southwest,
    MapLatLng northeast, {
    double padding = 60.0,
  }) async {
    if (_googleController != null) {
      await _googleController!.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(
          gmaps.LatLngBounds(
            southwest: southwest.toGoogle(),
            northeast: northeast.toGoogle(),
          ),
          padding,
        ),
      );
    } else if (_osmController != null) {
      final bounds = fmap.LatLngBounds(
        southwest.toOsm(),
        northeast.toOsm(),
      );
      _osmController!.fitCamera(
        fmap.CameraFit.bounds(
          bounds: bounds,
          padding: EdgeInsets.all(padding),
        ),
      );
    }
  }
}

/// Vue cartographique universelle qui instancie GoogleMap ou FlutterMap (OSM)
/// selon l'état du MapServiceManager.
/// RÈGLE ABSOLUE : Si OSM est actif, GoogleMap n'est JAMAIS instancié.
class AppMapView extends StatefulWidget {
  final MapLatLng initialCenter;
  final double initialZoom;
  final Set<AppMapMarker> markers;
  final Set<AppMapPolyline> polylines;
  final void Function(MapLatLng position)? onTap;
  final void Function(MapCameraPosition position)? onCameraMove;
  final void Function(AppMapController controller)? onMapCreated;
  final bool showFallbackBadge;
  final Widget? fallbackBadge;

  const AppMapView({
    super.key,
    required this.initialCenter,
    this.initialZoom = 14.5,
    this.markers = const {},
    this.polylines = const {},
    this.onTap,
    this.onCameraMove,
    this.onMapCreated,
    this.showFallbackBadge = true,
    this.fallbackBadge,
  });

  @override
  State<AppMapView> createState() => _AppMapViewState();
}

class _AppMapViewState extends State<AppMapView> {
  final AppMapController _unifiedController = AppMapController();
  final fmap.MapController _osmInternalController = fmap.MapController();

  // Mémorisation de l'état de caméra pour ne pas perdre la vue lors d'une bascule
  late MapLatLng _currentCenter;
  late double _currentZoom;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialCenter;
    _currentZoom = widget.initialZoom;
    _unifiedController.attachOsm(_osmInternalController);
    widget.onMapCreated?.call(_unifiedController);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MapServiceManager.instance,
      builder: (context, _) {
        final activeProvider = MapServiceManager.instance.activeProvider;
        final isOsm = activeProvider == MapProvider.osm;

        return Stack(
          children: [
            // Construction exclusive du widget correspondant au provider actif
            if (isOsm)
              _buildOsmMap()
            else
              _buildGoogleMap(),

            // Badge discret non bloquant informant du mode secours
            if (isOsm && widget.showFallbackBadge)
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: widget.fallbackBadge ?? _defaultFallbackBadge(),
              ),
          ],
        );
      },
    );
  }

  /// Rendu OpenStreetMap / Leaflet (FlutterMap)
  Widget _buildOsmMap() {
    return fmap.FlutterMap(
      mapController: _osmInternalController,
      options: fmap.MapOptions(
        initialCenter: _currentCenter.toOsm(),
        initialZoom: _currentZoom,
        onTap: (tapPosition, point) {
          final latLng = MapLatLng.fromOsm(point);
          _currentCenter = latLng;
          widget.onTap?.call(latLng);
        },
        onPositionChanged: (camera, hasGesture) {
          _currentCenter = MapLatLng.fromOsm(camera.center);
          _currentZoom = camera.zoom;
          widget.onCameraMove?.call(
            MapCameraPosition(
              target: _currentCenter,
              zoom: _currentZoom,
            ),
          );
        },
      ),
      children: [
        // Tuiles OpenStreetMap standards libres et gratuites
        fmap.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'sn.innov.seddo',
          maxZoom: 19,
        ),

        // Tracé de l'itinéraire
        if (widget.polylines.isNotEmpty)
          fmap.PolylineLayer(
            polylines: widget.polylines.map((p) {
              return fmap.Polyline(
                points: p.points.map((pt) => pt.toOsm()).toList(),
                color: p.color,
                strokeWidth: p.width.toDouble(),
              );
            }).toList(),
          ),

        // Marqueurs de position
        if (widget.markers.isNotEmpty)
          fmap.MarkerLayer(
            markers: widget.markers.map((m) {
              return fmap.Marker(
                point: m.position.toOsm(),
                width: m.width,
                height: m.height,
                alignment: m.anchor,
                child: GestureDetector(
                  onTap: m.onTap,
                  child: m.widget ??
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFFB5B00),
                        size: 36,
                      ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  /// Rendu Google Maps officiel
  Widget _buildGoogleMap() {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _currentCenter.toGoogle(),
        zoom: _currentZoom,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _unifiedController.attachGoogle(controller);
      },
      onTap: (latLng) {
        final pos = MapLatLng.fromGoogle(latLng);
        _currentCenter = pos;
        widget.onTap?.call(pos);
      },
      onCameraMove: (pos) {
        _currentCenter = MapLatLng.fromGoogle(pos.target);
        _currentZoom = pos.zoom;
        widget.onCameraMove?.call(
          MapCameraPosition(
            target: _currentCenter,
            zoom: _currentZoom,
            bearing: pos.bearing,
            tilt: pos.tilt,
          ),
        );
      },
      markers: widget.markers.map((m) {
        return gmaps.Marker(
          markerId: gmaps.MarkerId(m.id),
          position: m.position.toGoogle(),
          icon: m.googleIcon ?? gmaps.BitmapDescriptor.defaultMarker,
          onTap: m.onTap,
          anchor: const Offset(0.5, 0.5),
        );
      }).toSet(),
      polylines: widget.polylines.map((p) {
        return gmaps.Polyline(
          polylineId: gmaps.PolylineId(p.id),
          points: p.points.map((pt) => pt.toGoogle()).toList(),
          color: p.color,
          width: p.width,
        );
      }).toSet(),
    );
  }

  /// Badge discret informant l'utilisateur du mode secours
  Widget _defaultFallbackBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFFBBF24),
            size: 15,
          ),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Mode secours – estimation approximative',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
