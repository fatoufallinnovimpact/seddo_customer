import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/localization/wolof_localizations_delegate.dart';
import 'package:seddo/core/themes/app_theme.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/splash/presentation/pages/splash_page.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:seddo/firebase_options.dart';
import 'package:seddo/services/fcm_service.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Intercepte et affiche clairement toutes les erreurs Flutter au lieu de planter l'appli
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    debugPrint('[CRITICAL BUILD ERROR] ${errorDetails.exceptionAsString()}');
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingTwenty),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.primary,
                    size: 56,
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  Text(
                    'Une erreur d\'affichage est survenue',
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontLg,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  Text(
                    errorDetails.exceptionAsString(),
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontSm,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  await EasyLocalization.ensureInitialized();
  await NotificationService().initialize();
  await MapStyleService.loadMapStyle();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FcmService().init();
  } catch (e) {
    debugPrint('[Firebase] Initialisation reportée: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fr'),
        Locale('wo'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      startLocale: const Locale('fr'),
      child: const SeddoApp(),
    ),
  );
}

class SeddoApp extends StatelessWidget {
  const SeddoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seddo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: [
        const WolofMaterialLocalizationsDelegate(),
        const WolofCupertinoLocalizationsDelegate(),
        ...context.localizationDelegates,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const SplashPage(),
    );
  }
}

