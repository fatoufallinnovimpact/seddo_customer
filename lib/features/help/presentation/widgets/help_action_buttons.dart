import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpActionButtons extends StatelessWidget {
  const HelpActionButtons({super.key});

  static const String _whatsappSvg =
      'assets/icons/whatsapp-icon-logo-svgrepo-com.svg';
  static const String _phoneCallSvg =
      'assets/icons/telephone-call-svgrepo-com.svg';

  Future<void> _openWhatsApp() async {
    final cleanPhone = AppConstants.helpSupportWhatsAppNumber
        .replaceAll('+', '')
        .replaceAll(' ', '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makeCall() async {
    final uri = Uri.parse('tel:${AppConstants.helpSupportPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // WhatsApp Card
        Expanded(
          child: _buildActionCard(
            svgPath: _whatsappSvg,
            badgeText: 'help.whatsapp_sub'.tr(),
            title: 'help.whatsapp'.tr(),
            isWhatsApp: true,
            onTap: _openWhatsApp,
          ),
        ),
        const SizedBox(width: 14),
        // Telephone Call Card
        Expanded(
          child: _buildActionCard(
            svgPath: _phoneCallSvg,
            badgeText: 'help.call_sub'.tr(),
            title: 'help.call'.tr(),
            isWhatsApp: false,
            onTap: _makeCall,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String svgPath,
    required String badgeText,
    required String title,
    required VoidCallback onTap,
    bool isWhatsApp = false,
  }) {
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icône d'action : couleur de base pour WhatsApp, noir sobre pour Appeler
                    Container(
                      width: 42,
                      height: 42,
                      padding: EdgeInsets.all(isWhatsApp ? 7.5 : 9),
                      decoration: BoxDecoration(
                        color: isWhatsApp
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: SvgPicture.asset(
                        svgPath,
                        fit: BoxFit.contain,
                        colorFilter: isWhatsApp
                            ? null
                            : const ColorFilter.mode(
                                Color(0xFF0F172A),
                                BlendMode.srcIn,
                              ),
                      ),
                    ),
                    // Badge sans contour
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.5,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isWhatsApp
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isWhatsApp
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
