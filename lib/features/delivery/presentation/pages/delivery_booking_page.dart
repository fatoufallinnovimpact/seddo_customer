import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/map_config.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_destination_search_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_info_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_order_form_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_vehicle_details_sheet.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/pickup_map_location_picker_page.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/home/presentation/widgets/seddo_map_picker_pin.dart';
import 'package:seddo/features/payment/data/services/payment_methods_service.dart';
import 'package:seddo/features/payment/presentation/widgets/payment_method_modal.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/places_service.dart';

enum DeliveryCameraMode {
  tripOverview,
  destination,
  departure,
}

/// Page de réservation de livraison de colis (ENVOYER UN COLIS)
/// Conforme aux spécifications :
/// - Carte interactive avec marqueur signature de prise en charge animé (SeddoMapPickerPin)
/// - Modal coulissant "ENVOYER UN COLIS" avec hauteur par défaut ajustée pour que le bouton "Accéder au formulaire" soit bien visible
/// - Bouton circulaire blanc flottant directement AU-DESSUS du modal :
///   * Avant destination : flèche noire de navigation / recentrage GPS
///   * Après destination : cycle interactif (point de départ, drapeau destination, trajet overview) identique aux courses Seddo
/// - Glissement vers le haut du modal révélant dynamiquement la page détail :
///   * Plus on remonte le modal, plus l'illustration (express.png ou cargo.png) apparaît et grandit progressivement jusqu'à sa taille de base
///   * Affichage des détails (titre Livraison, tarif, cartes sans contours, À savoir, en-tête sécurisé tout en haut)
class DeliveryBookingPage extends StatefulWidget {
  final String? initialOrigin;
  final LatLng? initialOriginLocation;
  final PlacesService? placesService;

  const DeliveryBookingPage({
    super.key,
    this.initialOrigin,
    this.initialOriginLocation,
    this.placesService,
  });

  @override
  State<DeliveryBookingPage> createState() => _DeliveryBookingPageState();
}

class _DeliveryBookingPageState extends State<DeliveryBookingPage> {
  GoogleMapController? _mapController;
  late PlacesService _placesService;

  late LatLng _pickupLocation;
  late String _pickupAddress;

  LatLng? _destinationLocation;
  String? _destinationAddress;

  // Options de livraison : 'moto' ou 'cargo'
  String _selectedDeliveryType = 'moto';

  // Tarifs estimés de base (en FCFA)
  final int _motoPrice = 500;
  final int _cargoPrice = 2600;

  // Marqueurs carte (utilisés quand la destination est sélectionnée)
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _destinationFlagIcon;

  // Suivi de l'animation et du déplacement de la carte
  LatLng? _currentCameraCenter;
  bool _isMapMoving = false;
  Timer? _geocodeDebounceTimer;

  // Contrôleur du bottom sheet coulissant
  late final DraggableScrollableController _sheetController;
  double _currentSheetSize = 0.55;

  // Mode de la caméra pour le bouton au-dessus du modal (identique aux courses Seddo)
  DeliveryCameraMode _cameraMode = DeliveryCameraMode.tripOverview;

  @override
  void initState() {
    super.initState();
    _placesService = widget.placesService ?? PlacesService();

    _pickupLocation = widget.initialOriginLocation ??
        const LatLng(MapConfig.dakarCenterLat, MapConfig.dakarCenterLng);
    _pickupAddress = widget.initialOrigin?.isNotEmpty == true
        ? widget.initialOrigin!
        : 'Position actuelle';

    _sheetController = DraggableScrollableController();
    _sheetController.addListener(_onSheetSizeChanged);

    _loadMarkerIcons();
  }

  void _onSheetSizeChanged() {
    if (_sheetController.isAttached) {
      final size = _sheetController.size;
      if ((size - _currentSheetSize).abs() > 0.005) {
        setState(() {
          _currentSheetSize = size;
        });
      }
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    _geocodeDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final pickupIcon = await MapMarkerHelper.getDeliveryPickupMarker(
        eta: '~9 min',
      );
      final flagIcon = await MapMarkerHelper.getSvgDestinationFlagMarker();

      if (mounted) {
        setState(() {
          _pickupMarkerIcon = pickupIcon;
          _destinationFlagIcon = flagIcon;
        });
        _updateMapMarkers();
      }
    } catch (_) {
      try {
        final fallbackPickup = await MapMarkerHelper.getDeparturePinMarker();
        final fallbackFlag = await MapMarkerHelper.getDestinationPinMarker();
        if (mounted) {
          setState(() {
            _pickupMarkerIcon = fallbackPickup;
            _destinationFlagIcon = fallbackFlag;
          });
          _updateMapMarkers();
        }
      } catch (_) {}
    }
  }

