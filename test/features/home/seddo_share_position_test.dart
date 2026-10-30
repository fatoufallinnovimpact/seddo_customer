import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/presentation/widgets/seddo_share_position_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/user_position_bottom_sheet.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  testWidgets(
      'UserPositionBottomSheet renders custom SVG action tiles for save, share, edit',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      wrapWithTestLocalization(
        locale: const Locale('fr'),
        child: const Scaffold(
          body: UserPositionBottomSheet(
            userLocation: LatLng(14.6937, -17.4440),
            mainAddress: 'Route des Almadies',
            secondaryAddress: 'Dakar, Sénégal',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Route des Almadies'), findsOneWidget);
    expect(find.text('Dakar, Sénégal'), findsOneWidget);

    // Verify SVG icons
    final svgFinders = find.byType(SvgPicture);
    expect(svgFinders, findsWidgets);

    // Verify action titles in French
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
  });

  testWidgets(
      'UserPositionBottomSheet supports Wolof language switching',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      wrapWithTestLocalization(
        locale: const Locale('wo'),
        child: const Scaffold(
          body: UserPositionBottomSheet(
            userLocation: LatLng(14.6937, -17.4440),
            mainAddress: 'Route des Almadies',
            secondaryAddress: 'Dakar, Sénégal',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify action titles in Wolof
    expect(find.text('Soppi'), findsOneWidget);
    expect(find.text('Denc'), findsOneWidget);
    expect(find.text('Maye'), findsOneWidget);
  });

  testWidgets(
      'SeddoSharePositionSheet renders preview card, channels (WhatsApp, SMS, Copier, Autres), and share URL',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const testLocation = LatLng(14.67896, -17.46303);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SeddoSharePositionSheet(
            location: testLocation,
            mainAddress: 'Mermoz Ancienne Piste',
            secondaryAddress: 'Dakar, Sénégal',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and description
    expect(find.text('Partager votre position'), findsOneWidget);
    expect(find.text('Seddo'), findsOneWidget);
    expect(find.text('Course rapide et sécurisée'), findsOneWidget);
    expect(find.text('Mermoz Ancienne Piste'), findsOneWidget);
    expect(find.text('seddo.sn/ride'), findsOneWidget);

    // Verify share channels
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Autres'), findsOneWidget);
    expect(find.text('Partager maintenant'), findsOneWidget);

    // Verify generated URL format matches Yango deep-link pattern with end-lon and end-lat
    const sheet = SeddoSharePositionSheet(
      location: testLocation,
      mainAddress: 'Mermoz Ancienne Piste',
      secondaryAddress: 'Dakar, Sénégal',
    );
    expect(sheet.shareUrl,
        'https://seddo.sn/ride?end-lon=-17.46303&end-lat=14.67896');
    expect(sheet.shareMessage, contains('https://seddo.sn/ride?end-lon=-17.46303&end-lat=14.67896'));
    expect(sheet.shareMessage, contains('Un moyen simple pour me rejoindre avec Seddo'));
  });
}
