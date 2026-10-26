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
            badgeBgColor: const Color(0xFFF0FDF4),
            badgeTextColor: const Color(0xFF16A34A),
            badgeBorderColor: const Color(0xFFDCFCE7),
            title: 'help.whatsapp'.tr(),
            iconContainerBg: const Color(0xFFF0FDF4),
            iconContainerBorder: const Color(0xFFDCFCE7),
            onTap: _openWhatsApp,
          ),
        ),
        const SizedBox(width: 14),
        // Telephone Call Card
        Expanded(
          child: _buildActionCard(
            svgPath: _phoneCallSvg,
            badgeText: 'help.call_sub'.tr(),
            badgeBgColor: const Color(0xFFFFF7ED),
            badgeTextColor: const Color(0xFFEA580C),
            badgeBorderColor: const Color(0xFFFFEDD5),
            title: 'help.call'.tr(),
            iconContainerBg: const Color(0xFFFFF7ED),
            iconContainerBorder: const Color(0xFFFFEDD5),
            onTap: _makeCall,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String svgPath,
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required Color badgeBorderColor,
    required String title,
    required Color iconContainerBg,
    required Color iconContainerBorder,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: iconContainerBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: iconContainerBorder,
                          width: 1,
                        ),
                      ),
                      child: SvgPicture.asset(
                        svgPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: badgeBorderColor,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
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
