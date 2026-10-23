import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/core/localization/wolof_localizations_delegate.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import 'package:seddo/features/onboarding/presentation/pages/onboarding_page.dart';

class MockDrawerTestAssetLoader extends AssetLoader {
  const MockDrawerTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final isWo = locale.languageCode == 'wo';
    return {
      'app_name': 'Seddo',
      'common': {
        'welcome': isWo ? 'Dalal ak jamm ci Seddo !' : 'Bienvenue sur Seddo !',
        'french': 'Français',
        'wolof': 'Wolof',
        'cancel': isWo ? 'Neenal' : 'Annuler',
        'confirm': isWo ? 'Dëggal' : 'Confirmer',
        'close': isWo ? 'Tëj' : 'Fermer',
        'back': isWo ? 'Dellu' : 'Retour',
        'retry': isWo ? 'Jéemaat' : 'Réessayer',
        'save': isWo ? 'Denc' : 'Enregistrer',
        'delete': isWo ? 'Far' : 'Supprimer',
        'call': isWo ? 'Woowee' : 'Appeler',
        'message': isWo ? 'Bataaxal' : 'Message',
        'support': isWo ? 'Ndimbal' : 'Support',
      },
      'drawer': {
        'activity': isWo ? 'Yëngu-yëngu' : 'Activité',
        'activity_sub':
            isWo ? 'Tukki yi ak feyukaay yi' : 'Courses et remboursements',
        'tcu': 'TCU',
        'tcu_sub': isWo ? 'Bus, BRT ak TER' : 'Bus, BRT et TER',
        'saved_places': isWo ? 'Béréb yi ma denc' : 'Lieux enregistrés',
        'saved_places_sub':
            isWo ? 'Kër, Liggeyukaay, Aéroport' : 'Maison, Travail, Aéroport',
        'safety': isWo ? 'Kaaraange' : 'Sécurité',
        'safety_sub': isWo
            ? 'Numéro ndimbal, maye sa yoon'
            : 'Contacts d’urgence, partage de trajet',
        'notifications': isWo ? 'Yégle yi' : 'Notifications',
        'notifications_sub': isWo ? 'Push ak SMS' : 'Push et SMS',
        'language': isWo ? 'Làkk' : 'Langue',
        'help': isWo ? 'Ndimbal' : 'Aide',
        'help_sub':
            isWo ? 'Support ak ndimbal 24h/24' : 'Support et assistance 24/7',
        'privacy': isWo ? 'Kaaraangey dëkkukaay' : 'Confidentialité et données',
        'privacy_sub':
            isWo ? 'Kaaraangey sa mbir yi' : 'Protection des données personnelles',
        'logout': isWo ? 'Génn' : 'Se déconnecter',
        'logout_title': isWo ? 'Génn ci compte bi' : 'Se déconnecter',
        'logout_message': isWo
            ? 'Dëgg nga bëgg nga génn ci compte Seddo bi ?'
            : 'Êtes-vous sûr de vouloir vous déconnecter de votre compte Seddo ?',
        'payment': isWo ? 'Fey' : 'Paiement',
        'payment_sub': 'Orange Money 77 ••• 45 12',
        'default_mode': isWo ? 'Mànkoon na' : 'Mode par défaut',
      },
      'language_modal': {
        'title': isWo ? 'Tànnal làkk' : 'Choisir la langue',
        'french': 'Français',
        'french_sub': isWo ? 'Làkk bu réew mi' : 'Langue officielle',
        'wolof': 'Wolof',
        'wolof_sub': 'Làkku réew mi',
      },
    };
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildTestableWidget({required Widget child}) {
    return EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('wo')],
      path: 'assets/translations',
      assetLoader: const MockDrawerTestAssetLoader(),
      fallbackLocale: const Locale('fr'),
      startLocale: const Locale('fr'),
      saveLocale: false,
      useOnlyLangCode: true,
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
            home: Scaffold(
              body: SizedBox(
                width: 340,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  testWidgets('SeddoDrawerWidget renders user profile, payment card and all menu items',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      buildTestableWidget(child: const SeddoDrawerWidget()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // 1. Profile
    expect(find.text('AWA DIOP'), findsOneWidget);
    expect(find.text('AD'), findsOneWidget);
    expect(find.text('4,8'), findsOneWidget);
    expect(find.text('77 123 45 12'), findsOneWidget);

    // 2. Payment card
    expect(find.text('Paiement'), findsOneWidget);
    expect(find.text('Orange Money 77 ••• 45 12'), findsOneWidget);

    // 3. Main Menu items
    expect(find.text('Activité'), findsOneWidget);
    expect(find.text('Courses et remboursements'), findsOneWidget);

    expect(find.text('TCU'), findsOneWidget);
    expect(find.text('Bus, BRT et TER'), findsOneWidget);

    expect(find.text('Lieux enregistrés'), findsOneWidget);
    expect(find.text('Maison, Travail, Aéroport'), findsOneWidget);

    expect(find.text('Sécurité'), findsOneWidget);
    expect(find.text('Contacts d’urgence, partage de trajet'), findsOneWidget);

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Push et SMS'), findsOneWidget);

    expect(find.text('Langue'), findsOneWidget);

    expect(find.text('Aide'), findsOneWidget);
    expect(find.text('Support et assistance 24/7'), findsOneWidget);

    expect(find.text('Confidentialité et données'), findsOneWidget);
    expect(find.text('Protection des données personnelles'), findsOneWidget);

    // 4. Logout tout en bas
    expect(find.text('Se déconnecter'), findsOneWidget);
  });

  testWidgets('Tapping Langue opens language selection sheet and allows switching',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      buildTestableWidget(child: const SeddoDrawerWidget()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // Tap on Langue
    await tester.tap(find.text('Langue'));
    await tester.pumpAndSettle();

    expect(find.text('Choisir la langue'), findsOneWidget);
    expect(find.text('Wolof'), findsOneWidget);
    expect(find.text('Français'), findsNWidgets(2));
  });

  testWidgets('Tapping Se déconnecter opens bottom-sheet LogoutModal and confirms to Onboarding',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      buildTestableWidget(child: const SeddoDrawerWidget()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // Tap on Se déconnecter
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    // Verify LogoutModal bottom sheet appears
    expect(find.text('Annuler'), findsOneWidget);
    expect(
      find.text('Êtes-vous sûr de vouloir vous déconnecter de votre compte Seddo ?'),
      findsOneWidget,
    );

    // Confirm logout
    final confirmButtons = find.widgetWithText(ElevatedButton, 'Se déconnecter');
    expect(confirmButtons, findsOneWidget);
    await tester.tap(confirmButtons);
    await tester.pumpAndSettle();

    // Redirection to OnboardingPage
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('Selecting Wolof in LanguageModal dynamically updates drawer and UI to Wolof',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      buildTestableWidget(child: const SeddoDrawerWidget()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // Initially French
    expect(find.text('Activité'), findsOneWidget);
    expect(find.text('Sécurité'), findsOneWidget);
    expect(find.text('Paiement'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);

    // Tap on Langue to open LanguageModal
    await tester.tap(find.text('Langue'));
    await tester.pumpAndSettle();

    expect(find.text('Choisir la langue'), findsOneWidget);

    // Tap on Wolof card
    await tester.tap(find.text('Wolof'));
    await tester.pumpAndSettle();

    // Close the language modal
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Drawer should now be in Wolof!
    expect(find.text('Yëngu-yëngu'), findsOneWidget);
    expect(find.text('Kaaraange'), findsOneWidget);
    expect(find.text('Fey'), findsOneWidget);
    expect(find.text('Génn'), findsOneWidget);
  });
}