  void _updateMapMarkers() {
    final newMarkers = <Marker>{};

    if (_destinationLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('delivery_pickup_marker'),
          position: _pickupLocation,
          icon: _pickupMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: 'Prise en charge',
            snippet: _pickupAddress,
          ),
        ),
      );

      newMarkers.add(
        Marker(
          markerId: const MarkerId('delivery_destination_marker'),
          position: _destinationLocation!,
          icon: _destinationFlagIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: 'Adresse de livraison',
            snippet: _destinationAddress ?? '',
          ),
        ),
      );

      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route_line'),
          points: [_pickupLocation, _destinationLocation!],
          color: AppColors.primary,
          width: 4,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );

      _fitMapToBounds();
    } else {
      _polylines.clear();
    }

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
  }

  Future<void> _updatePickupLocation(LatLng newPos) async {
    setState(() {
      _pickupLocation = newPos;
    });
    _updateMapMarkers();

    _geocodeDebounceTimer?.cancel();
    _geocodeDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final result = await _placesService.reverseGeocode(
          newPos.latitude,
          newPos.longitude,
        );
        if (result != null && mounted) {
          setState(() {
            _pickupAddress = result.mainText.isNotEmpty
                ? result.mainText
                : result.fullAddress;
          });
          _updateMapMarkers();
        }
      } catch (_) {}
    });
  }

  void _fitMapToBounds() {
    if (_destinationLocation == null || _mapController == null) return;

    final south = math.min(_pickupLocation.latitude, _destinationLocation!.latitude);
    final north = math.max(_pickupLocation.latitude, _destinationLocation!.latitude);
    final west = math.min(_pickupLocation.longitude, _destinationLocation!.longitude);
    final east = math.max(_pickupLocation.longitude, _destinationLocation!.longitude);

    final bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  Future<void> _recenterOnUser() async {
    try {
      final currentPos = await _placesService.getCurrentCoordinates();
      if (currentPos != null && mounted) {
        await _updatePickupLocation(currentPos);
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentPos, zoom: 16.5),
          ),
        );
      } else {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _pickupLocation, zoom: 16.5),
          ),
        );
      }
    } catch (_) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _pickupLocation, zoom: 16.5),
        ),
      );
    }
  }

  /// Gestion du bouton flottant circulaire au-dessus du modal (identique aux courses Seddo)
  void _onFloatingCircularButtonTap() {
    if (_destinationLocation == null) {
      _recenterOnUser();
      return;
    }

    final nextMode = switch (_cameraMode) {
      DeliveryCameraMode.tripOverview => DeliveryCameraMode.destination,
      DeliveryCameraMode.destination => DeliveryCameraMode.departure,
      DeliveryCameraMode.departure => DeliveryCameraMode.tripOverview,
    };

    setState(() {
      _cameraMode = nextMode;
    });

    final controller = _mapController;
    if (controller == null) return;

    switch (nextMode) {
      case DeliveryCameraMode.destination:
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _destinationLocation!, zoom: 16.5),
          ),
        );
        break;
      case DeliveryCameraMode.departure:
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _pickupLocation, zoom: 16.5),
          ),
        );
        break;
      case DeliveryCameraMode.tripOverview:
        _fitMapToBounds();
        break;
    }
  }

  Widget _buildFloatingCircularIcon() {
    if (_destinationLocation == null) {
      // Pas de destination : flèche noire de navigation / recentrage GPS
      return const Icon(
        Icons.navigation_rounded,
        color: Color(0xFF1E1E1E),
        size: 22,
      );
    }

    switch (_cameraMode) {
      case DeliveryCameraMode.tripOverview:
        // Affiche la vue globale -> le bouton propose d'aller à la destination (flag)
        return SvgPicture.asset(
          'assets/icons/flag-svgrepo-com.svg',
          width: 22,
          height: 22,
          colorFilter: const ColorFilter.mode(
            Color(0xFF1E1E1E),
            BlendMode.srcIn,
          ),
        );
      case DeliveryCameraMode.destination:
        // Affiche la destination -> le bouton propose d'aller au départ
        return const Icon(
          Icons.hail_rounded,
          color: Color(0xFF1E1E1E),
          size: 24,
        );
      case DeliveryCameraMode.departure:
        // Affiche le départ -> le bouton propose d'afficher tout le trajet
        return SvgPicture.asset(
          'assets/icons/trip-svgrepo-com.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(
            Color(0xFF1E1E1E),
            BlendMode.srcIn,
          ),
        );
    }
  }

  void _expandSheet() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _collapseSheet() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.55,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _chooseDestination() async {
    final result = await DeliveryDestinationSearchModal.show(
      context,
      placesService: _placesService,
      pickupLocation: _pickupLocation,
    );

    if (result != null && mounted) {
      setState(() {
        _destinationLocation = LatLng(
          result.latitude,
          result.longitude,
        );
        _destinationAddress = result.mainText.isNotEmpty
            ? result.mainText
            : result.fullAddress;
      });
      _updateMapMarkers();
    }
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
      _updateMapMarkers();
    }
  }

  Future<void> _openOrderForm() async {
    if (_destinationAddress == null || _destinationLocation == null) {
      await _chooseDestination();
      if (_destinationAddress == null) return;
    }

    if (!mounted) return;

    final estimatedPrice =
        _selectedDeliveryType == 'cargo' ? _cargoPrice : _motoPrice;

    await DeliveryOrderFormModal.show(
      context,
      pickupAddress: _pickupAddress,
      destinationAddress: _destinationAddress!,
      pickupLocation: _pickupLocation,
      destinationLocation: _destinationLocation,
      placesService: _placesService,
      deliveryType: _selectedDeliveryType,
      estimatedPrice: estimatedPrice,
      onEditPickup: _editPickupAddress,
      onEditDestination: _chooseDestination,
      onAddressesUpdated: (pickup, pickupLoc, dest, destLoc) {
        if (!mounted) return;
        setState(() {
          _pickupAddress = pickup;
          if (pickupLoc != null) _pickupLocation = pickupLoc;
          _destinationAddress = dest;
          if (destLoc != null) _destinationLocation = destLoc;
        });
        _updateMapMarkers();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isMoto = _selectedDeliveryType == 'moto';

    // Progression de l'agrandissement du modal vers la page de détails (de 0.55 à 1.0)
    final double t = ((_currentSheetSize - 0.55) / 0.45).clamp(0.0, 1.0);

    // Calcul de la position du bouton flottant au-dessus du modal
    final double floatingButtonBottom =
        math.min(screenHeight * _currentSheetSize + 14, screenHeight - 90);
    final double floatingButtonOpacity =
        (1.0 - t * 2.2).clamp(0.0, 1.0);

    // Calcul de la zone sécurisée en haut pour les encoches et caméras
    final safeTop = math.max(mediaQuery.padding.top, mediaQuery.viewPadding.top);
    final topBarPadding = safeTop > 0 ? safeTop + 8 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. CARTE EN PLEIN ÉCRAN AVEC PADDING INFÉRIEUR SYNCHRONISÉ AU MODAL
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _pickupLocation,
                zoom: 16.2,
              ),
              padding: EdgeInsets.only(
                bottom: screenHeight * _currentSheetSize,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                MapStyleService.applyStyle(controller);
              },
              onCameraMoveStarted: () {
                if (!_isMapMoving) {
                  setState(() => _isMapMoving = true);
                }
              },
              onCameraMove: (position) {
                _currentCameraCenter = position.target;
              },
              onCameraIdle: () {
                if (_isMapMoving) {
                  setState(() => _isMapMoving = false);
                }
                if (_currentCameraCenter != null &&
                    _destinationLocation == null) {
                  _updatePickupLocation(_currentCameraCenter!);
                }
              },
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // 2. Marqueur interactif animé au centre de la zone visible de la carte (en haut, bien espacé du modal)
          if (_destinationLocation == null && floatingButtonOpacity > 0.05)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * (1.0 - _currentSheetSize),
              child: Opacity(
                opacity: floatingButtonOpacity,
                child: Center(
                  child: IgnorePointer(
                    child: SeddoMapPickerPin(
                      isMoving: _isMapMoving,
                      customPinIcon: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              'Prise en charge ~9 min',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E1E1E),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.mapPickerPinOrange,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.38),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.hail_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          Container(
                            width: 2.8,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bouton Retour circulaire en haut à gauche
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.18),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.arrow_back,
                    color: Color(0xFF1E1E1E),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // 3. Bouton circulaire blanc flottant directement AU-DESSUS du modal
          // Affiche la flèche de navigation ou cycle entre point de départ, flag et trajet (comme dans les courses Seddo)
          if (floatingButtonOpacity > 0.05)
            Positioned(
              bottom: floatingButtonBottom,
              right: 16,
              child: Opacity(
                opacity: floatingButtonOpacity,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 5,
                  shadowColor: Colors.black.withOpacity(0.20),
                  child: InkWell(
                    onTap: _onFloatingCircularButtonTap,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: _buildFloatingCircularIcon(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 4. MODAL INFÉRIEUR COULISSANT "ENVOYER UN COLIS" & PAGE DE DÉTAIL DYNAMIQUE
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.55, // Position de base
            minChildSize: 0.55, // Verrouillé à la position de base : ne peut pas descendre plus bas
            maxChildSize: 1.0,
            snap: true,
            snapSizes: const [0.55, 1.0],
            builder: (context, scrollController) {
              final bottomPadding = MediaQuery.of(context).padding.bottom;

              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 18,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Contenu défilable
                    SingleChildScrollView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Barre supérieure en mode pleine page (fades in quand t > 0.3)
                          if (t > 0.1)
                            Opacity(
                              opacity: t,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16, topBarPadding, 16, 4),
                                child: Row(
                                  children: [
                                    Material(
                                      color: const Color(0xFFF1F5F9),
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        onTap: _collapseSheet,
                                        customBorder: const CircleBorder(),
                                        child: const SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: Icon(
                                            Icons.arrow_back,
                                            color: Color(0xFF1E293B),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(
                                          _pickupAddress,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      shape: const CircleBorder(),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.info_outline_rounded,
                                          color: Color(0xFF64748B),
                                          size: 22,
                                        ),
                                        onPressed: () {
                                          DeliveryInfoModal.show(
                                            context,
                                            deliveryType: _selectedDeliveryType,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Poignée de glissement (drag handle) quand le modal est en bas
                          if (t <= 0.3)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 10, bottom: 6),
                                width: 40,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),

                          // 2. Photo dans le détail qui grandit au fur et à mesure que l'on remonte le modal
                          if (t > 0.05)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Center(
                                child: SizedBox(
                                  height: 165 * t, // Grandit progressivement de 0 à sa taille normale
                                  child: Opacity(
                                    opacity: t,
                                    child: Image.asset(
                                      isMoto
                                          ? 'assets/images/express.png'
                                          : 'assets/images/cargo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Grand titre "Livraison" + Tarifs de la page détail
                          if (t > 0.1)
                            Opacity(
                              opacity: t,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Livraison',
                                      style: GoogleFonts.inter(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isMoto
                                          ? 'Pour les petits colis et documents'
                                          : 'Transportez de gros volumes',
                                      style: GoogleFonts.inter(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isMoto
                                          ? 'à partir de $_motoPrice F · 13 min. >'
                                          : 'à partir de $_cargoPrice F · 5 min. >',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                ),
                              ),
                            ),

                          // Titre "ENVOYER UN COLIS" en mode compact
                          if (t <= 0.3)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                              child: Text(
                                'ENVOYER UN COLIS',
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1E1E1E),
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),

                          // Boîte des adresses (Départ & Arrivée) en mode compact
                          if (t <= 0.3)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFF3F4F6), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    InkWell(
                                      onTap: _editPickupAddress,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E1E1E),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.hail_rounded,
                                                color: Colors.white,
                                                size: 21,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                _pickupAddress,
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF1E1E1E),
                                                  letterSpacing: -0.2,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Divider(
                                      height: 1,
                                      thickness: 0.8,
                                      indent: 64,
                                      endIndent: 16,
                                      color: Color(0xFFF1F5F9),
                                    ),
                                    InkWell(
                                      onTap: _chooseDestination,
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: Center(
                                                child: SvgPicture.asset(
                                                  'assets/icons/flag-svgrepo-com.svg',
                                                  width: 22,
                                                  height: 22,
                                                  colorFilter: const ColorFilter.mode(
                                                    Color(0xFF1E1E1E),
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                _destinationAddress ??
                                                    'Adresse de livraison',
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight:
                                                      _destinationAddress != null
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                  color: _destinationAddress != null
                                                      ? const Color(0xFF1E1E1E)
                                                      : const Color(0xFF94A3B8),
                                                  letterSpacing: -0.2,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 14),

                          // 3. Cartes de choix de véhicules : "Express Moto" & "Express Cargo"
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildVehicleCard(
                                    title: 'Express Moto',
                                    timeBadge: '9 min.',
                                    price: 'à partir de $_motoPrice F',
                                    imagePath: 'assets/images/livraison.png',
                                    isSelected: isMoto,
                                    onTap: () => setState(
                                        () => _selectedDeliveryType = 'moto'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildVehicleCard(
                                    title: 'Express Cargo',
                                    timeBadge: '5 min.',
                                    price: 'à partir de $_cargoPrice F',
                                    imagePath: 'assets/images/cargo.png',
                                    isSelected: !isMoto,
                                    onTap: () => setState(
                                        () => _selectedDeliveryType = 'cargo'),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 4. Section "À savoir" visible quand le modal monte
                          if (t > 0.2) ...[
                            const SizedBox(height: 20),
                            Opacity(
                              opacity: t,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'À savoir',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        children: [
                                          _buildStepRow(
                                            stepNumber: '1',
                                            title:
                                                'Appuyez sur « Ouvrir le formulaire de commande »',
                                            subtitle:
                                                'Bouton situé en bas de cet écran',
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            child: Divider(
                                              height: 1,
                                              thickness: 0.8,
                                              color: Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          _buildStepRow(
                                            stepNumber: '2',
                                            title: 'Sélectionnez les options requises',
                                            subtitle: isMoto
                                                ? 'Jusqu\'à la porte, jusqu\'au porche, ou dans l\'intervalle de temps'
                                                : 'Volume, déménageurs, itinéraire et vitesse de prise en charge',
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            child: Divider(
                                              height: 1,
                                              thickness: 0.8,
                                              color: Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          _buildStepRow(
                                            stepNumber: '3',
                                            title: 'Sélectionnez le mode paiement',
                                            subtitle:
                                                'Tout est prêt, passez votre commande',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Espace pour ne pas être masqué par la barre d'action inférieure
                          SizedBox(height: bottomPadding + 88),
                        ],
                      ),
                    ),

                    // Barre d'actions inférieure fixée en bas du modal
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(18, 10, 18, bottomPadding + 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // 1. Mode de paiement à gauche (SANS contours)
                            ValueListenableBuilder<String>(
                              valueListenable:
                                  PaymentMethodsService().selectedCodeNotifier,
                              builder: (context, code, _) {
                                final assetPath =
                                    PaymentMethodsService.getAssetForCode(code);
                                final isCash =
                                    code.toUpperCase().trim() == 'CASH';

                                return Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    onTap: () =>
                                        PaymentMethodModal.show(context),
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox(
                                      width: 48,
                                      height: 52,
                                      child: Center(
                                        child: isCash
                                            ? Image.asset(
                                                assetPath,
                                                width: 40,
                                                height: 28,
                                                fit: BoxFit.contain,
                                              )
                                            : ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Image.asset(
                                                  assetPath,
                                                  width: 32,
                                                  height: 32,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(width: 8),

                            // 2. Bouton central orange/rouge "Accéder au formulaire de commande"
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _openOrderForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'Accéder au formulaire\nde commande',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // 3. Bouton à droite : tune (ouvre le détail) ou flèche vers le bas (replie le modal) - SANS card
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: t >= 0.5 ? _collapseSheet : _expandSheet,
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 44,
                                  height: 52,
                                  child: Center(
                                    child: Icon(
                                      t >= 0.5
                                          ? Icons.keyboard_arrow_down_rounded
                                          : Icons.tune_rounded,
                                      color: const Color(0xFF1E1E1E),
                                      size: 28,
                                    ),
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
            },
          ),
        ],
      ),
    );
  }

  /// Carte de sélection sans contour (border: null) avec photo de véhicule bien proportionnée
  Widget _buildVehicleCard({
    required String title,
    required String timeBadge,
    required String price,
    required String imagePath,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isCargo = imagePath.contains('cargo');

    return Material(
      color: isSelected ? const Color(0xFFF1F5F9) : const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      timeBadge,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Image.asset(
                    imagePath,
                    width: isCargo ? 76 : 54,
                    height: isCargo ? 44 : 36,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                price,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String stepNumber,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
