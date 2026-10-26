import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:seddo/core/localization/wolof_localizations_delegate.dart';
import 'package:seddo/core/themes/app_theme.dart';
import 'package:seddo/features/splash/presentation/pages/splash_page.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:seddo/firebase_options.dart';
import 'package:seddo/services/fcm_service.dart';
import 'package:seddo/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await NotificationService().initialize();

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
