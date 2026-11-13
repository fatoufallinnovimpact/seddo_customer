import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';

/// Screen allowing the user to view and edit their profile:
/// - First name & Last name
/// - Profile photo via PUT /v1/users/me/photo (and displaying with GET /v1/users/me/photo)
/// - Notification preferences (push and SMS On/Off switches via PATCH /v1/users/me)
/// Language is intentionally excluded as it is managed directly via the burger menu.
class EditProfilePage extends StatefulWidget {
  final UserModel? currentUser;

  const EditProfilePage({
    super.key,
    this.currentUser,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final AuthRepository _authRepo = AuthRepository();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;

  late UserModel _user;
  String? _accessToken;
  bool _notifyPush = true;
  bool _notifySms = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  File? _localPickedPhoto;
  int _photoVersion = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser ??
        _authRepo.currentUser ??
        const UserModel(id: '', phone: '');

    _firstNameController = TextEditingController(text: _user.firstName ?? '');
    _lastNameController = TextEditingController(text: _user.lastName ?? '');
    _notifyPush = _user.notifyPush;
    _notifySms = _user.notifySms;

    _loadTokenAndLatestProfile();
  }

  Future<void> _loadTokenAndLatestProfile() async {
    final token = await _authRepo.getAccessToken();
    if (mounted && token != null) {
      setState(() {
        _accessToken = token;
      });
    }

    final latest = await _authRepo.fetchUserProfile();
    if (mounted && latest != null) {
      setState(() {
        _user = latest;
        if (_firstNameController.text.trim().isEmpty && latest.firstName != null) {
          _firstNameController.text = latest.firstName!;
        }
        if (_lastNameController.text.trim().isEmpty && latest.lastName != null) {
          _lastNameController.text = latest.lastName!;
        }
        _notifyPush = latest.notifyPush;
        _notifySms = latest.notifySms;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked == null || !mounted) return;

      setState(() {
        _localPickedPhoto = File(picked.path);
        _isUploadingPhoto = true;
      });

      final updated = await _authRepo.uploadProfilePhoto(picked.path);
      if (mounted) {
        setState(() {
          _user = updated;
          _isUploadingPhoto = false;
          _photoVersion = DateTime.now().millisecondsSinceEpoch;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo de profil mise à jour avec succès'.tr()),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement de la photo: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Photo de profil'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ListTile(
                    key: const Key('edit_photo_camera'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGrey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, color: AppColors.textPrimary),
                    ),
                    title: Text(
                      'Prendre une photo'.tr(),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickAndUploadPhoto(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    key: const Key('edit_photo_gallery'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGrey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_library_rounded, color: AppColors.textPrimary),
                    ),
                    title: Text(
                      'Choisir depuis la galerie'.tr(),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickAndUploadPhoto(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();

    if (first.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir votre prénom'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await _authRepo.updateProfile(
        firstName: first,
        lastName: last,
        notifyPush: _notifyPush,
        notifySms: _notifySms,
      );

      if (mounted) {
        setState(() {
          _user = updated;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pop(updated);
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
    final initials = (_user.initials.isNotEmpty && _user.initials != 'SD')
        ? _user.initials
        : (_firstNameController.text.trim().isNotEmpty
            ? _firstNameController.text.trim().substring(0, _firstNameController.text.trim().length >= 2 ? 2 : 1).toUpperCase()
            : 'SD');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          key: const Key('edit_profile_back_button'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Modifier mon profil',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Avatar Section
            _buildAvatarSection(initials),
            const SizedBox(height: 28),

            // 2. Personal Information Section
            _buildSectionCard(
              title: 'Informations personnelles',
              icon: Icons.person_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('Prénom'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    key: const Key('edit_profile_firstname_field'),
                    controller: _firstNameController,
                    hint: 'Ex: Fatou',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildInputLabel('Nom'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    key: const Key('edit_profile_lastname_field'),
                    controller: _lastNameController,
                    hint: 'Ex: Fall',
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildInputLabel('Numéro de téléphone'),
                  const SizedBox(height: 6),
                  _buildReadOnlyPhoneField(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Notification Preferences Section
            _buildSectionCard(
              title: 'Préférences de notification',
              icon: Icons.notifications_active_rounded,
              child: Column(
                children: [
                  _buildSwitchTile(
                    key: const Key('edit_profile_push_switch'),
                    title: 'Notifications push',
                    subtitle: 'Alertes en direct lors des courses et messages',
                    value: _notifyPush,
                    onChanged: (val) => setState(() => _notifyPush = val),
                    icon: Icons.notifications_none_rounded,
                  ),
                  const Divider(height: 20, thickness: 0.8, color: Color(0xFFECEEF2)),
                  _buildSwitchTile(
                    key: const Key('edit_profile_sms_switch'),
                    title: 'SMS de secours',
                    subtitle: 'Recevoir un SMS en cas de perte de connexion réseau',
                    value: _notifySms,
                    onChanged: (val) => setState(() => _notifySms = val),
                    icon: Icons.sms_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 4. Save Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                key: const Key('edit_profile_save_button'),
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Enregistrer les modifications',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(String initials) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            key: const Key('edit_profile_avatar_button'),
            onTap: _showPhotoOptions,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: _isUploadingPhoto
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : _buildAvatarContent(initials),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(String initials) {
    if (_localPickedPhoto != null) {
      return Image.file(
        _localPickedPhoto!,
        fit: BoxFit.cover,
        width: 96,
        height: 96,
      );
    }

    final explicitUrl = _user.photoUrl;
    if (explicitUrl != null && explicitUrl.isNotEmpty) {
      final basePhotoUrl = explicitUrl.startsWith('http')
          ? explicitUrl
          : (explicitUrl.startsWith('/')
              ? '${ApiEndpoints.baseUrl}$explicitUrl'
              : '${ApiEndpoints.baseUrl}/$explicitUrl');
      final photoUrlToLoad = '$basePhotoUrl?t=$_photoVersion';

      return Image.network(
        photoUrlToLoad,
        headers: _accessToken != null ? {'Authorization': 'Bearer $_accessToken'} : null,
        fit: BoxFit.cover,
        width: 96,
        height: 96,
        errorBuilder: (context, error, stackTrace) => _buildInitialsText(initials),
      );
    }

    return _buildInitialsText(initials);
  }

  Widget _buildInitialsText(String initials) {
    return Text(
      initials,
      style: GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        key: key,
        controller: controller,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF9CA3AF),
          ),
          prefixIcon: Icon(prefixIcon, color: AppColors.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildReadOnlyPhoneField() {
    final phoneText = _user.formattedDisplayPhone.isNotEmpty
        ? _user.formattedDisplayPhone
        : (_user.formattedNationalPhone.isNotEmpty ? _user.formattedNationalPhone : _user.phone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_outlined, color: Color(0xFF6B7280), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              phoneText.isNotEmpty ? phoneText : 'Numéro non renseigné',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563),
              ),
            ),
          ),
          const Icon(Icons.lock_outline_rounded, color: Color(0xFF9CA3AF), size: 16),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
