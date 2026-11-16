import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'home_page_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Service cards layout strictly satisfies height alignment requirement',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(milliseconds: 600));

    final livraisonFinder = find.byKey(const ValueKey('home_service_card_livraison'));
    final transportFinder = find.byKey(const ValueKey('home_service_card_transpo'));
    final courseFinder = find.byKey(const ValueKey('home_service_card_course'));

    expect(livraisonFinder, findsOneWidget);
    expect(transportFinder, findsOneWidget);
    expect(courseFinder, findsOneWidget);

    final livraisonRect = tester.getRect(livraisonFinder);
    final transportRect = tester.getRect(transportFinder);
    final courseRect = tester.getRect(courseFinder);

    // 1. Top of Livraison card matches Top of Courses card
    expect(livraisonRect.top, closeTo(courseRect.top, 0.5));

    // 2. Bottom of Transport card matches Bottom of Courses card
    expect(transportRect.bottom, closeTo(courseRect.bottom, 0.5));

    // 3. Combined height of left cards + gap equals height of Courses card
    final leftTotalHeight = transportRect.bottom - livraisonRect.top;
    final courseHeight = courseRect.height;
    expect(leftTotalHeight, closeTo(courseHeight, 0.5));

    await tester.pumpAndSettle();
  });
}
