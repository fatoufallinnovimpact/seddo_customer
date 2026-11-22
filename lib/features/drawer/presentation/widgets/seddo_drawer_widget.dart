import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/activity/presentation/pages/activity_page.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/drawer/domain/bloc/drawer_account_bloc.dart';
import 'package:seddo/features/drawer/domain/bloc/drawer_account_event.dart';
import 'package:seddo/features/drawer/domain/bloc/drawer_account_state.dart';
import 'package:seddo/features/drawer/presentation/widgets/language_modal.dart';
import 'package:seddo/features/drawer/presentation/widgets/logout_modal.dart';
import 'package:seddo/features/drawer/presentation/widgets/notifications_modal.dart';
import 'package:seddo/features/help/presentation/pages/help_page.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/payment/data/services/payment_methods_service.dart';
import 'package:seddo/features/payment/presentation/widgets/payment_method_modal.dart';
import 'package:seddo/features/privacy/presentation/pages/privacy_page.dart';
import 'package:seddo/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:seddo/features/safety/presentation/pages/safety_page.dart';
import 'package:seddo/features/saved_places/presentation/pages/saved_places_page.dart';

/// Full-screen Account / Menu View ("Mon compte") matching the user's design mockups:
/// - Opens full-screen occupying the entire phone screen width & height
/// - Header at the top with "Mon compte"
/// - White borderless profile card with subtle shadow:
///   * Circular avatar with real user profile photo or initials
///   * Real user name and phone number
///   * Tapping the name or the avatar circle navigates to EditProfilePage
///   * Below in the same white card: two borderless grey cards:
///     1. Number of trips (real API value, 0 if 0)
///     2. Star rating returned by the API (if 0 or null, displays 0 with star)
/// - Below: Grouped white borderless cards with subtle shadow and pastel circular icons
///   for all existing menu items (Activité, TCU, Lieux enregistrés, Méthode de paiement,
///   Sécurité, Notifications, Langue, Aide, Confidentialité et données) and Se déconnecter.
class SeddoDrawerWidget extends StatefulWidget {
  const SeddoDrawerWidget({super.key});

  @override
  State<SeddoDrawerWidget> createState() => _SeddoDrawerWidgetState();
}

