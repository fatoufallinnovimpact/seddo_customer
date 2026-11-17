import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';

/// Modal bottom sheet for managing Notification Preferences:
/// - Displays the exact notification preferences card ("Préférences de notification")
///   that was previously at the bottom of EditProfilePage:
///   * Notifications push ("Alertes en direct lors des courses et messages")
///   * SMS de secours ("Recevoir un SMS en cas de perte de connexion réseau")
/// - Connected directly to PATCH /v1/users/me (and GET /v1/users/me) via AuthRepository.
class NotificationsModal extends StatefulWidget {
  final UserModel? initialUser;

  const NotificationsModal({
    super.key,
    this.initialUser,
  });

  static Future<UserModel?> show(
    BuildContext context, {
    UserModel? currentUser,
  }) {
    return showModalBottomSheet<UserModel?>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => NotificationsModal(
        initialUser: currentUser,
      ),
    );
  }

  @override
  State<NotificationsModal> createState() => _NotificationsModalState();
}

class _NotificationsModalState extends State<NotificationsModal> {
  final AuthRepository _authRepo = AuthRepository();

  late UserModel _user;
  late bool _notifyPush;
  late bool _notifySms;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser ??
        _authRepo.currentUser ??
        const UserModel(id: '', phone: '');
    _notifyPush = _user.notifyPush;
    _notifySms = _user.notifySms;

    _loadLatestPreferences();
  }

  Future<void> _loadLatestPreferences() async {
    final cached = await _authRepo.getCachedUser();
    if (mounted && cached != null) {
      setState(() {
        _user = cached;
        _notifyPush = cached.notifyPush;
        _notifySms = cached.notifySms;
      });
    }

    final remote = await _authRepo.fetchUserProfile();
    if (mounted && remote != null) {
      setState(() {
        _user = remote;
        _notifyPush = remote.notifyPush;
        _notifySms = remote.notifySms;
      });
    }
  }

  Future<void> _updatePreference({
    bool? notifyPush,
    bool? notifySms,
  }) async {
    final nextPush = notifyPush ?? _notifyPush;
    final nextSms = notifySms ?? _notifySms;

    setState(() {
      _notifyPush = nextPush;
      _notifySms = nextSms;
      _isSaving = true;
    });

    try {
      final updated = await _authRepo.updateProfile(
        notifyPush: nextPush,
        notifySms: nextSms,
      );
      if (mounted) {
        setState(() {
          _user = updated;
          _notifyPush = updated.notifyPush;
          _notifySms = updated.notifySms;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de mise à jour: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusTwentyFour),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.modalShadow,
            blurRadius: AppConstants.radiusSheet,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingTwenty,
        AppConstants.spacingUnitXl,
        AppConstants.spacingTwenty,
        bottomPadding > 0
            ? bottomPadding + AppConstants.spacingMd
            : AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: AppConstants.handleWidth,
              height: AppConstants.handleHeight,
              decoration: BoxDecoration(
                color: AppColors.grayBorderDivider,
                borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Header: Icon + "Préférences de notification" + Close button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  size: AppConstants.iconSizeDefault,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnit),
              Expanded(
                child: Text(
                  'Préférences de notification',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontLg,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.only(right: AppConstants.spacingSm),
                  child: SizedBox(
                    width: AppConstants.iconSizeSm,
                    height: AppConstants.iconSizeSm,
                    child: CircularProgressIndicator(
                      strokeWidth: AppConstants.spacingXxs,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                key: const Key('notifications_modal_close_button'),
                onTap: () => Navigator.of(context).pop(_user),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spacingXs),
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textPrimary,
                    size: AppConstants.iconSizeLg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Switch 1: Notifications push
          _buildSwitchTile(
            key: const Key('notifications_modal_push_switch'),
            title: 'Notifications push',
            subtitle: 'Alertes en direct lors des courses et messages',
            value: _notifyPush,
            onChanged: (val) => _updatePreference(notifyPush: val),
            icon: Icons.notifications_none_rounded,
          ),
          const Divider(
            height: AppConstants.spacingTwenty,
            thickness: AppConstants.spacingTiny,
            color: AppColors.subtleDivider,
          ),

          // Switch 2: SMS de secours
          _buildSwitchTile(
            key: const Key('notifications_modal_sms_switch'),
            title: 'SMS de secours',
            subtitle: 'Recevoir un SMS en cas de perte de connexion réseau',
            value: _notifySms,
            onChanged: (val) => _updatePreference(notifySms: val),
            icon: Icons.sms_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required Key key,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingSm),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(AppConstants.radiusItem),
            ),
            child: Icon(
              icon,
              size: AppConstants.iconSizeMd,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppConstants.spacingUnitXl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontBase,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXxs),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Switch.adaptive(
            key: key,
            value: value,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
