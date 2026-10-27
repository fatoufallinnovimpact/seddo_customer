import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/auth/presentation/pages/phone_input_page.dart';
import 'package:seddo/features/onboarding/presentation/widgets/consent_modal_widget.dart';
import 'package:seddo/features/onboarding/presentation/pages/onboarding_page.dart';

class MockTestAssetLoader extends AssetLoader {
  const MockTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'app_name': 'Seddo',
      'common': {
        'welcome': 'Bienvenue sur Seddo !',
        'french': 'Français',
        'wolof': 'Wolof'
      },
      'onboarding': {
        'hero_title': 'Votre chauffeur,\npayé en Orange Money.',
        'hero_subtitle': 'Prix fixe avant de partir.\nZéro cash.',
        'start': 'Commencer',
        'legal_notice':
            'En continuant, vous acceptez les conditions\nd\'utilisation et la politique de confidentialité.'
      },
      'consent': {
        'title': 'Consentements obligatoires',
        'subtitle':
            'Pour vous offrir un service fiable et sécurisé, veuillez accepter les éléments suivants :',
        'cgu': 'J\'accepte les Conditions Générales d\'Utilisation (CGU)',
        'privacy': 'J\'accepte la Politique de protection des données',
        'location':
            'J\'autorise la géolocalisation pour trouver des trajets autour de moi',
        'accept_start': 'Accepter & Commencer'
      },
      'auth': {
        'your_number': 'Votre numéro',
        'orange_money_notice':
            'Un numéro Orange Money est nécessaire pour payer vos courses.',
        'phone_hint': '77 123 45 12',
        'continue': 'Continuer',
        'code_received': 'Code reçu par SMS',
        'enter_code_sent_to': 'Entrez le code envoyé au',
        'resend_code_in': 'Renvoyer le code dans',
        'resend_code': 'Renvoyer le code'
      }
    };
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('OnboardingPage renders completely without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('fr'), Locale('wo')],
        path: 'assets/translations',
        assetLoader: const MockTestAssetLoader(),
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
              home: const OnboardingPage(),
            );
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Wolof'), findsOneWidget);
  });

  testWidgets(
      'Tapping Commencer navigates directly to PhoneInputPage without showing ConsentModalWidget',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('fr'), Locale('wo')],
        path: 'assets/translations',
        assetLoader: const MockTestAssetLoader(),
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
              home: const OnboardingPage(),
            );
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Tap Commencer
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    // Verify modal is not displayed and PhoneInputPage is displayed directly
    expect(find.byType(ConsentModalWidget), findsNothing);
    expect(find.byType(PhoneInputPage), findsOneWidget);
  });
}

