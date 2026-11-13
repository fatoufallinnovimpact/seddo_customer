import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/core/localization/wolof_localizations_delegate.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import 'package:seddo/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';

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
        'tcu_sub': 'Bus AFTU, DDD, BRT',
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

  testWidgets(
      'SeddoDrawerWidget renders user profile and all menu items without payment card',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const testUser = UserModel(
      id: 'usr_default',
      phone: '77 123 45 12',
      firstName: 'Fatou',
      lastName: 'Fall',
      rating: 4.8,
    );
    AuthRepository().setCurrentUser(testUser);
    addTearDown(() => AuthRepository().setCurrentUser(null));

    await tester.pumpWidget(
      buildTestableWidget(child: const SeddoDrawerWidget()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // 1. Profile with real user
    expect(find.text('Fatou Fall'), findsOneWidget);
    expect(find.text('FF'), findsOneWidget);
    expect(find.text('4,8'), findsOneWidget);
    expect(find.text('+221 77 123 45 12'), findsOneWidget);

    // 2. Payment card removed
    expect(find.text('Paiement'), findsNothing);
    expect(find.textContaining('Orange Money'), findsNothing);

    // 3. Main Menu items
    expect(find.text('Activité'), findsOneWidget);
    expect(find.text('Courses et remboursements'), findsOneWidget);

    expect(find.text('TCU'), findsOneWidget);
    expect(find.text('Bus AFTU, DDD, BRT'), findsOneWidget);

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
    expect(find.text('Aide'), findsOneWidget);
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
    expect(find.text('Ndimbal'), findsOneWidget);
    expect(find.text('Génn'), findsOneWidget);
  });

  testWidgets(
      'SeddoDrawerWidget displays authenticated user name and phone without payment card',
      (tester) async {
    const testUser = UserModel(
      id: 'usr_771004313',
      phone: '77 100 43 13',
      firstName: 'Fatou',
      lastName: 'Fall',
      lang: 'fr',
      omEligible: true,
      isNew: false,
      needsProfile: false,
    );
    AuthRepository().setCurrentUser(testUser);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      AuthRepository().setCurrentUser(null);
    });

    await tester.pumpWidget(
      buildTestableWidget(child: const SeddoDrawerWidget()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // 1. Profile with real user name and phone
    expect(find.text('Fatou Fall'), findsOneWidget);
    expect(find.text('FF'), findsOneWidget);
    expect(find.text('+221 77 100 43 13'), findsOneWidget);

    // 2. Payment card is removed
    expect(find.text('Paiement'), findsNothing);
    expect(find.textContaining('Orange Money'), findsNothing);
  });

  testWidgets('SeddoDrawerWidget displays real user rating from API or fallback',
      (tester) async {
    const testUserWithRating = UserModel(
      id: 'usr_771004313',
      phone: '77 100 43 13',
      firstName: 'Fatou',
      lastName: 'Fall',
      lang: 'fr',
      omEligible: true,
      rating: 4.9,
      ratingCount: 18,
    );
    AuthRepository().setCurrentUser(testUserWithRating);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      AuthRepository().setCurrentUser(null);
    });

    await tester.pumpWidget(
      buildTestableWidget(child: const SeddoDrawerWidget()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('drawer_user_rating')), findsOneWidget);
    expect(find.text('4,9'), findsOneWidget);
  });

  testWidgets(
      'Tapping avatar initials button or name navigates directly to EditProfilePage',
      (tester) async {
    const testUser = UserModel(
      id: 'usr_771004313',
      phone: '77 100 43 13',
      firstName: 'Fatou',
      lastName: 'Fall',
      lang: 'fr',
      omEligible: true,
    );
    AuthRepository().setCurrentUser(testUser);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      AuthRepository().setCurrentUser(null);
    });

    await tester.pumpWidget(
      buildTestableWidget(child: const SeddoDrawerWidget()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap on avatar button
    final avatarButton = find.byKey(const Key('drawer_avatar_button'));
    expect(avatarButton, findsOneWidget);
    await tester.tap(avatarButton);
    await tester.pumpAndSettle();

    // Verify EditProfilePage is opened directly
    expect(find.text('Modifier mon profil'), findsOneWidget);
    expect(find.byKey(const Key('edit_profile_firstname_field')), findsOneWidget);
  });

  testWidgets('SeddoDrawerWidget displays only phone number when user rating is null',
      (tester) async {
    const testUserNoRating = UserModel(
      id: 'usr_no_rating',
      phone: '77 100 43 13',
      firstName: 'Fatou',
      lastName: 'Fall',
      rating: null,
      ratingCount: 0,
    );
    AuthRepository().setCurrentUser(testUserNoRating);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      AuthRepository().setCurrentUser(null);
    });

    await tester.pumpWidget(
      buildTestableWidget(child: const SeddoDrawerWidget()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('drawer_user_rating')), findsNothing);
    expect(find.text('Nouveau'), findsNothing);
    expect(find.byKey(const Key('drawer_user_name_button')), findsOneWidget);
    expect(find.text('Fatou Fall'), findsOneWidget);
    expect(find.text('+221 77 100 43 13'), findsOneWidget);
  });
}
