import 'package:flutter/material.dart';

/// Centralized color palette for the Seddo application.
/// Follows Innov & Impact Africa coding guidelines (placed in core/utils/app_colors.dart).
abstract class AppColors {
  // Brand / Primary Colors
  /// Orange Seddo (primaire) - #FB5B00 (exact reference orange)
  /// Usage: Boutons principaux, marqueur de destination, en-têtes
  static const Color primary = Color(0xFFFB5B00);

  /// Orange foncé - #CC4C00
  /// Usage: États pressés, texte orange sur fond blanc (contraste)
  static const Color primaryDark = Color(0xFFCC4C00);

  // Text Colors
  /// Noir texte - #1A1A1A
  /// Usage: Titres et textes principaux, bouton noir principal
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// Gris texte secondaire - #8A8A8A
  /// Usage: Textes secondaires, sous-titres, placeholders
  static const Color textSecondary = Color(0xFF8A8A8A);

  // Surface & Background Colors
  /// Gris interface - #F2F2F2
  /// Usage: Fonds de cartes, arrière-plans légers
  static const Color surfaceGrey = Color(0xFFF2F2F2);
  static const Color cardBackground = Color(0xFFF2F2F2);

  /// Pure white
  static const Color white = Color(0xFFFFFFFF);

  /// Semi-transparent whites for overlays & subtitles on orange background
  static const Color white90 = Color(0xE6FFFFFF);
  static const Color white80 = Color(0xCCFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white25 = Color(0x40FFFFFF);
  static const Color white20 = Color(0x33FFFFFF);

  /// Transparent
  static const Color transparent = Colors.transparent;

  /// Main black button color - #111111
  static const Color buttonBlack = Color(0xFF111111);

  /// Disabled primary button background
  static const Color buttonDisabled = Color(0x66FB5B00);

  /// Auth and OTP input colors
  static const Color inputBackground = Color(0xFFF2F2F2);
  static const Color otpBoxFilled = Color(0xFF111111);
  static const Color otpBoxEmpty = Color(0xFFF2F2F2);
  static const Color shadowLight = Color(0x14000000);

  /// Language selector pill container background
  static const Color languageContainerBackground = Color(0x33FFFFFF);
  static const Color languageContainerBorder = Color(0x26FFFFFF);

  /// Decorative background contour rings
  static const Color decorativeArc = Color(0x1AFFFFFF);

  /// Onboarding scene illustration colors (Vector skyline, pin & road)
  static const Color skylineSilhouette = Color(0xFF8A2500);
  static const Color pinFill = Color(0x66FFFFFF);
  static const Color pinBorder = Color(0x8AFFFFFF);
  static const Color roadCurve = Color(0xB3FFFFFF);

  /// Border and divider color
  static const Color border = Color(0xFFE5E5E5);

  /// Home design specific card & container colors (matching new mockup)
  /// Soft peach circular container for Almadies home icon
  static const Color peachContainer = Color(0xFFFFF0E6);

  /// Soft grey/slate circular container for Travail briefcase icon
  static const Color greyContainer = Color(0xFFF2F4F7);

  /// Soft subtle card border
  static const Color cardBorder = Color(0xFFEEEEEE);

  /// Subtle divider line
  static const Color divider = Color(0xFFEEEEEE);

  /// Subtle card shadow
  static const Color cardShadow = Color(0x0D000000);

  /// Eco card selected subtle background tint
  static const Color ecoCardSelectedBackground = Color(0xFFFFF9F5);

  /// Unread notification dot badge
  static const Color unreadDot = Color(0xFFFF5F00);

  /// Inactive indicator dot color
  static const Color inactiveIndicator = Color(0xFFD4D4D4);

  // Feedback & Status Colors
  /// Vert succès - #1E9E5A
  /// Usage: Paiement confirmé, chauffeur en ligne, succès
  static const Color success = Color(0xFF1E9E5A);

  /// Tracé d'itinéraire style Yango - Vert dynamique #00C853
  static const Color yangoRouteGreen = Color(0xFF00C853);

  /// Tracé d'itinéraire déjà parcouru - Gris discret #BDBDBD
  static const Color routeTraveled = Color(0xFFBDBDBD);

  /// Rouge alerte - #D93025
  /// Usage: Erreurs, SOS, alertes critiques
  static const Color alert = Color(0xFFD93025);
  static const Color error = Color(0xFFD93025);

  // Car Animation Colors
  static const Color carBody = Color(0xFFFFFFFF);
  static const Color carShadow = Color(0x26000000);
  static const Color carWheel = Color(0xFF1A1A1A);
  static const Color carWheelRim = Color(0xFF9CA3AF);
  static const Color carWindow = Color(0xFFE0E7FF);
  static const Color carHeadlight = Color(0xFFFEF08A);
  static const Color carTaillight = Color(0xFFEF4444);

  // Surface tints & warm backgrounds
  static const Color warmCream = Color(0xFFF7F5F0);
  static const Color bannerGradientStart = Color(0xFFFFF5EE);
  static const Color bannerGradientEnd = Color(0xFFF9F5EC);
  static const Color fieldBackground = Color(0xFFF7F7F7);
  static const Color chipBackground = Color(0xFFF2F2F2);
  static const Color addressCardBg = Color(0xFFFBF8F4);
  static const Color iconCircleBg = Color(0xFFF3F3F3);
  static const Color dragHandle = Color(0xFFE2E2E2);
  static const Color mapPinAnchor = Color(0xFF161616);
  static const Color textMuted = Color(0xFF757575);
  static const Color deleteRed = Color(0xFFD32F2F);

  // Saved place category badges & icons
  static const Color savedPlaceHomeBg = Color(0xFFFFECE5);
  static const Color savedPlaceWorkBg = Color(0xFFF1F1F1);
  static const Color savedPlaceStarBg = Color(0xFFFFF7D6);
  static const Color savedPlaceAirportBg = Color(0xFFE5F4FF);
  static const Color savedPlaceAirportIcon = Color(0xFF0288D1);
  static const Color savedPlaceHeartBg = Color(0xFFFFE6EB);
  static const Color savedPlaceHeartIcon = Color(0xFFE91E63);
  static const Color savedPlaceGymBg = Color(0xFFE6F7EC);
  static const Color savedPlaceGymIcon = Color(0xFF2E7D32);

  // Map pin & helper colors
  static const Color mapCarWindow = Color(0xFFC7D2FE);
  static const Color mapCarRoof = Color(0xFF262626);
  static const Color mapCarLight = Color(0xFFFFFBEB);

  // Orange Money & Payment Flow tokens
  static const Color orangeMoneyOrange = Color(0xFFFF6600);
  static const Color walletContainerBg = Color(0xFFFFECEB);
  static const Color walletIconColor = Color(0xFFE53935);
  static const Color cancelSecondaryBtnBg = Color(0xFFF3F1ED);
  static const Color refundContainerBg = Color(0xFFE8F8F0);
  static const Color refundGreen = Color(0xFF1E8E4D);
  static const Color refundPillBg = Color(0xFFE8F8F0);
  static const Color radarRingColor = Color(0x4DFB5B00);
  static const Color radarFillColor = Color(0x0FFB5B00);
  static const Color licensePlateBg = Color(0xFF1E293B);
  static const Color chatBubbleCustomer = Color(0xFFFB5B00);
  static const Color chatBubbleDriver = Color(0xFFF2F4F7);

  // Active Ride & Safety & Rating tokens
  static const Color sirenRed = Color(0xFFDC2626);
  static const Color avatarBeige = Color(0xFFEBE5DF);
  static const Color paidBadgeBg = Color(0xFFFFEDE0);
  static const Color paidBadgeText = Color(0xFFB45309);
  static const Color starGold = Color(0xFFFFB800);
  static const Color tagChipBg = Color(0xFFF3F1ED);
  static const Color tagChipSelectedBg = Color(0xFF1E1E1E);
  static const Color tagChipSelectedText = Color(0xFFFFFFFF);
  static const Color liveStatusBg = Color(0xFFE8F8F0);
  static const Color liveStatusText = Color(0xFF00C853);

  // Shadows
  static const Color shadowSubtleBlack = Color(0x0C000000);
  static const Color shadowSoftBlack = Color(0x0F000000);
  static const Color shadowCardBlack = Color(0x14000000);
  static const Color shadowDarkBlack = Color(0x18000000);
  static const Color shadowMarker = Color(0x1F000000);
  static const Color shadowHeavy = Color(0x33000000);
  static const Color shadowPinBox = Color(0x3D000000);
}
