import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/activity/presentation/pages/activity_page.dart';
import 'package:seddo/features/drawer/presentation/widgets/language_modal.dart';
import 'package:seddo/features/drawer/presentation/widgets/logout_modal.dart';
import 'package:seddo/features/help/presentation/pages/help_page.dart';
import 'package:seddo/features/privacy/presentation/pages/privacy_page.dart';
import 'package:seddo/features/safety/presentation/pages/safety_page.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/saved_places/presentation/pages/saved_places_page.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_page.dart';
import 'package:seddo/features/profile/presentation/pages/edit_profile_page.dart';

/// Lateral navigation drawer matching the design mockup:
/// - User profile: Real avatar photo or initials, real user name, rating from GET /v1/users/me and phone number
/// - Menu list items:
///   - Activité (refresh-ccw-clock-svgrepo-com.svg / Courses et remboursements)
///   - TCU (bus-svgrepo-com.svg / Bus, BRT et TER)
///   - Lieux enregistrés (star-svgrepo-com.svg / Maison, Travail, Aéroport)
///   - Sécurité (security-svgrepo-com.svg / Contacts d’urgence, partage de trajet)
///   - Notifications (notification-svgrepo-com.svg / Push et SMS)
///   - Langue (language-svgrepo-com.svg / Français ou Wolof)
/// - Bottom section:
///   - Row with Aide (question-svgrepo-com.svg) & Confidentialité et données (lock icon)
///   - Red Se déconnecter button (logout-line-svgrepo-com.svg)
class SeddoDrawerWidget extends StatefulWidget {
  const SeddoDrawerWidget({super.key});

  @override
  State<SeddoDrawerWidget> createState() => _SeddoDrawerWidgetState();
}

