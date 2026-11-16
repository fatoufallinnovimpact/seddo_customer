import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/presentation/widgets/ou_allons_nous_card.dart';

void main() {
  testWidgets('OuAllonsNousCard renders default label and handles tap interaction',
      (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OuAllonsNousCard(
            label: 'Où allons-nous ?',
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    // 1. Text is rendered
    expect(find.text('Où allons-nous ?'), findsOneWidget);

    // 2. Chevron right icon is rendered
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    // 3. Container background is serviceCardBg and height is 52.0
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColors.serviceCardBg);
    expect(tester.getSize(find.byType(OuAllonsNousCard)).height, 52.0);

    // 4. Tap triggers callback
    await tester.tap(find.byType(OuAllonsNousCard));
    expect(tapped, isTrue);

    await tester.pump();
  });
}
