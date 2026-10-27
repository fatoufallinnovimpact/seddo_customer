import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/auth/domain/bloc/auth_bloc.dart';
import 'package:seddo/features/auth/domain/bloc/auth_event.dart';
import 'package:seddo/features/auth/presentation/pages/otp_verification_page.dart';
import 'phone_input_page_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('OtpVerificationPage renders title and 6 boxes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    final authBloc = AuthBloc();
    authBloc.add(const AuthPhoneNumberChangedEvent('771234512'));

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
              home: BlocProvider.value(
                value: authBloc,
                child: const OtpVerificationPage(),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Code reçu par SMS'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);

    // Enter 5 digit code to verify boxes display
    await tester.enterText(find.byType(TextField), '39021');
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // Enter 6th digit to trigger auto-submit and navigation
    await tester.enterText(find.byType(TextField), '390214');
    await tester.pumpAndSettle();

    // Since mock needsProfile is false, it navigates to HomePage
    expect(find.byType(OtpVerificationPage), findsNothing);
  });
}
