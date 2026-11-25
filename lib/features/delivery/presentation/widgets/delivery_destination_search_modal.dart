import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/pickup_map_location_picker_page.dart';
import 'package:seddo/services/places_service.dart';

/// Modal de recherche d'adresse de livraison avec autocomplétion Google Places
class DeliveryDestinationSearchModal extends StatefulWidget {
  final PlacesService placesService;
  final LatLng? pickupLocation;
  final String? initialSearch;
  final bool isPickup;
  final String? title;

  const DeliveryDestinationSearchModal({
    super.key,
    required this.placesService,
    this.pickupLocation,
    this.initialSearch,
    this.isPickup = false,
    this.title,
  });

  static Future<PlaceSearchResult?> show(
    BuildContext context, {
    required PlacesService placesService,
    LatLng? pickupLocation,
    String? initialSearch,
    bool isPickup = false,
    String? title,
  }) {
    return showModalBottomSheet<PlaceSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DeliveryDestinationSearchModal(
        placesService: placesService,
        pickupLocation: pickupLocation,
        initialSearch: initialSearch,
        isPickup: isPickup,
        title: title,
      ),
    );
  }

  @override
  State<DeliveryDestinationSearchModal> createState() =>
      _DeliveryDestinationSearchModalState();
}

class _DeliveryDestinationSearchModalState
    extends State<DeliveryDestinationSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchController.text = widget.initialSearch!;
      _performSearch(widget.initialSearch!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.placesService.autocomplete(
        query,
        userLocation: widget.pickupLocation,
      );
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() => _isLoading = true);
    try {
      final details = await widget.placesService.details(suggestion.placeId);
      if (mounted) {
        final result = PlaceSearchResult(
          id: suggestion.placeId,
          fullAddress: details.address.isNotEmpty
              ? details.address
              : suggestion.description,
          mainText: suggestion.mainText ?? details.address,
          secondaryText: suggestion.secondaryText ?? '',
          latitude: details.lat,
          longitude: details.lng,
        );
        Navigator.of(context).pop(result);
        return;
      }
    } catch (_) {}

    // Fallback si details ne renvoie rien ou échoue
    if (suggestion.latitude != null && suggestion.longitude != null && mounted) {
      final result = PlaceSearchResult(
        id: suggestion.placeId,
        fullAddress: suggestion.description,
        mainText: suggestion.mainText ?? suggestion.description,
        secondaryText: suggestion.secondaryText ?? '',
        latitude: suggestion.latitude!,
        longitude: suggestion.longitude!,
      );
      Navigator.of(context).pop(result);
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickOnMap() async {
    final defaultLocation = widget.pickupLocation ??
        const LatLng(14.6928, -17.4730);

    final result = await Navigator.of(context).push<PlaceSearchResult>(
      MaterialPageRoute(
        builder: (ctx) => PickupMapLocationPickerPage(
          initialLocation: defaultLocation,
          initialMainText: widget.isPickup
              ? 'Choisir le point de départ'
              : 'Choisir l\'adresse de livraison',
          placesService: widget.placesService,
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.88;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header avec bouton fermeture et Titre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Material(
                  color: const Color(0xFFF1F5F9),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.close_rounded,
                        color: Color(0xFF1E293B),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.title ??
                        (widget.isPickup
                            ? 'Point de départ'
                            : 'Adresse de livraison'),
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Barre de recherche avec autocomplétion
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  if (widget.isPickup)
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: Color(0xFF64748B),
                    )
                  else
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/flag-svgrepo-com.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF64748B),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: widget.isPickup
                            ? 'Où récupérer le colis ?'
                            : 'Où livrer le colis ?',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Option rapide : Choisir sur la carte
          InkWell(
            onTap: _pickOnMap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.map_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choisir sur la carte',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          widget.isPickup
                              ? 'Placer le point de départ manuellement'
                              : 'Placer le repère de livraison manuellement',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),

          // Liste des suggestions d'autocomplétion
          Expanded(
            child: _suggestions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Tapez une adresse ou un quartier de Dakar'
                            : 'Aucune adresse trouvée pour "${_searchController.text}"',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 64,
                      endIndent: 16,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      return ListTile(
                        onTap: () => _selectSuggestion(item),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.mainText ?? item.description,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: item.secondaryText?.isNotEmpty == true
                            ? Text(
                                item.secondaryText!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: item.distanceKm != null
                            ? Text(
                                '${item.distanceKm} km',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
