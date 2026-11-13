import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/core/localization/wolof_localizations_delegate.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/profile/presentation/pages/edit_profile_page.dart';

class MockProfileTestAssetLoader extends AssetLoader {
  const MockProfileTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'app_name': 'Seddo',
      'common': {
        'cancel': 'Annuler',
        'confirm': 'Confirmer',
        'close': 'Fermer',
        'back': 'Retour',
        'save': 'Enregistrer',
      },
      'edit_profile': {
        'title': 'Modifier le profil',
        'personal_info': 'Informations personnelles',
        'first_name': 'Prénom',
        'first_name_hint': 'Votre prénom',
        'last_name': 'Nom',
        'last_name_hint': 'Votre nom',
        'phone': 'Numéro de téléphone',
        'phone_immutable': 'Le numéro de téléphone ne peut pas être modifié',
        'notifications': 'Préférences de notification',
        'notify_push': 'Notifications push',
        'notify_push_desc': 'Alertes de course, mises à jour et rappels',
        'notify_sms': 'Notifications par SMS',
        'notify_sms_desc': 'SMS de secours pour les courses importantes',
        'save_changes': 'Enregistrer les modifications',
        'saved_success': 'Profil mis à jour avec succès',
        'first_name_required': 'Le prénom est requis',
        'last_name_required': 'Le nom est requis',
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
      supportedLocales: const [Locale('fr')],
      path: 'assets/translations',
      assetLoader: const MockProfileTestAssetLoader(),
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
            home: child,
          );
        },
      ),
    );
  }

  testWidgets(
      'EditProfilePage displays current user details, excludes language, and toggles notifications',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const initialUser = UserModel(
      id: 'usr_fatou_fall',
      phone: '+221784226719',
      firstName: 'Fatou',
      lastName: 'Fall',
      photoUrl: null,
      rating: null,
      ratingCount: 0,
      lang: 'fr',
      notifyPush: true,
      notifySms: false,
    );
    AuthRepository().setCurrentUser(initialUser);
    addTearDown(() => AuthRepository().setCurrentUser(null));

    await tester.pumpWidget(
      buildTestableWidget(
        child: const EditProfilePage(currentUser: initialUser),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Title and header
    expect(find.text('Modifier mon profil'), findsOneWidget);
    expect(find.text('FF'), findsOneWidget);

    // 2. Personal info fields
    final firstNameFinder = find.byKey(const Key('edit_profile_firstname_field'));
    final lastNameFinder = find.byKey(const Key('edit_profile_lastname_field'));
    expect(firstNameFinder, findsOneWidget);
    expect(lastNameFinder, findsOneWidget);
    expect(find.text('Fatou'), findsOneWidget);
    expect(find.text('Fall'), findsOneWidget);

    // 3. Phone is read-only
    final expectedPhone = initialUser.formattedDisplayPhone.isNotEmpty
        ? initialUser.formattedDisplayPhone
        : (initialUser.formattedNationalPhone.isNotEmpty
            ? initialUser.formattedNationalPhone
            : initialUser.phone);
    expect(find.text(expectedPhone), findsOneWidget);

    // 4. Notifications section (Push is ON, SMS is OFF)
    final pushSwitchFinder = find.byKey(const Key('edit_profile_push_switch'));
    final smsSwitchFinder = find.byKey(const Key('edit_profile_sms_switch'));
    expect(pushSwitchFinder, findsOneWidget);
    expect(smsSwitchFinder, findsOneWidget);

    final Switch pushSwitch = tester.widget<Switch>(pushSwitchFinder);
    final Switch smsSwitch = tester.widget<Switch>(smsSwitchFinder);
    expect(pushSwitch.value, isTrue);
    expect(smsSwitch.value, isFalse);

    // 5. Language selector MUST NOT exist on this page (already handled in drawer)
    expect(find.text('Langue'), findsNothing);
    expect(find.text('Wolof'), findsNothing);

    // 6. Toggle SMS Switch ON
    await tester.tap(smsSwitchFinder);
    await tester.pumpAndSettle();
    final Switch updatedSmsSwitch = tester.widget<Switch>(smsSwitchFinder);
    expect(updatedSmsSwitch.value, isTrue);

    // 7. Update Name
    await tester.enterText(firstNameFinder, 'Aminata');
    await tester.enterText(lastNameFinder, 'Diop');
    await tester.pumpAndSettle();

    // 8. Save changes
    final saveButton = find.byKey(const Key('edit_profile_save_button'));
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify currentUser in AuthRepository was updated
    final updatedUser = AuthRepository().currentUser;
    expect(updatedUser?.firstName, 'Aminata');
    expect(updatedUser?.lastName, 'Diop');
    expect(updatedUser?.notifySms, isTrue);
    expect(updatedUser?.notifyPush, isTrue);
  });

  testWidgets('Tapping photo edit button opens camera/gallery options',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const initialUser = UserModel(
      id: 'usr_test_photo',
      phone: '+221784226719',
      firstName: 'Fatou',
      lastName: 'Fall',
    );
    AuthRepository().setCurrentUser(initialUser);
    addTearDown(() => AuthRepository().setCurrentUser(null));

    await tester.pumpWidget(
      buildTestableWidget(
        child: const EditProfilePage(currentUser: initialUser),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Changer la photo de profil'), findsNothing);

    final photoButton = find.byKey(const Key('edit_profile_avatar_button'));
    expect(photoButton, findsOneWidget);
    await tester.tap(photoButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit_photo_camera')), findsOneWidget);
    expect(find.byKey(const Key('edit_photo_gallery')), findsOneWidget);
  });
}
