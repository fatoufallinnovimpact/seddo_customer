import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/home/presentation/widgets/seddo_share_position_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/user_position_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'UserPositionBottomSheet renders custom SVG action tiles for save, share, edit',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserPositionBottomSheet(
            userLocation: LatLng(14.6937, -17.4440),
            mainAddress: 'Route des Almadies',
            secondaryAddress: 'Dakar, Sénégal',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VOTRE POSITION'), findsOneWidget);
    expect(find.text('Route des Almadies'), findsOneWidget);
    expect(find.text('Dakar, Sénégal'), findsOneWidget);

    // Verify SVG tiles
    final svgFinders = find.byType(SvgPicture);
    expect(svgFinders, findsWidgets);

    // Verify action titles
    expect(
        find.text('Enregistrer la position pour une utilisation ultérieure'),
        findsOneWidget);
    expect(find.text('Partager la position'), findsOneWidget);
    expect(find.text('Modifier votre position'), findsOneWidget);
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
