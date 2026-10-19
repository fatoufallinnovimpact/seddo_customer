import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/themes/app_theme.dart';
import 'package:seddo/features/splash/presentation/pages/splash_page.dart';

void main() {
  testWidgets('SplashPage displays properly and animates', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SplashPage(),
      ),
    );
    expect(find.byType(SplashPage), findsOneWidget);

    // Advance animation frame
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SplashPage), findsOneWidget);

    // Dispose widget tree cleanly to cancel pending navigation timer
    await tester.pumpWidget(const SizedBox());
  });
}
