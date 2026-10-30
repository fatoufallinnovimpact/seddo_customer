import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/core/localization/wolof_localizations_delegate.dart';
import 'package:seddo/features/home/presentation/pages/home_page.dart';
import 'package:seddo/features/home/presentation/widgets/seddo_share_position_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/user_position_bottom_sheet.dart';

class MockHomeTestAssetLoader extends AssetLoader {
  const MockHomeTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'app_name': 'Seddo',
      'home': {
        'where_to': 'Où allez-vous ?',
        'go': 'Aller',
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
        'tcu_banner_badge': 'TRANSPORTS URBAINS',
        'tcu_banner_title': 'Voyagez en toute simplicité',
        'tcu_banner_subtitle': 'TER, BRT, bus AFTU et DDD :\nplanifiez vos déplacements',
        'tcu_banner_button': 'Itinéraires',
        'see_all': 'Voir tout',
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
        'save': 'Enregistrer',
        'share': 'Partager',
        'edit': 'Modifier',
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
      'HomePage renders top bar with SEDDO logo & address, and bottom current location card with mini GoogleMap, Modifier button and Partager button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(milliseconds: 600));

    // 1. Top bar elements
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.text('SEDDO'), findsOneWidget);
    expect(find.text('Rue YF-557, 20'), findsAtLeastNWidgets(1));

    // 2. Search Bar
    expect(find.text('Où allez-vous ?'), findsOneWidget);
    expect(find.text('Aller'), findsNothing);

    // 3. Mini GoogleMap preview in current location card
    expect(find.byType(GoogleMap), findsOneWidget);

    // 4. Modifier button on mini map
    expect(find.byKey(const ValueKey('home_edit_position_button')), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);

    // 5. White strip: current address and Partager button
    expect(find.byKey(const ValueKey('home_share_position_button')), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);

    // 6. Tapping Partager button opens SeddoSharePositionSheet
    await tester.tap(find.byKey(const ValueKey('home_share_position_button')));
    await tester.pumpAndSettle();

    expect(find.byType(SeddoSharePositionSheet), findsOneWidget);
  });

  testWidgets('Tapping SEDDO logo does not open any modal',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(milliseconds: 600));

    // Tap header (SEDDO logo)
    await tester.tap(find.byKey(const ValueKey('seddo_logo_and_location_header')));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify user position modal does NOT appear
    expect(find.byType(UserPositionBottomSheet), findsNothing);
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

  testWidgets('HomePage renders TCU banner with TER Dakar and Itinéraires button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));

    // TCU Banner elements
    expect(find.byKey(const ValueKey('home_tcu_banner_card')), findsOneWidget);
    expect(find.text('TRANSPORTS URBAINS'), findsNothing);
    expect(find.text('Voyagez en toute simplicité'), findsOneWidget);
    expect(find.text('Itinéraires'), findsOneWidget);
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
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
