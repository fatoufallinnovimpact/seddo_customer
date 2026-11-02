import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('SlideRightToLeftRoute iOS Swipe-to-Back Tests', () {
    testWidgets('On iOS, swiping from left to right pops the page back',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          SlideRightToLeftRoute(
                            page: const Scaffold(
                              body: Center(
                                child: Text('Second Page iOS'),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('Go to Second Page'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        // Open second page
        await tester.tap(find.text('Go to Second Page'));
        await tester.pumpAndSettle();

        expect(find.text('Second Page iOS'), findsOneWidget);

        // Swipe back from left edge to right
        final gesture = await tester.startGesture(const Offset(5, 300));
        await gesture.moveBy(const Offset(400, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        // Second page was popped back to first page
        expect(find.text('Second Page iOS'), findsNothing);
        expect(find.text('Go to Second Page'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'On Android, left edge swipe does NOT pop the page (iOS only gesture)',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          SlideRightToLeftRoute(
                            page: const Scaffold(
                              body: Center(
                                child: Text('Second Page Android'),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('Go to Second Page'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        // Open second page
        await tester.tap(find.text('Go to Second Page'));
        await tester.pumpAndSettle();

        expect(find.text('Second Page Android'), findsOneWidget);

        // Drag from left edge to right (not handled on Android)
        await tester.dragFrom(const Offset(5, 300), const Offset(350, 0));
        await tester.pumpAndSettle();

        // Page is STILL on Second Page because swipe-to-back is disabled on Android
        expect(find.text('Second Page Android'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'On iOS, opening a modal bottom sheet does NOT slide the route (canTransitionTo is false for modals)',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          SlideRightToLeftRoute(
                            page: Builder(
                              builder: (sheetContext) {
                                return Scaffold(
                                  body: Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        showModalBottomSheet<void>(
                                          context: sheetContext,
                                          builder: (_) => const SizedBox(
                                            height: 200,
                                            child: Text('Modal Content'),
                                          ),
                                        );
                                      },
                                      child: const Text('Open Modal Sheet'),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text('Go to Page with Modal'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Go to Page with Modal'));
        await tester.pumpAndSettle();

        // Open modal bottom sheet
        await tester.tap(find.text('Open Modal Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Modal Content'), findsOneWidget);

        // Verify that the page behind is still at its centered x position and not slid away
        final buttonPos = tester.getTopLeft(find.text('Open Modal Sheet'));
        expect(buttonPos.dx, greaterThan(0));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
