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
        'tcu': 'TCU',
        'tcu_sub': 'Bus, BRT et TER',
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

  testWidgets('HomePage renders GoogleMap, top bar, floating controls, and cards carousel',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(milliseconds: 600));

    // 1. GoogleMap is present
    expect(find.byType(GoogleMap), findsOneWidget);

    // 2. Top bar elements
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.text('SEDDO'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);

    // 3. Floating vehicle indicator pill and GPS button
    expect(find.text('5 Eco autour · 2 min'), findsOneWidget);
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

    // 4. Initial Card: Seddo Eco
    expect(find.text('ÉCONOMIQUE'), findsOneWidget);
    expect(find.text('Seddo Eco'), findsOneWidget);
    expect(find.text('Arrive dans 2 min'), findsOneWidget);
    expect(find.text('Où allez-vous ?'), findsOneWidget);

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
    expect(find.text('5 arrêts à moins de 500 m'), findsOneWidget);
    expect(find.text('Où allez-vous en commun ?'), findsOneWidget);
  });
}