class _SeddoDrawerWidgetState extends State<SeddoDrawerWidget> {
  final AuthRepository _authRepo = AuthRepository();
  UserModel? _currentUser;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _currentUser = _authRepo.currentUser;
    _loadUser();
  }

  Future<void> _loadUser() async {
    final token = await _authRepo.getAccessToken();
    if (mounted && token != null) {
      setState(() {
        _accessToken = token;
      });
    }

    final cached = await _authRepo.getCachedUser();
    if (mounted && cached != null) {
      setState(() {
        _currentUser = cached;
      });
    }

    final remote = await _authRepo.fetchUserProfile();
    if (mounted && remote != null) {
      setState(() {
        _currentUser = remote;
      });
    }
  }

  Future<void> _openEditProfile(BuildContext context) async {
    Navigator.of(context).pop();
    final updated = await Navigator.of(context).push<UserModel?>(
      SlideRightToLeftRoute(
        page: EditProfilePage(
          currentUser: _currentUser ?? _authRepo.currentUser,
        ),
      ),
    );
    if (mounted) {
      if (updated != null) {
        setState(() {
          _currentUser = updated;
        });
      }
      _loadUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = (screenWidth * 0.84).clamp(300.0, 360.0);
    final user = _currentUser ?? _authRepo.currentUser;

    return Drawer(
      width: drawerWidth,
      backgroundColor: AppColors.white,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomLeft: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. User Profile Header
                            _buildProfileHeader(context, user),
                            const SizedBox(height: 20),

                        // 2. Navigation List Items
                        _buildMenuItem(
                          context: context,
                          iconPath:
                              'assets/icons/refresh-ccw-clock-svgrepo-com.svg',
                          title: 'drawer.activity'.tr(),
                          subtitle: 'drawer.activity_sub'.tr(),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              SlideRightToLeftRoute(
                                page: const ActivityPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),

                        _buildMenuItem(
                          context: context,
                          iconPath: 'assets/icons/bus-svgrepo-com.svg',
                          title: 'drawer.tcu'.tr(),
                          subtitle: 'drawer.tcu_sub'.tr(),
                          onTap: () {
                            LatLng? userLoc;
                            try {
                              userLoc = context.read<HomeBloc>().state.userLocation;
                            } catch (_) {}
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              SlideRightToLeftRoute(
                                page: PublicTransportPage(
                                  initialOriginLocation: userLoc,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),

                        _buildMenuItem(
                          context: context,
                          iconPath: 'assets/icons/star-svgrepo-com.svg',
                          title: 'drawer.saved_places'.tr(),
                          subtitle: 'drawer.saved_places_sub'.tr(),
                          onTap: () {
                            LatLng? userLoc;
                            try {
                              userLoc = context.read<HomeBloc>().state.userLocation;
                            } catch (_) {}
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              SlideRightToLeftRoute(
                                page: SavedPlacesPage(
                                  currentUserLocation: userLoc,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),

                        _buildMenuItem(
                          context: context,
                          iconPath: 'assets/icons/security-svgrepo-com.svg',
                          title: 'drawer.safety'.tr(),
                          subtitle: 'drawer.safety_sub'.tr(),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              SlideRightToLeftRoute(
                                page: const SafetyPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),

                        _buildMenuItem(
                          context: context,
                          iconPath: 'assets/icons/notification-svgrepo-com.svg',
                          title: 'drawer.notifications'.tr(),
                          subtitle: 'drawer.notifications_sub'.tr(),
                          onTap: () {
                            _openEditProfile(context);
                          },
                        ),
                        const SizedBox(height: 6),

                        _buildMenuItem(
                          context: context,
                          iconPath: 'assets/icons/language-svgrepo-com.svg',
                          title: 'drawer.language'.tr(),
                          subtitle: context.locale.languageCode == 'wo'
                              ? 'common.wolof'.tr()
                              : 'common.french'.tr(),
                          onTap: () {
                            _openLanguageSheet(context);
                          },
                        ),
                        const SizedBox(height: 6),

                        // 7. Aide (in the list right below Langue)
                        _buildMenuItem(
                          context: context,
                          iconPath: 'assets/icons/question-svgrepo-com.svg',
                          title: 'drawer.help'.tr(),
                          subtitle: 'drawer.help_sub'.tr(),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              SlideRightToLeftRoute(
                                page: const HelpPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),

                        // 8. Confidentialité et données (in the list right below Aide)
                        _buildMenuItem(
                          context: context,
                          iconWidget: const Icon(
                            Icons.lock_outline_rounded,
                            size: 22,
                            color: AppColors.textPrimary,
                          ),
                          title: 'drawer.privacy'.tr(),
                          subtitle: 'drawer.privacy_sub'.tr(),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              SlideRightToLeftRoute(
                                page: const PrivacyPage(),
                              ),
                            );
                          },
                        ),

                        // Spacer pushes logout button towards the bottom
                        const Spacer(),
                        const SizedBox(height: 18),

                        // Logout Button (Red with SVG, surélevé du bas)
                        _buildLogoutButton(context),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Profile Header: Displays real user initials/photo, name, rating from GET /v1/users/me, and phone
  Widget _buildProfileHeader(BuildContext context, UserModel? user) {
    final String first = (user?.firstName ?? '').trim();
    final String last = (user?.lastName ?? '').trim();
    final String displayName = (first.isNotEmpty && last.isNotEmpty)
        ? '$first $last'
        : (user != null &&
                user.fullName.trim().isNotEmpty &&
                user.fullName.trim() != 'Utilisateur Seddo')
            ? user.fullName.trim()
            : (first.isNotEmpty)
                ? first
                : (user != null && user.formattedNationalPhone.isNotEmpty)
                    ? user.formattedNationalPhone
                    : 'Utilisateur';

    final initials = (user != null && user.initials.isNotEmpty && user.initials != 'SD')
        ? user.initials
        : (first.isNotEmpty)
            ? first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase()
            : 'SD';

    final displayPhone =
        (user != null && user.formattedNationalPhone.isNotEmpty)
            ? user.formattedNationalPhone
            : (user != null && user.formattedDisplayPhone.isNotEmpty)
                ? user.formattedDisplayPhone
                : '';

    final bool hasRating =
        user != null && user.rating != null && user.rating! > 0;
    final displayRating = hasRating
        ? user.rating!.toStringAsFixed(1).replaceAll('.', ',')
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          key: const Key('drawer_avatar_button'),
          onTap: () => _openEditProfile(context),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: _buildAvatarImage(user, initials),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                key: const Key('drawer_user_name_button'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openEditProfile(context),
                child: Text(
                  displayName,
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.1,
                    wordSpacing: 3.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 3),
              if (hasRating)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: AppColors.amberWarning,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        displayRating,
                        key: const Key('drawer_user_rating'),
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        ' · ',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        displayPhone,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  displayPhone,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage(UserModel? user, String initials) {
    final photoUrl = user?.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      final fullUrl = photoUrl.startsWith('http')
          ? photoUrl
          : (photoUrl.startsWith('/')
              ? '${ApiEndpoints.baseUrl}$photoUrl'
              : '${ApiEndpoints.baseUrl}/$photoUrl');
      return Image.network(
        fullUrl,
        headers: _accessToken != null
            ? {'Authorization': 'Bearer $_accessToken'}
            : null,
        fit: BoxFit.cover,
        width: 58,
        height: 58,
        errorBuilder: (context, error, stackTrace) =>
            _buildInitialsText(initials),
      );
    }

    return _buildInitialsText(initials);
  }

  Widget _buildInitialsText(String initials) {
    return Text(
      initials,
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: AppColors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  // Menu item with vector SVG icon or iconWidget, bold title and subtitle
  Widget _buildMenuItem({
    required BuildContext context,
    String? iconPath,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Container(
          width: double.infinity,
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
              children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Center(
                  child: iconWidget ??
                      (iconPath != null
                          ? SvgPicture.asset(
                              iconPath,
                              width: 22,
                              height: 22,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            )
                          : const SizedBox.shrink()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Logout button at the very bottom
  Widget _buildLogoutButton(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => _confirmLogout(context),
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.sirenRed.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/icons/logout-line-svgrepo-com.svg',
                width: 22,
                height: 22,
                colorFilter: const ColorFilter.mode(
                  AppColors.sirenRed,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'drawer.logout'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sirenRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }






  void _openLanguageSheet(BuildContext context) {
    LanguageModal.show(context);
  }





  void _confirmLogout(BuildContext context) {
    LogoutModal.show(context);
  }
}
