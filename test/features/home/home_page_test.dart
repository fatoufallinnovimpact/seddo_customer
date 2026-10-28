import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/core/localization/wolof_localizations_delegate.dart';
import 'package:seddo/features/home/presentation/pages/home_page.dart';

class MockHomeTestAssetLoader extends AssetLoader {
  const MockHomeTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'app_name': 'Seddo',
      'home': {
        'where_to': 'Où allez-vous ?',
        'where_to_sub': 'Entrez votre destination',
        'recent_places': 'Mes récentes courses',
        'almadies': 'Les Almadies',
        'almadies_sub': 'Route des Almadies, Dakar',
        'work': 'Travail',
        'work_sub': 'Plateau, rue Carnot, Dakar',
        'suggestions': 'Suggestions',
        'seddo_eco': 'Seddo Eco',
        'eco_sub': 'Économique',
        'confort': 'Confort',
        'confort_sub': 'Plus d’espace',
        'airport': 'Aéroport',
        'airport_sub': 'AIBD direct',
        'tcu': 'TCU',
        'tcu_sub': 'Bus, BRT & TER',
        'drivers_around': '{} chauffeurs autour · {} min',
      },
      'drawer': {
        'activity': 'Activité',
        'activity_sub': 'Courses et remboursements',
        'payment': 'Paiement',
        'saved_places': 'Lieux enregistrés',
        'saved_places_sub': 'Gérer vos adresses',
        'safety': 'Sécurité',
        'safety_sub': 'Assistance et urgence',
        'language': 'Langue',
        'help': 'Aide',
        'help_sub': 'Support client',
        'privacy': 'Confidentialité',
        'privacy_sub': 'Données et mentions légales',
        'logout': 'Déconnexion',
        'tcu': 'TCU',
        'tcu_sub': 'Bus, BRT et TER',
      },
      'common': {
        'french': 'Français',
        'wolof': 'Wolof',
      },
    };
  }
}

Widget createHomeScreen() {
  return EasyLocalization(
    supportedLocales: const [Locale('fr'), Locale('wo')],
    path: 'assets/translations',
    fallbackLocale: const Locale('fr'),
    startLocale: const Locale('fr'),
    assetLoader: const MockHomeTestAssetLoader(),
    child: Builder(
      builder: (context) {
        return MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: [
            const WolofMaterialLocalizationsDelegate(),
            const WolofCupertinoLocalizationsDelegate(),
            ...context.localizationDelegates,
          ],
          home: const HomePage(),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets(
      'HomePage renders top bar with SEDDO logo & address, no bottom GoogleMap, and offer cards carousel',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(milliseconds: 600));

    // 1. GoogleMap is removed from HomePage per user request
    expect(find.byType(GoogleMap), findsNothing);

    // 2. Top bar elements
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.text('SEDDO'), findsOneWidget);
    expect(find.text('Rue YF-557, 20'), findsOneWidget);

    // 3. Search Bar
    expect(find.text('Où allez-vous ?'), findsOneWidget);

    // 4. Initial Card: Seddo Eco
    expect(find.text('ÉCONOMIQUE'), findsOneWidget);
    expect(find.text('Seddo Eco'), findsOneWidget);
    expect(find.text('Arrive dans 2 min'), findsOneWidget);

    // 5. Swipe PageView to Confort
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("PLUS D'ESPACE"), findsOneWidget);
    expect(find.text('Seddo Confort'), findsOneWidget);
    expect(find.text('3 Confort autour · 4 min'), findsOneWidget);

    // 6. Swipe PageView to TCU
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('SANS VOITURE'), findsOneWidget);
    expect(find.text('Bus, BRT, ...'), findsOneWidget);
  });

  testWidgets('Tapping SEDDO logo or street address opens VOTRE POSITION bottom sheet',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(milliseconds: 600));

    // Tap header (SEDDO logo + street location)
    await tester.tap(find.byKey(const ValueKey('seddo_logo_and_location_header')));
    await tester.pumpAndSettle();

    // Verify "VOTRE POSITION" modal appears
    expect(find.text('VOTRE POSITION'), findsOneWidget);
    expect(find.text('Rue YF-557, 20'), findsAtLeastNWidgets(1));
    expect(find.text('Enregistrer la position pour une utilisation ultérieure'),
        findsOneWidget);
    expect(find.text('Partager la position'), findsOneWidget);
    expect(find.text('Modifier votre position'), findsOneWidget);
  });

  testWidgets('HomePage displays 2 recent trip cards from base / defaults',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));

    // Suggestions section header
    expect(find.text('Suggestions'), findsOneWidget);

    // Two recent trip cards should be visible
    expect(find.text('Sea Plaza'), findsOneWidget);
    expect(find.text("Place de l'Indépendance"), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsNWidgets(2));
  });

  testWidgets('Tapping menu icon opens endDrawer from right to left',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(milliseconds: 600));

    // Tap on burger menu button
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Verify endDrawer is open and visible
    expect(find.text('Activité'), findsOneWidget);
    expect(find.text('Courses et remboursements'), findsOneWidget);
  });
}
