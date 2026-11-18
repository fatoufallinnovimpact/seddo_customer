import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to resolve driver photo URL and cache photo bytes & Bearer token
class DriverAvatarHelper {
  static String? _cachedToken;
  static final Map<String, Uint8List> _bytesCache = {};

  static Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('auth_access_token');
    } catch (_) {}
    return _cachedToken;
  }

  static String? resolveUrl(String? raw, [String? rideId]) {
    final clean = raw?.trim() ?? '';
    if (clean.isNotEmpty) {
      if (clean.startsWith('http')) return clean;
      final base = BaseUrl.current.endsWith('/')
          ? BaseUrl.current.substring(0, BaseUrl.current.length - 1)
          : BaseUrl.current;
      return clean.startsWith('/') ? '$base$clean' : '$base/$clean';
    }

    final effectiveRideId = (rideId != null && rideId.trim().isNotEmpty)
        ? rideId.trim()
        : (RideService.lastCreatedRideId ?? RideService.lastCompletedRideId);

    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      final base = BaseUrl.current.endsWith('/')
          ? BaseUrl.current.substring(0, BaseUrl.current.length - 1)
          : BaseUrl.current;
      return '$base/v1/rides/$effectiveRideId/driver/photo';
    }
    return null;
  }

  static Uint8List? getCached({String? photoUrl, String? rideId}) {
    if (photoUrl != null && photoUrl.trim().isNotEmpty && _bytesCache.containsKey(photoUrl.trim())) {
      return _bytesCache[photoUrl.trim()];
    }
    final effectiveRideId = rideId ?? RideService.lastCreatedRideId ?? RideService.lastCompletedRideId;
    if (effectiveRideId != null && _bytesCache.containsKey('ride_$effectiveRideId')) {
      return _bytesCache['ride_$effectiveRideId'];
    }
    return null;
  }

  static void setCached(String key, Uint8List bytes) {
    if (key.trim().isNotEmpty) {
      _bytesCache[key.trim()] = bytes;
    }
  }

  static void clearCache() {
    _bytesCache.clear();
    _cachedToken = null;
  }

  static Future<Uint8List?> fetchDriverPhoto({
    String? photoUrl,
    String? rideId,
    RideService? rideService,
  }) async {
    final cached = getCached(photoUrl: photoUrl, rideId: rideId);
    if (cached != null) return cached;

    final cleanPhoto = photoUrl?.trim();
    final effectiveRideId = (rideId != null && rideId.trim().isNotEmpty)
        ? rideId.trim()
        : (RideService.lastCreatedRideId ?? RideService.lastCompletedRideId);

    if ((cleanPhoto == null || cleanPhoto.isEmpty) &&
        (effectiveRideId == null || effectiveRideId.isEmpty)) {
      return null;
    }

    try {
      final service = rideService ?? RideService();
      final bytes = await service.getPartyPhoto(
        rideId: effectiveRideId ?? '',
        party: 'driver',
        explicitUrl: cleanPhoto,
      );

      if (bytes != null && bytes.isNotEmpty) {
        if (photoUrl != null && photoUrl.trim().isNotEmpty) {
          _bytesCache[photoUrl.trim()] = bytes;
        }
        if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
          _bytesCache['ride_$effectiveRideId'] = bytes;
        }
        return bytes;
      }
    } catch (_) {}
    return null;
  }
}

/// Widget affichant la photo de profil réelle du chauffeur via l'endpoint
/// GET /v1/rides/{id}/{party}/photo (RidesController_partyPhoto)
/// ou ses initiales en fallback si le chauffeur n'a pas de photo.
class DriverAvatarWidget extends StatefulWidget {
  final String? photoUrl;
  final String? rideId;
  final String name;
  final double size;
  final TextStyle? initialsStyle;
  final Color backgroundColor;
  final Color initialsColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final RideService? rideService;

  const DriverAvatarWidget({
    super.key,
    this.photoUrl,
    this.rideId,
    required this.name,
    this.size = 52.0,
    this.initialsStyle,
    this.backgroundColor = AppColors.surfaceGrey,
    this.initialsColor = AppColors.textPrimary,
    this.border,
    this.boxShadow,
    this.rideService,
  });

  @override
  State<DriverAvatarWidget> createState() => _DriverAvatarWidgetState();
}

class _DriverAvatarWidgetState extends State<DriverAvatarWidget> {
  Uint8List? _imageBytes;
  String? _token;

  @override
  void initState() {
    super.initState();
    _imageBytes = DriverAvatarHelper.getCached(
      photoUrl: widget.photoUrl,
      rideId: widget.rideId,
    );
    _loadPhotoAndToken();
  }

  @override
  void didUpdateWidget(covariant DriverAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photoUrl != oldWidget.photoUrl || widget.rideId != oldWidget.rideId) {
      _loadPhotoAndToken();
    }
  }

  Future<void> _loadPhotoAndToken() async {
    final token = await DriverAvatarHelper.getToken();
    if (mounted && token != null && token != _token) {
      setState(() {
        _token = token;
      });
    }

    if (_imageBytes == null) {
      final bytes = await DriverAvatarHelper.fetchDriverPhoto(
        photoUrl: widget.photoUrl,
        rideId: widget.rideId,
        rideService: widget.rideService,
      );
      if (mounted && bytes != null && bytes.isNotEmpty) {
        setState(() {
          _imageBytes = bytes;
        });
      }
    }
  }

  String _getInitials() {
    if (widget.name.trim().isEmpty) return 'CH';
    final parts = widget.name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = DriverAvatarHelper.resolveUrl(widget.photoUrl, widget.rideId);
    final initials = _getInitials();

    final initialsWidget = Center(
      child: Text(
        initials,
        style: widget.initialsStyle ??
            GoogleFonts.inter(
              fontSize: widget.size * 0.33,
              fontWeight: FontWeight.w800,
              color: widget.initialsColor,
            ),
      ),
    );

    Widget imageContent;
    if (_imageBytes != null && _imageBytes!.isNotEmpty) {
      imageContent = Image.memory(
        _imageBytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => initialsWidget,
      );
    } else if (resolvedUrl != null) {
      // N'appeler Image.network vers notre API que si le jeton d'authentification est prêt,
      // pour éviter les requêtes non-authentifiées qui provoquent une erreur 401.
      final isApiUrl = resolvedUrl.contains('/v1/rides/');
      if (!isApiUrl || (_token != null && _token!.isNotEmpty)) {
        imageContent = Image.network(
          resolvedUrl,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          headers: _token != null && _token!.isNotEmpty
              ? {'Authorization': 'Bearer $_token'}
              : null,
          errorBuilder: (context, error, stackTrace) => initialsWidget,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return initialsWidget;
          },
        );
      } else {
        imageContent = initialsWidget;
      }
    } else {
      imageContent = initialsWidget;
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        shape: BoxShape.circle,
        border: widget.border,
        boxShadow: widget.boxShadow,
      ),
      child: ClipOval(
        child: imageContent,
      ),
    );
  }
}
