import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Modal moderne et élégant de partage de position inspiré de Yango
/// Permet de partager sa position exacte via WhatsApp, SMS, copie de lien
/// ou toute autre application grâce au menu de partage système natif.
class SeddoSharePositionSheet extends StatelessWidget {
  final LatLng location;
  final String mainAddress;
  final String secondaryAddress;

  const SeddoSharePositionSheet({
    super.key,
    required this.location,
    required this.mainAddress,
    required this.secondaryAddress,
  });

  /// URL de partage au format Seddo (similaire à Yango)
  String get shareUrl {
    final lat = location.latitude.toStringAsFixed(5);
    final lon = location.longitude.toStringAsFixed(5);
    return 'https://seddo.sn/ride?end-lon=$lon&end-lat=$lat';
  }

  /// Message complet prêt à être partagé (style identique à Yango)
  String get shareMessage {
    return 'Un moyen simple pour me rejoindre avec Seddo. Appuie sur le lien pour commander une course vers ma position. $shareUrl';
  }

  static Future<void> show(
    BuildContext context, {
    required LatLng location,
    required String mainAddress,
    required String secondaryAddress,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => SeddoSharePositionSheet(
        location: location,
        mainAddress: mainAddress,
        secondaryAddress: secondaryAddress,
      ),
    );
  }

  Future<void> _shareToWhatsApp(BuildContext context) async {
    final text = Uri.encodeComponent(shareMessage);
    final appUri = Uri.parse('whatsapp://send?text=$text');
    final webUri = Uri.parse('https://wa.me/?text=$text');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      SharePlus.instance.share(ShareParams(text: shareMessage));
    }
  }

  Future<void> _shareToSms() async {
    final text = Uri.encodeComponent(shareMessage);
    final uri = Uri.parse('sms:?body=$text');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}
    SharePlus.instance.share(ShareParams(text: shareMessage));
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: shareMessage));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lien copié dans le presse-papiers !'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareSystem() {
    SharePlus.instance.share(ShareParams(text: shareMessage));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            12,
            AppConstants.spacingLg,
            bottomPadding > 0 ? 12 : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Barre de glissement
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.dragHandle,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. En-tête : Titre & Fermeture
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Partager votre position',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.grayBgLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textLabelGrey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'La personne n\'aura qu\'à cliquer sur le lien pour commander une course vers votre position.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // 3. Carte d'aperçu de partage Seddo (inspirée de l'aperçu Yango)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.topDownEcoBody, AppColors.carRoofGradientMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowCardBlack,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo carré Seddo (style Yango rouge, ici orange Seddo éclatant)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'SEDDO',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seddo',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Course rapide et sécurisée',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Destination et adresse
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mainAddress,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Lien cliquable
                    Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 14,
                          color: AppColors.textMutedGrey,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'seddo.sn/ride',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMutedGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Canaux de partage rapide
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // WhatsApp
                  _buildShareChannelButton(
                    customIcon: SvgPicture.asset(
                      'assets/icons/whatsapp-icon-logo-svgrepo-com.svg',
                      width: 28,
                      height: 28,
                    ),
                    label: 'WhatsApp',
                    onTap: () => _shareToWhatsApp(context),
                  ),

                  // SMS
                  _buildShareChannelButton(
                    customIcon: SvgPicture.asset(
                      'assets/icons/chat-round-svgrepo-com.svg',
                      width: 26,
                      height: 26,
                      colorFilter: const ColorFilter.mode(
                        AppColors.blueHighlightText,
                        BlendMode.srcIn,
                      ),
                    ),
                    bgColor: AppColors.blueHighlightBg,
                    label: 'SMS',
                    onTap: _shareToSms,
                  ),

                  // Copier le lien
                  _buildShareChannelButton(
                    icon: Icons.copy_rounded,
                    iconColor: AppColors.textLabelGrey,
                    bgColor: AppColors.grayBgLight,
                    label: 'Copier',
                    onTap: () => _copyLink(context),
                  ),

                  // Autres applications
                  _buildShareChannelButton(
                    customIcon: SvgPicture.asset(
                      'assets/icons/share-svgrepo-com.svg',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                    bgColor: AppColors.primary.withValues(alpha: 0.12),
                    label: 'Autres',
                    onTap: _shareSystem,
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // 5. Bouton principal "Partager maintenant"
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _shareSystem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/share-svgrepo-com.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Partager maintenant',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
    );
  }

  Widget _buildShareChannelButton({
    IconData? icon,
    Widget? customIcon,
    Color? iconColor,
    Color? bgColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor ?? AppColors.grayBgSubtle,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: customIcon ??
                Icon(
                  icon,
                  color: iconColor ?? AppColors.textPrimary,
                  size: 26,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
