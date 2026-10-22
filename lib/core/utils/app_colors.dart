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

  // Centralized Theme & UI Tokens (Innov & Impact Africa Guidelines)
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateBorder = Color(0xFFE2E8F0);
  static const Color slateLightBg = Color(0xFFF1F5F9);
  static const Color slateMuted = Color(0xFF6B7280);
  static const Color offlineDark = Color(0xFF141414);
  static const Color grayBorderLight = Color(0xFFEAECF0);
  static const Color grayBorderMedium = Color(0xFFD1D5DB);
  static const Color grayBorderDivider = Color(0xFFE5E7EB);
  static const Color grayBgSubtle = Color(0xFFF9FAFB);
  static const Color grayBgLight = Color(0xFFF3F4F6);
  static const Color peachLight = Color(0xFFFFF2E8);
  static const Color peachMedium = Color(0xFFFFEDD5);
  static const Color peachDeep = Color(0xFFFFDFC8);
  static const Color peachBorder = Color(0xFFFFD9C2);
  static const Color orangeLightBg = Color(0xFFFFF7ED);
  static const Color orangeSubtleBg = Color(0xFFFFF4EC);
  static const Color orangeAccent = Color(0xFFFF7A00);
  static const Color orangeDarkAccent = Color(0xFFEA580C);
  static const Color orangeVibrant = Color(0xFFFF5722);
  static const Color amberRating = Color(0xFFFF9500);
  static const Color avatarLightBeige = Color(0xFFE2DBD3);
  static const Color buttonSecondaryBeige = Color(0xFFF4F1EA);
  static const Color pureBlack = Color(0xFF000000);
  static const Color black38 = Color(0x61000000);
  static const Color errorLightBg = Color(0xFFFFECEC);
  static const Color errorRed = Color(0xFFE53935);
  static const Color darkMarker = Color(0xFF1E1E1E);
  static const Color silverMarker = Color(0xFFC0C0C0);
  static const Color headlightMarker = Color(0xFFFFF9D2);
  static const Color darkMirror = Color(0xFF2C2C2E);
  static const Color taillightMarker = Color(0xFFFF3B30);

  // Drawer & Navigation tokens
  static const Color drawerDark = Color(0xFF161616);
  static const Color drawerCardBorder = Color(0xFF282828);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color greenSuccess = Color(0xFF16A34A);
  static const Color skyBlue = Color(0xFF0284C7);
  static const Color waveBlue = Color(0xFF00B2FE);

  // Emergency & Safety modal tokens
  static const Color emergencyAlertBg = Color(0xFFFFF7F0);
  static const Color emergencyAlertBorder = Color(0xFFFFD8B2);
  static const Color emergencyAlertText = Color(0xFF7A3500);
  static const Color policeBadgeBg = Color(0xFFEBF5FF);
  static const Color policeBadgeIcon = Color(0xFF1E40AF);
  static const Color sirenLightBg = Color(0xFFFEF2F2);
  static const Color hospitalBadgeBg = Color(0xFFECFDF5);
  static const Color hospitalBadgeIcon = Color(0xFF059669);
  static const Color contactBadgeBg = Color(0xFFF3E8FF);
  static const Color contactBadgeIcon = Color(0xFF7E22CE);
  static const Color safetyCardBg = Color(0xFFF7F8FA);

  // Map Marker Canvas tokens
  static const Color shadowCarCanvas = Color(0x55000000);
  static const Color carRoofGradientStart = Color(0xFF3A3A3C);
  static const Color carRoofGradientMid = Color(0xFF1C1C1E);
  static const Color carRoofGradientEnd = Color(0xFF0D0D0E);
  static const Color carGrilleDark = Color(0xFF111111);
  static const Color windshieldBlueStart = Color(0xFF64D2FF);
  static const Color windshieldBlueMid = Color(0xFF0A2E4C);
  static const Color shadowCanvasMedium = Color(0x44000000);
  static const Color orangeDarkPin = Color(0xFFD64400);
  static const Color pinDarkGradientStart = Color(0xFF333333);
  static const Color shadowCanvasSoft = Color(0x30000000);

  // Rating Illustration & Avatar tokens
  static const Color avatarCollar = Color(0xFFE64A19);
  static const Color avatarSkin = Color(0xFFA66038);
  static const Color avatarHair = Color(0xFF33180D);
  static const Color avatarBgTop = Color(0xFFFFEAD8);
  static const Color avatarWaveLight = Color(0xFFFF8A3D);
  static const Color badgePeachBorder = Color(0xFFFFEEDD);
  static const Color badgePeachFill = Color(0xFFFFE5D3);
  static const Color avatarCircleBg = Color(0xFFFFE8D6);
  static const Color orangeVibrantGlow = Color(0x66FF5722);
  static const Color orangeVibrantShadow = Color(0x4DFF5722);

  // Consent modal tokens
  static const Color consentButtonDisabled = Color(0xFFFFB59A);

  // Receipt & Help Flow tokens
  static const Color receiptPaidBadgeBg = Color(0xFFD1FAE5);
  static const Color receiptPaidBadgeText = Color(0xFF059669);
  static const Color receiptDeparturePin = Color(0xFF1E293B);
  static const Color receiptArrivalPin = Color(0xFFFB5B00);
  static const Color receiptRouteLine = Color(0xFF1E293B);
  static const Color supportTagBorder = Color(0xFFE5E7EB);

  // Public Transport (TCU) tokens
  static const Color tcuDddGreen = Color(0xFF10B981);
  static const Color tcuAftuBlue = Color(0xFF1D4ED8);
  static const Color tcuBrtOrange = Color(0xFFF59E0B);
  static const Color tcuTerPurple = Color(0xFF6B21A8);
  static const Color tcuTimelineTrack = Color(0xFFD1D5DB);
  static const Color tcuWalkingDot = Color(0xFFEA580C);
  static const Color tcuStopPin = Color(0xFF1E3A8A);
  static const Color tcuStatCardBg = Color(0xFFF4F4F5);
  static const Color tcuDurationGreen = Color(0xFF10B981);
  static const Color tcuFieldBorder = Color(0xFFE5E7EB);
}
