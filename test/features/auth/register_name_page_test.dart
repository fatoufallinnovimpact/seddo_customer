import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/auth/presentation/pages/register_name_page.dart';
import 'package:seddo/features/onboarding/presentation/widgets/consent_modal_widget.dart';
import 'package:seddo/features/home/presentation/pages/home_page.dart';
import 'phone_input_page_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget() {
    return EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('wo')],
      path: 'assets/translations',
      assetLoader: const MockAuthTestAssetLoader(),
      fallbackLocale: const Locale('fr'),
      startLocale: const Locale('fr'),
      saveLocale: false,
      useOnlyLangCode: true,
      child: Builder(
        builder: (context) {
          return MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: const RegisterNamePage(),
          );
        },
      ),
    );
  }

  testWidgets(
      'RegisterNamePage initial render: fields visible, button disabled',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Votre profil'), findsOneWidget);
    expect(find.text('Prénom'), findsOneWidget);
    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('Accepter et continuer'), findsOneWidget);

    final ElevatedButton button =
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets(
      'Entering only one field keeps button disabled; entering both enables button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Enter first name only
    await tester.enterText(textFields.first, 'Fatou');
    await tester.pumpAndSettle();

    var button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    // Enter last name
    await tester.enterText(textFields.last, 'Fall');
    await tester.pumpAndSettle();

    button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
      'Tapping Accepter et continuer opens ConsentModalWidget, accepting terms saves user and goes to HomePage',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.first, 'Fatou');
    await tester.enterText(textFields.last, 'Fall');
    await tester.pumpAndSettle();

    // Tap "Accepter et continuer"
    await tester.tap(find.text('Accepter et continuer'));
    await tester.pumpAndSettle();

    // Verify modal is open
    expect(find.byType(ConsentModalWidget), findsOneWidget);
    expect(find.text('Consentements obligatoires'), findsOneWidget);

    // Tap each of the 3 consent options
    expect(find.text('CGU'), findsOneWidget);
    expect(find.text('Protection des données'), findsOneWidget);
    expect(find.text('Géolocalisation'), findsOneWidget);

    await tester.tap(find.text('CGU'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Protection des données'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Géolocalisation'));
    await tester.pumpAndSettle();

    // Tap "Accepter & Commencer" in modal
    await tester.tap(find.text('Accepter & Commencer'));
    await tester.pumpAndSettle();

    // Verify modal closed and HomePage is rendered
    expect(find.byType(ConsentModalWidget), findsNothing);
    expect(find.byType(RegisterNamePage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);

    // Verify SharedPreferences values
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_first_name'), 'Fatou');
    expect(prefs.getString('user_last_name'), 'Fall');
    expect(prefs.getString('user_full_name'), 'Fatou Fall');
    expect(prefs.getBool('onboarding_completed'), true);
  });
}
