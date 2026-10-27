import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
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

/// Lateral navigation drawer matching the design mockup:
/// - User profile: Orange circular avatar (AD), "AWA DIOP", rating (★ 4,8 · 77 123 45 12)
/// - Modern payment card: Dark background with stylish orange circular curve, wallet icon, Orange Money
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
class SeddoDrawerWidget extends StatelessWidget {
  const SeddoDrawerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = (screenWidth * 0.84).clamp(300.0, 360.0);

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
        child: FutureBuilder<UserModel?>(
          future: AuthRepository().getCachedUser(),
          initialData: AuthRepository().currentUser,
          builder: (context, snapshot) {
            final user = snapshot.data ?? AuthRepository().currentUser;
            return LayoutBuilder(
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
                            const SizedBox(height: 22),

                            // 2. Modern Dark Payment Card with Orange Curve
                            _buildPaymentCard(context, user),
                            const SizedBox(height: 20),

                        // 3. Navigation List Items
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
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              SlideRightToLeftRoute(
                                page: const PublicTransportPage(),
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
        );
      },
    ),
  ),
);
  }

  // Profile Header: Displays real user initials, name, and phone from authentication
  Widget _buildProfileHeader(BuildContext context, UserModel? user) {
    final displayName = (user != null && user.fullName.isNotEmpty)
        ? user.fullName.toUpperCase()
        : 'AWA DIOP';
    final initials = (user != null && user.initials.isNotEmpty)
        ? user.initials
        : 'AD';
    final displayPhone =
        (user != null && user.formattedNationalPhone.isNotEmpty)
            ? user.formattedNationalPhone
            : (user != null && user.formattedDisplayPhone.isNotEmpty)
                ? user.formattedDisplayPhone
                : '77 123 45 12';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
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
                          '4,8',
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
                  ),
                ],
              ),
            ),
          ],
        );
  }

  // Modern Payment Card
  Widget _buildPaymentCard(BuildContext context, UserModel? user) {
    final paymentPhone = (user != null && user.maskedPhone.isNotEmpty)
        ? user.maskedPhone
        : '77 ••• 45 12';

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          _openPaymentSheet(context, user);
        },
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        child: Container(
          height: 74,
          decoration: BoxDecoration(
            color: AppColors.drawerDark,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowDarkBlack,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Stylish orange crescent on the right edge
              Positioned(
                right: -24,
                top: -12,
                bottom: -12,
                child: Container(
                  width: 90,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Card content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.drawerCardBorder,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.credit_card_rounded,
                        color: AppColors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'drawer.payment'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Orange Money $paymentPhone',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.white.withValues(alpha: 0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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

  // Modals & Bottom Sheets

  static void openNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'drawer.notifications_title'.tr(),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildNotificationItem(
              title: 'drawer.notif_rides'.tr(),
              subtitle: 'drawer.notif_rides_desc'.tr(),
              initialValue: true,
            ),
            const Divider(height: 24),
            _buildNotificationItem(
              title: 'drawer.notif_promo'.tr(),
              subtitle: 'drawer.notif_promo_desc'.tr(),
              initialValue: true,
            ),
            const Divider(height: 24),
            _buildNotificationItem(
              title: 'drawer.notif_safety'.tr(),
              subtitle: 'drawer.notif_safety_desc'.tr(),
              initialValue: true,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildNotificationItem({
    required String title,
    required String subtitle,
    required bool initialValue,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: initialValue,
              activeTrackColor: AppColors.primary,
              onChanged: (val) {
                setState(() => initialValue = val);
              },
            ),
          ],
        );
      },
    );
  }

  void _openPaymentSheet(BuildContext context, [UserModel? user]) {
    final effectiveUser = user ?? AuthRepository().currentUser;
    final sheetPhone = (effectiveUser != null &&
            effectiveUser.formattedDisplayPhone.isNotEmpty)
        ? effectiveUser.formattedDisplayPhone
        : '+221 77 123 45 12';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'drawer.payment_methods'.tr(),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'drawer.payment_secure_desc'.tr(),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.orangeLightBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.phone_android_rounded,
                      color: AppColors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Orange Money',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$sheetPhone · ${'drawer.default_mode'.tr()}',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceGrey,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.waveBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.waves_rounded,
                      color: AppColors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wave',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'drawer.soon'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