class _SeddoDrawerWidgetState extends State<SeddoDrawerWidget> {
  late final DrawerAccountBloc _accountBloc;
  final AuthRepository _authRepo = AuthRepository();
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    _accountBloc = DrawerAccountBloc(authRepository: _authRepo)
      ..add(const DrawerAccountLoadRequested());
    PaymentMethodsService().init();
    PaymentMethodsService().refreshFromBackend().ignore();
  }

  @override
  void dispose() {
    _accountBloc.close();
    super.dispose();
  }

  bool _isInDrawer(BuildContext context) {
    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState != null &&
        (scaffoldState.isDrawerOpen || scaffoldState.isEndDrawerOpen)) {
      return true;
    }
    return context.findAncestorWidgetOfExactType<DrawerController>() != null;
  }

  void _closeMenuIfNeeded(BuildContext context) {
    if (_isInDrawer(context)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openEditProfile(BuildContext context, UserModel? user) async {
    final navigator = Navigator.of(context);
    if (_isInDrawer(context)) {
      navigator.pop();
    }
    final updated = await navigator.push<UserModel?>(
      SlideRightToLeftRoute(
        page: EditProfilePage(
          currentUser: user ?? _authRepo.currentUser,
        ),
      ),
    );
    if (mounted) {
      _accountBloc.add(DrawerAccountUserUpdated(updatedUser: updated));
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final screenWidth = MediaQuery.of(context).size.width;

    return BlocProvider<DrawerAccountBloc>.value(
      value: _accountBloc,
      child: Drawer(
        width: screenWidth,
        backgroundColor: AppColors.accountScaffoldBg,
        elevation: AppConstants.elevationNone,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _dragDistance = 0,
            onHorizontalDragUpdate: (details) {
              if (details.primaryDelta != null) {
                _dragDistance += details.primaryDelta!;
              }
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              // Balayage de gauche vers la droite pour fermer/retourner à l'accueil
              if (velocity > 250 || _dragDistance > 80) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  _closeMenuIfNeeded(context);
                }
              }
              _dragDistance = 0;
            },
            child: BlocBuilder<DrawerAccountBloc, DrawerAccountState>(
              builder: (context, state) {
                final user = state.user ?? _authRepo.currentUser;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingTwenty,
                    AppConstants.spacingUnitLg,
                    AppConstants.spacingTwenty,
                    AppConstants.spacingXl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Top Header ("Mon compte")
                      _buildTopHeader(context),
                      const SizedBox(height: AppConstants.spacingUnitLg),

                      // 2. White Profile & Stats Card (borderless, with shadow)
                      _buildProfileCard(context, user, state),
                      const SizedBox(height: AppConstants.spacingUnitXl),

                      // 3. First Grouped Card: Trajets & Paiement
                      _buildGroupedMenuCard(
                        children: [
                          _buildStyledMenuItem(
                            context: context,
                            iconPath:
                                'assets/icons/refresh-ccw-clock-svgrepo-com.svg',
                            title: 'drawer.activity'.tr(),
                            subtitle: 'drawer.activity_sub'.tr(),
                            onTap: () {
                              final navigator = Navigator.of(context);
                              _closeMenuIfNeeded(context);
                              navigator.push(
                                SlideRightToLeftRoute(
                                  page: const ActivityPage(),
                                ),
                              );
                            },
                          ),
                          _buildStyledMenuItem(
                            context: context,
                            iconPath: 'assets/icons/star-svgrepo-com.svg',
                            title: 'drawer.saved_places'.tr(),
                            subtitle: 'drawer.saved_places_sub'.tr(),
                            onTap: () {
                              LatLng? userLoc;
                              try {
                                userLoc =
                                    context.read<HomeBloc>().state.userLocation;
                              } catch (_) {}
                              final navigator = Navigator.of(context);
                              _closeMenuIfNeeded(context);
                              navigator.push(
                                SlideRightToLeftRoute(
                                  page: SavedPlacesPage(
                                    currentUserLocation: userLoc,
                                  ),
                                ),
                              );
                            },
                          ),
                          ValueListenableBuilder<String>(
                            valueListenable:
                                PaymentMethodsService().selectedCodeNotifier,
                            builder: (context, selectedCode, _) {
                              final assetPath =
                                  PaymentMethodsService.getAssetForCode(
                                selectedCode,
                              );
                              final isCash =
                                  selectedCode.toUpperCase().trim() == 'CASH';

                              return _buildStyledMenuItem(
                                context: context,
                                iconWidget: const Icon(
                                  Icons.credit_card_rounded,
                                  size: 22,
                                  color: Color(0xFF0F172A),
                                ),
                                title: 'drawer.payment_modes_title'.tr(),
                                subtitle: PaymentMethodsService.getLabelForCode(
                                  selectedCode,
                                ),
                                trailing: isCash
                                    ? Image.asset(
                                        assetPath,
                                        width: 38,
                                        height: 26,
                                        fit: BoxFit.contain,
                                      )
                                    : Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0F172A)
                                                  .withOpacity(0.06),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.asset(
                                            assetPath,
                                            width: 30,
                                            height: 30,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                onTap: () {
                                  PaymentMethodModal.show(context);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingUnitLg),

                      // 4. Second Grouped Card: Préférences & Sécurité
                      _buildGroupedMenuCard(
                        children: [
                          _buildStyledMenuItem(
                            context: context,
                            iconPath: 'assets/icons/security-svgrepo-com.svg',
                            title: 'drawer.safety'.tr(),
                            subtitle: 'drawer.safety_sub'.tr(),
                            onTap: () {
                              final navigator = Navigator.of(context);
                              _closeMenuIfNeeded(context);
                              navigator.push(
                                SlideRightToLeftRoute(
                                  page: const SafetyPage(),
                                ),
                              );
                            },
                          ),
                          _buildStyledMenuItem(
                            context: context,
                            iconPath:
                                'assets/icons/notification-svgrepo-com.svg',
                            title: 'drawer.notifications'.tr(),
                            subtitle: 'drawer.notifications_sub'.tr(),
                            onTap: () {
                              _openNotificationsModal(context, user);
                            },
                          ),
                          _buildStyledMenuItem(
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
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingUnitLg),

                      // 5. Third Grouped Card: Assistance & Confidentialité
                      _buildGroupedMenuCard(
                        children: [
                          _buildStyledMenuItem(
                            context: context,
                            iconPath: 'assets/icons/question-svgrepo-com.svg',
                            title: 'drawer.help'.tr(),
                            subtitle: 'drawer.help_sub'.tr(),
                            onTap: () {
                              final navigator = Navigator.of(context);
                              _closeMenuIfNeeded(context);
                              navigator.push(
                                SlideRightToLeftRoute(
                                  page: const HelpPage(),
                                ),
                              );
                            },
                          ),
                          _buildStyledMenuItem(
                            context: context,
                            iconWidget: const Icon(
                              Icons.lock_outline_rounded,
                              size: AppConstants.accountMenuIconSize,
                              color: Color(0xFF0F172A),
                            ),
                            title: 'drawer.privacy'.tr(),
                            subtitle: 'drawer.privacy_sub'.tr(),
                            onTap: () {
                              final navigator = Navigator.of(context);
                              _closeMenuIfNeeded(context);
                              navigator.push(
                                SlideRightToLeftRoute(
                                  page: const PrivacyPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: AppConstants.spacingUnitLg),

                    // 6. Logout Card at the bottom
                    _buildGroupedMenuCard(
                      children: [
                        _buildLogoutButton(context),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildTopHeader(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.iOS;
    final rawTitle = 'drawer.account_title'.tr();
    final titleText =
        rawTitle == 'drawer.account_title' ? 'Mon compte' : rawTitle;

    return SizedBox(
      height: AppConstants.circularIconContainerSize,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Titre centré
          Center(
            child: Text(
              titleText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: AppConstants.accountTitleFontSize,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          // Flèche de retour à gauche uniquement sur Android (masquée sur iOS)
          if (!isIOS)
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  key: const Key('drawer_back_button'),
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      _closeMenuIfNeeded(context);
                    }
                  },
                  child: Container(
                    width: AppConstants.circularIconContainerSize,
                    height: AppConstants.circularIconContainerSize,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowSubtleBlack,
                          blurRadius: AppConstants.spacingUnit,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: AppConstants.iconSizeLg,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    UserModel? user,
    DrawerAccountState state,
  ) {
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

    final initials =
        (user != null && user.initials.isNotEmpty && user.initials != 'SD')
            ? user.initials
            : (first.isNotEmpty)
                ? first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase()
                : 'SD';

    final displayPhone = (user != null && user.formattedDisplayPhone.isNotEmpty)
        ? user.formattedDisplayPhone
        : (user != null && user.formattedNationalPhone.isNotEmpty)
            ? (user.formattedNationalPhone.startsWith('+221')
                ? user.formattedNationalPhone
                : '+221 ${user.formattedNationalPhone}')
            : '';

    final bool hasRating =
        user != null && user.rating != null && user.rating! > 0;
    final String displayRating = hasRating
        ? user.rating!.toStringAsFixed(1).replaceAll('.', ',')
        : '0';

    final int tripsValue = (user?.tripsCount != null && user!.tripsCount! > 0)
        ? user.tripsCount!
        : (state.tripsCount > 0)
            ? state.tripsCount
            : (AuthRepository.cachedTripsCount ?? user?.tripsCount ?? state.tripsCount);

    final rawTripsLabel = 'drawer.trips_label'.tr();
    final tripsLabel =
        rawTripsLabel == 'drawer.trips_label' ? 'Courses' : rawTripsLabel;

    final rawRatingLabel = 'drawer.rating_label'.tr();
    final ratingLabel =
        rawRatingLabel == 'drawer.rating_label' ? 'Évaluation' : rawRatingLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.accountCardRadius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSubtleBlack,
            blurRadius: AppConstants.accountCardShadowBlur,
            offset: Offset(0, AppConstants.accountCardShadowOffsetY),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top part: Avatar circle + User name & phone number
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                key: const Key('drawer_avatar_button'),
                onTap: () => _openEditProfile(context, user),
                child: Container(
                  width: AppConstants.accountAvatarSize,
                  height: AppConstants.accountAvatarSize,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: _buildAvatarImage(user, initials, state.accessToken),
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitXl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      key: const Key('drawer_user_name_button'),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSm),
                      onTap: () => _openEditProfile(context, user),
                      child: Text(
                        displayName,
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontXl,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (displayPhone.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spacingXxs),
                      Text(
                        displayPhone,
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontMd,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Bottom part inside the same white card: Two borderless grey cards
          Row(
            children: [
              // 1st grey card: Trips count
              Expanded(
                child: Container(
                  key: const Key('drawer_trips_stat_card'),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spacingUnit,
                    horizontal: AppConstants.spacingUnitLg,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accountStatBoxBg,
                    borderRadius: BorderRadius.circular(
                      AppConstants.accountStatBoxRadius,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$tripsValue',
                        key: const Key('drawer_user_trips_count'),
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.accountStatNumberFontSize,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingXxs),
                      Text(
                        tripsLabel,
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontSm,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitLg),

              // 2nd grey card: API star rating (or 0 if 0/null)
              Expanded(
                child: Container(
                  key: const Key('drawer_rating_stat_card'),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spacingUnit,
                    horizontal: AppConstants.spacingUnitLg,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accountStatBoxBg,
                    borderRadius: BorderRadius.circular(
                      AppConstants.accountStatBoxRadius,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayRating,
                            key: hasRating
                                ? const Key('drawer_user_rating')
                                : const Key('drawer_user_rating_zero'),
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.accountStatNumberFontSize,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingXxs),
                          const Icon(
                            Icons.star_rounded,
                            size: AppConstants.accountStatStarSize,
                            color: AppColors.textPrimary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingXxs),
                      Text(
                        ratingLabel,
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontSm,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(
    UserModel? user,
    String initials,
    String? accessToken,
  ) {
    // 1. Rendu instantané depuis la mémoire vive (0ms, zéro temps d'attente, 100% fluide)
    if (AuthRepository.cachedUserPhotoBytes != null &&
        AuthRepository.cachedUserPhotoBytes!.isNotEmpty) {
      return Image.memory(
        AuthRepository.cachedUserPhotoBytes!,
        fit: BoxFit.cover,
        width: AppConstants.accountAvatarSize,
        height: AppConstants.accountAvatarSize,
        gaplessPlayback: true,
      );
    }

    final photoUrl = user?.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      // 2. Si le chemin est un fichier local (ex: photo prise par caméra ou galerie)
      try {
        final localFile = File(photoUrl);
        if (localFile.existsSync()) {
          localFile.readAsBytes().then((bytes) {
            if (bytes.isNotEmpty) {
              AuthRepository.setUserPhotoBytes(bytes);
            }
          });
          return Image.file(
            localFile,
            fit: BoxFit.cover,
            width: AppConstants.accountAvatarSize,
            height: AppConstants.accountAvatarSize,
            gaplessPlayback: true,
          );
        }
      } catch (_) {}

      // 3. Préchargement silencieux en mémoire pour la prochaine ouverture
      if (AuthRepository.cachedUserPhotoBytes == null) {
        _authRepo.getUserPhotoBytes().then((bytes) {
          if (mounted && bytes != null && bytes.isNotEmpty) {
            setState(() {});
          }
        });
      }

      final isApiUrl = photoUrl.contains('/v1/users/');
      if (isApiUrl && (accessToken == null || accessToken.isEmpty)) {
        return _buildInitialsText(initials);
      }

      final fullUrl = photoUrl.startsWith('http')
          ? photoUrl
          : (photoUrl.startsWith('/')
              ? '${ApiEndpoints.baseUrl}$photoUrl'
              : '${ApiEndpoints.baseUrl}/$photoUrl');
      return Image.network(
        fullUrl,
        headers: accessToken != null && accessToken.isNotEmpty
            ? {'Authorization': 'Bearer $accessToken'}
            : null,
        fit: BoxFit.cover,
        width: AppConstants.accountAvatarSize,
        height: AppConstants.accountAvatarSize,
        gaplessPlayback: true,
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
        fontSize: AppConstants.iconSizeLg,
        fontWeight: FontWeight.w900,
        color: AppColors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildGroupedMenuCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(AppConstants.accountSectionCardRadius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSubtleBlack,
            blurRadius: AppConstants.accountSectionShadowBlur,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildStyledMenuItem({
    required BuildContext context,
    String? iconPath,
    Widget? iconWidget,
    Color iconBgColor = const Color(0xFFF3F4F6),
    Color iconColor = const Color(0xFF0F172A),
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.06),
        highlightColor: AppColors.primary.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingNine,
          ),
          child: Row(
            children: [
              Container(
                width: AppConstants.accountMenuIconCircleSize,
                height: AppConstants.accountMenuIconCircleSize,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: iconWidget ??
                    (iconPath != null
                        ? SvgPicture.asset(
                            iconPath,
                            width: AppConstants.accountMenuIconSize,
                            height: AppConstants.accountMenuIconSize,
                            colorFilter: ColorFilter.mode(
                              iconColor,
                              BlendMode.srcIn,
                            ),
                          )
                        : const SizedBox.shrink()),
              ),
              const SizedBox(width: AppConstants.spacingUnitLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontBase,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingTiny),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppConstants.spacingMd),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => _confirmLogout(context),
        splashColor: AppColors.sirenRed.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingNine,
          ),
          child: Row(
            children: [
              Container(
                width: AppConstants.accountMenuIconCircleSize,
                height: AppConstants.accountMenuIconCircleSize,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/logout-line-svgrepo-com.svg',
                  width: AppConstants.accountMenuIconSize,
                  height: AppConstants.accountMenuIconSize,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF0F172A),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitLg),
              Expanded(
                child: Text(
                  'drawer.logout'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontBase,
                    fontWeight: FontWeight.w800,
                    color: AppColors.sirenRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotificationsModal(
    BuildContext context,
    UserModel? user,
  ) async {
    final updated = await NotificationsModal.show(
      context,
      currentUser: user ?? _authRepo.currentUser,
    );
    if (mounted) {
      _accountBloc.add(DrawerAccountUserUpdated(updatedUser: updated));
    }
  }

  void _openLanguageSheet(BuildContext context) {
    LanguageModal.show(context);
  }

  void _confirmLogout(BuildContext context) {
    LogoutModal.show(context);
  }
}
