import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/auth/domain/bloc/auth_bloc.dart';
import 'package:seddo/features/auth/presentation/pages/phone_input_page.dart';

class MockAuthTestAssetLoader extends AssetLoader {
  const MockAuthTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'app_name': 'Seddo',
      'common': {
        'welcome': 'Bienvenue sur Seddo !',
        'french': 'Français',
        'wolof': 'Wolof'
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
        'resend_code': 'Renvoyer le code',
        'profile_title': 'Votre profil',
        'profile_subtitle':
            'Entrez votre prénom et votre nom pour que votre chauffeur puisse vous identifier.',
        'first_name': 'Prénom',
        'first_name_hint': 'Ex: Awa',
        'last_name': 'Nom',
        'last_name_hint': 'Ex: Diop',
        'accept_and_continue': 'Accepter et continuer'
      },
      'consent': {
        'title': 'Consentements obligatoires',
        'subtitle': 'Pour vous offrir un service fiable et sécurisé...',
        'cgu': 'CGU',
        'privacy': 'Protection des données',
        'location': 'Géolocalisation',
        'accept_start': 'Accepter & Commencer'
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

  testWidgets('PhoneInputPage renders correctly with +221 and headline',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    await tester.pumpWidget(
      EasyLocalization(
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
              home: BlocProvider(
                create: (_) => AuthBloc(),
                child: const PhoneInputPage(),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Votre numéro'), findsOneWidget);
    expect(
      find.text('Un numéro Orange Money est nécessaire pour payer vos courses.'),
      findsOneWidget,
    );
    expect(find.text('+221'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);

    // Enter 9 digits
    await tester.enterText(find.byType(TextField), '771234512');
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, '77 123 45 12');
  });
}
