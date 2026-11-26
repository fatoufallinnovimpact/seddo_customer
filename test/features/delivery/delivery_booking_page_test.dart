import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/delivery/presentation/pages/delivery_booking_page.dart';
import 'package:seddo/features/delivery/presentation/pages/delivery_itinerary_page.dart';
import 'package:seddo/features/delivery/presentation/pages/delivery_order_details_page.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_address_details_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_contact_picker_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_destination_search_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_info_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_order_form_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_call_courier_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_order_summary_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_time_option_info_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_tracking_sheet.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_update_order_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_vehicle_details_sheet.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/services/places_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDeliveryAssetLoader extends AssetLoader {
  const MockDeliveryAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    if (file.existsSync()) {
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }
    return {};
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildTestableWidget(Widget child) {
    return EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('wo')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      startLocale: const Locale('fr'),
      assetLoader: const MockDeliveryAssetLoader(),
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('DeliveryBookingPage Widget Tests', () {
    testWidgets('Renders all UI components according to reference screenshot',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          const DeliveryBookingPage(
            initialOrigin: 'Rue FN-55, 175',
            initialOriginLocation: LatLng(14.6928, -17.4730),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Draggable sheet Header & Title "ENVOYER UN COLIS" (verrouillé à sa position de base 0.55)
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      final sheetWidget = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(sheetWidget.initialChildSize, 0.55);
      expect(sheetWidget.minChildSize, 0.55);
      expect(sheetWidget.maxChildSize, 1.0);
      expect(find.text('ENVOYER UN COLIS'), findsOneWidget);

      // 1b. Interactive animated position marker (SeddoMapPickerPin)
      expect(find.text('Prise en charge ~9 min'), findsOneWidget);

      // 2. Pickup Address row with position icon (Icons.hail_rounded)
      expect(find.text('Rue FN-55, 175'), findsOneWidget);
      expect(find.byIcon(Icons.hail_rounded), findsWidgets);

      // 3. Destination Address row with "Adresse de livraison" and flag SVG icon
      expect(find.text('Adresse de livraison'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader.toString().contains('flag-svgrepo-com.svg'),
        ),
        findsOneWidget,
      );

      // 4. Vehicle Selection Cards (Express Moto and Express Cargo truck)
      expect(find.text('Express Moto'), findsOneWidget);
      expect(find.text('9 min.'), findsOneWidget);
      expect(find.text('à partir de 500 F'), findsOneWidget);

      expect(find.text('Express Cargo'), findsOneWidget);
      expect(find.text('5 min.'), findsOneWidget);
      expect(find.text('à partir de 2600 F'), findsOneWidget);

      // 5. Bottom Action Bar with tune button
      expect(
        find.text('Accéder au formulaire\nde commande'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      // 6. Test vehicle selection toggle
      await tester.tap(find.text('Express Cargo'));
      await tester.pumpAndSettle();

      // Toggle back to Express Moto
      await tester.tap(find.text('Express Moto'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Tapping Adresse de livraison opens DeliveryDestinationSearchModal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          const DeliveryBookingPage(
            initialOrigin: 'Rue FN-55, 175',
            initialOriginLocation: LatLng(14.6928, -17.4730),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on "Adresse de livraison"
      await tester.tap(find.text('Adresse de livraison'));
      await tester.pumpAndSettle();

      // Modal should be open with search field and map picker option
      expect(find.byType(DeliveryDestinationSearchModal), findsOneWidget);
      expect(find.text('Où livrer le colis ?'), findsOneWidget);
      expect(find.text('Choisir sur la carte'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Tapping details tune button expands sheet with vehicle details and closes via chevron down',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          const DeliveryBookingPage(
            initialOrigin: 'Rue FN-48, 12',
            initialOriginLocation: LatLng(14.6928, -17.4730),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap tune button to expand vehicle details sheet to full height
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      // Should display vehicle details in expanded state
      expect(find.text('Livraison'), findsOneWidget);
      expect(find.text('Pour les petits colis et documents'), findsOneWidget);
      expect(find.text('À savoir'), findsOneWidget);

      // Numbered steps in "À savoir"
      expect(
        find.text('Appuyez sur « Ouvrir le formulaire de commande »'),
        findsOneWidget,
      );
      expect(find.text('Sélectionnez les options requises'), findsOneWidget);
      expect(find.text('Sélectionnez le mode paiement'), findsOneWidget);

      // Close via keyboard_arrow_down_rounded
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // Sheet is collapsed back, tune icon returns
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('DeliveryVehicleDetailsSheet displays correctly when shown standalone',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: DeliveryVehicleDetailsSheet(
              initialDeliveryType: 'moto',
              pickupAddress: 'Rue FN-48, 12',
              motoPrice: 500,
              cargoPrice: 2600,
              onOpenOrderForm: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryVehicleDetailsSheet), findsOneWidget);
      expect(find.text('Livraison'), findsOneWidget);
      expect(find.text('Pour les petits colis et documents'), findsOneWidget);
      expect(find.text('À savoir'), findsOneWidget);
      expect(find.text('Appuyez sur « Ouvrir le formulaire de commande »'), findsOneWidget);
    });

    testWidgets('DeliveryOrderFormModal displays all components according to reference screenshots and handles sub-modals',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: DeliveryOrderFormModal(
              pickupAddress: 'Rue FN-55, 175',
              destinationAddress: 'Avenue Cheikh Anta Diop',
              deliveryType: 'moto',
              estimatedPrice: 700,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Carte supérieure Adresse (Image 1)
      expect(find.text('Express'), findsOneWidget);
      expect(find.text('Point de départ'), findsOneWidget);
      expect(find.text('Rue FN-55, 175'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Avenue Cheikh Anta Diop'), findsOneWidget);
      expect(find.text('Adresse'), findsOneWidget);
      expect(find.text('Itinéraire'), findsOneWidget);

      // 2. Carte principale (Images 1 & 2)
      expect(find.text('Poids maximal : 10 kg'), findsOneWidget);
      expect(find.text('Dès que possible'), findsOneWidget);
      expect(find.text('30 minutes de plus'), findsOneWidget);
      expect(find.text('Dans 2 heures'), findsOneWidget);
      expect(find.text('Options'), findsOneWidget);

      // 3. Test de sélection d'une option horaire
      await tester.ensureVisible(find.text('Dès que possible'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dès que possible'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Saisissez les détails'), findsOneWidget);

      // 4. Test du Modal Coursier (Image 5)
      await tester.ensureVisible(find.textContaining('Coursier •'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Coursier •'));
      await tester.pumpAndSettle();

      expect(find.text('Coursier'), findsOneWidget);
      expect(find.text('N\'importe quel coursier à proximité'), findsOneWidget);
      expect(find.text('Coursier en voiture'), findsOneWidget);

      // Sélectionner coursier en voiture et fermer
      await tester.tap(find.text('Coursier en voiture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Coursier en voiture'), findsOneWidget);

      // 5. Test du Modal Options (Image 3)
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();

      expect(find.text('Sac de livraison isotherme'), findsOneWidget);
      expect(find.text('Instructions du Coursier'), findsOneWidget);
      expect(find.text('Fermer'), findsOneWidget);

      // 6. Test du Modal Instructions du Coursier (Image 4)
      await tester.tap(find.text('Instructions du Coursier'));
      await tester.pumpAndSettle();

      expect(find.text('Instructions du Coursier'), findsNWidgets(2));
      expect(find.textContaining('Expliquez précisément'), findsOneWidget);
      expect(find.text('Assistant will help out'), findsOneWidget);
      expect(find.text('Terminer'), findsOneWidget);

      // Saisir une instruction
      await tester.enterText(find.byType(TextField), 'Colis fragile, manipuler avec soin');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      // De retour sur le modal Options, on le ferme
      expect(find.text('Fermer'), findsOneWidget);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
    });

    testWidgets('DeliveryInfoModal displays correctly for Express Moto and closes via J\'ai compris',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DeliveryInfoModal.show(context, deliveryType: 'moto'),
                child: const Text('Open Moto Info'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Moto Info'));
      await tester.pumpAndSettle();

      expect(find.text('EXPRESS MOTO'), findsOneWidget);
      expect(find.text('Pour les petits colis et documents'), findsOneWidget);
      expect(find.text('Récupération et livraison gratuits des articles porte-à-porte'), findsOneWidget);
      expect(find.text('Vous pouvez envoyer plusieurs petits articles d\'un poids total jusqu\'à 10 kg'), findsOneWidget);
      expect(find.text('Il est préférable d\'emballer soigneusement les articles fragiles pour les garder en sécurité'), findsOneWidget);
      expect(find.text('Le destinataire et vous pouvez suivre la livraison en temps réel'), findsOneWidget);
      expect(find.text('J\'ai compris'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Close via J'ai compris
      await tester.tap(find.text('J\'ai compris'));
      await tester.pumpAndSettle();

      expect(find.text('EXPRESS MOTO'), findsNothing);
    });

    testWidgets('DeliveryInfoModal displays correctly for Express Cargo and closes via close icon',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DeliveryInfoModal.show(context, deliveryType: 'cargo'),
                child: const Text('Open Cargo Info'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Cargo Info'));
      await tester.pumpAndSettle();

      expect(find.text('EXPRESS CARGO'), findsOneWidget);
      expect(find.text('Transportez de gros volumes'), findsOneWidget);
      expect(find.text('Une personne aidera à charger ou décharger les objets lourds (si l\'option correspondante est choisie).'), findsOneWidget);
      expect(find.text('Un seul siège pour le passager'), findsOneWidget);
      expect(find.text('Les véhicules transportent des charges d\'un poids maximal de 1 500 kg.'), findsOneWidget);
      expect(find.text('J\'ai compris'), findsOneWidget);

      // Close via close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('EXPRESS CARGO'), findsNothing);
    });

    testWidgets('Tapping info icon on DeliveryBookingPage opens DeliveryInfoModal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          const DeliveryBookingPage(
            initialOrigin: 'Rue FN-48, 12',
            initialOriginLocation: LatLng(14.6928, -17.4730),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand sheet so info icon in top header is visible
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      // Tap info icon
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryInfoModal), findsOneWidget);
      expect(find.text('EXPRESS MOTO'), findsOneWidget);

      // Close via J'ai compris
      await tester.tap(find.text('J\'ai compris'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryInfoModal), findsNothing);
    });

    testWidgets('DeliveryAddressDetailsModal displays correctly and opens attachment menu',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      DeliveryAddressDetails? returnedDetails;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedDetails = await DeliveryAddressDetailsModal.show(
                    context,
                    address: 'Centre D\'imagerie Diagnostique',
                    location: const LatLng(14.6928, -17.4730),
                    isPickup: true,
                  );
                },
                child: const Text('Open Address Details'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Address Details'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryAddressDetailsModal), findsOneWidget);
      expect(find.text('De'), findsOneWidget);
      expect(find.text('Centre D\'imagerie Diagnostique'), findsOneWidget);
      expect(find.text('Entrée'), findsOneWidget);
      expect(find.text('Appartement'), findsOneWidget);
      expect(find.text('Étage'), findsOneWidget);
      expect(find.text('Interphone'), findsOneWidget);
      expect(find.text('Commentaire'), findsOneWidget);
      expect(find.text('Contact'), findsOneWidget);
      expect(find.text('+221784226719'), findsOneWidget);

      // Tap paperclip (trombone) attachment icon
      await tester.tap(find.byIcon(Icons.attach_file));
      await tester.pumpAndSettle();

      expect(find.text('Photothèque'), findsOneWidget);
      expect(find.text('Prendre une photo'), findsOneWidget);
      expect(find.text('Parcourir les fichiers'), findsOneWidget);

      // Tap Photothèque option
      await tester.tap(find.text('Photothèque'));
      await tester.pumpAndSettle();

      expect(find.text('Photo_1.jpg'), findsOneWidget);

      // Enter details and submit
      await tester.enterText(find.widgetWithText(TextField, 'Entrée'), 'Bâtiment B');
      await tester.enterText(find.widgetWithText(TextField, 'Appartement'), '12A');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryAddressDetailsModal), findsNothing);
      expect(returnedDetails, isNotNull);
      expect(returnedDetails!.address, equals('Centre D\'imagerie Diagnostique'));
      expect(returnedDetails!.entry, equals('Bâtiment B'));
      expect(returnedDetails!.apartment, equals('12A'));
      expect(returnedDetails!.attachments, contains('Photo_1.jpg'));
    });

    testWidgets('DeliveryAddressDetailsModal header tap opens search and updates address',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      DeliveryAddressDetails? returnedDetails;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedDetails = await DeliveryAddressDetailsModal.show(
                    context,
                    address: 'Point initial',
                    location: const LatLng(14.6928, -17.4730),
                    isPickup: true,
                  );
                },
                child: const Text('Open Details'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryAddressDetailsModal), findsOneWidget);
      expect(find.text('Point initial'), findsOneWidget);

      // Tap header row to change address
      await tester.tap(find.text('Point initial'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryDestinationSearchModal), findsOneWidget);

      // Select one of the default places in the search modal
      final placeFinder = find.text('Centre D\'imagerie Diagnostique');
      if (placeFinder.evaluate().isNotEmpty) {
        await tester.tap(placeFinder.first);
        await tester.pumpAndSettle();
      } else {
        // Close search if list is different
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
      }

      // Tap Terminé
      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryAddressDetailsModal), findsNothing);
      expect(returnedDetails, isNotNull);
    });

    testWidgets('DeliveryItineraryPage displays route stops and burger handle actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      DeliveryItineraryResult? result;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await DeliveryItineraryPage.show(
                    context,
                    pickupLocation: const LatLng(14.6928, -17.4730),
                    pickupAddress: 'Centre D\'imagerie Diagnostique',
                    destinationLocation: const LatLng(14.6937, -17.4441),
                    destinationAddress: 'Fass Delorme',
                  );
                },
                child: const Text('Open Itinerary'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Itinerary'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryItineraryPage), findsOneWidget);
      expect(find.text('Itinéraire'), findsOneWidget);
      expect(find.text('Depuis'), findsOneWidget);
      expect(find.text('Centre D\'imagerie Diagnostique'), findsOneWidget);
      expect(find.text('Vers'), findsOneWidget);
      expect(find.text('Fass Delorme'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNWidgets(2));
      expect(find.text('Terminer'), findsOneWidget);

      // Tap Terminer button
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryItineraryPage), findsNothing);
      expect(result, isNotNull);
      expect(result!.pickupAddress, equals('Centre D\'imagerie Diagnostique'));
      expect(result!.destinationAddress, equals('Fass Delorme'));
    });

    testWidgets('DeliveryContactPickerModal displays contacts, handles search and selects a contact',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      ContactItem? selectedContact;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedContact = await DeliveryContactPickerModal.show(
                    context,
                    isExpediteur: true,
                    currentPhone: '+221784226719',
                  );
                },
                child: const Text('Open Contacts'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Contacts'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryContactPickerModal), findsOneWidget);
      expect(find.text('Expéditeur'), findsOneWidget);
      expect(
        find.textContaining('Envoyez-lui un lien de suivi de la livraison'),
        findsOneWidget,
      );
      expect(find.text('Moi'), findsOneWidget);
      expect(find.text('Ne pas lui communiquer'), findsOneWidget);
      expect(find.text('Abibatou diao innov'), findsOneWidget);

      // Search for specific contact
      await tester.enterText(
        find.widgetWithText(TextField, 'Saisissez un nom ou un numéro de téléphone'),
        'Aïda',
      );
      await tester.pumpAndSettle();

      expect(find.text('Aïda Top'), findsOneWidget);
      expect(find.text('+221774111178'), findsOneWidget);

      // Tap on contact
      await tester.tap(find.text('Aïda Top'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryContactPickerModal), findsNothing);
      expect(selectedContact, isNotNull);
      expect(selectedContact!.name, equals('Aïda Top'));
      expect(selectedContact!.phone, equals('+221774111178'));
    });

    testWidgets('DeliveryDestinationSearchModal displays Point de départ when isPickup is true',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await DeliveryDestinationSearchModal.show(
                    context,
                    placesService: PlacesService(),
                    isPickup: true,
                    title: 'Point de départ',
                  );
                },
                child: const Text('Open Pickup Search'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Pickup Search'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryDestinationSearchModal), findsOneWidget);
      expect(find.text('Point de départ'), findsOneWidget);
      expect(find.text('Où récupérer le colis ?'), findsOneWidget);
      expect(find.text('Choisir sur la carte'), findsOneWidget);
      expect(find.text('Placer le point de départ manuellement'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryDestinationSearchModal), findsNothing);
    });

    testWidgets('DeliveryOrderDetailsPage displays unified address details and handles options and submission',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          const DeliveryOrderDetailsPage(
            pickupAddress: 'Centre D\'imagerie Diagnostique',
            destinationAddress: 'Grand Yoff',
            pickupLocation: LatLng(14.6928, -17.4730),
            destinationLocation: LatLng(14.7300, -17.4600),
            selectedTimeOption: '2hours',
            courierChoice: 'any',
            estimatedPrice: 900,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title & subtitle
      expect(find.text('Dans 2 heures'), findsOneWidget);
      expect(find.text('N\'importe quel coursier à proximité'), findsOneWidget);

      // Main question heading
      expect(find.text('Quelle option est la plus pratique ?'), findsOneWidget);

      // Options: Porte-à-porte & À l'entrée
      expect(find.text('Porte-à-porte'), findsOneWidget);
      expect(find.text('Le coursier se rendra à votre étage'), findsOneWidget);
      expect(find.text('À l\'entrée'), findsOneWidget);
      expect(find.text('Vous rejoignez le coursier à l\'extérieur'), findsOneWidget);

      // Unified card with both addresses
      expect(find.text('Centre D\'imagerie Diagnostique'), findsOneWidget);
      expect(find.text('Grand Yoff'), findsOneWidget);
      expect(find.text('Entrée'), findsNWidgets(2));
      expect(find.text('Appartement'), findsNWidgets(2));
      expect(find.text('Étage'), findsNWidgets(2));
      expect(find.text('Interphone'), findsNWidgets(2));
      expect(find.text('Commentaire'), findsNWidgets(2));
      expect(find.text('Contact'), findsNWidgets(2));

      // Bottom bar initial state (neither option selected)
      expect(find.text('Choisissez le mode de\nlivraison'), findsOneWidget);
      expect(find.textContaining('Prise en charge avant'), findsOneWidget);
      expect(find.textContaining('Livraison avant'), findsOneWidget);
      expect(find.textContaining('à partir de 900 F'), findsOneWidget);

      // Tap Porte-à-porte
      await tester.tap(find.text('Porte-à-porte'));
      await tester.pumpAndSettle();

      // Button now changes to "Commander la livraison"
      expect(find.text('Commander la livraison'), findsOneWidget);
      expect(find.textContaining('à partir de 1000 F'), findsOneWidget);
    });

    testWidgets('DeliveryTimeOptionInfoModal displays correctly for 30 minutes de plus and closes via J\'ai compris',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DeliveryTimeOptionInfoModal.show(
                  context,
                  title: '30 minutes de plus',
                  timeOptionId: '30min',
                ),
                child: const Text('Open 30min Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open 30min Modal'));
      await tester.pumpAndSettle();

      expect(find.text('30 minutes de plus'), findsOneWidget);
      expect(find.textContaining('Votre commande sera moins chère'), findsOneWidget);
      expect(find.textContaining('Prise en charge chez l’expéditeur'), findsOneWidget);
      expect(find.textContaining('Livraison au destinataire'), findsOneWidget);
      expect(find.text('J’ai compris'), findsOneWidget);

      await tester.tap(find.text('J’ai compris'));
      await tester.pumpAndSettle();

      expect(find.text('30 minutes de plus'), findsNothing);
    });

    testWidgets('Tapping 30 minutes de plus or Dans 2 heures in DeliveryOrderFormModal opens DeliveryTimeOptionInfoModal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: DeliveryOrderFormModal(
              pickupAddress: 'Rue FN-55, 175',
              destinationAddress: 'Avenue Cheikh Anta Diop',
              deliveryType: 'moto',
              estimatedPrice: 700,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on "30 minutes de plus"
      await tester.ensureVisible(find.text('30 minutes de plus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 minutes de plus'));
      await tester.pumpAndSettle();

      // Modal should be visible
      expect(find.byType(DeliveryTimeOptionInfoModal), findsOneWidget);
      expect(find.text('30 minutes de plus'), findsNWidgets(2)); // Tile + Modal
      expect(find.text('J’ai compris'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('J’ai compris'));
      await tester.pumpAndSettle();

      // Modal is closed
      expect(find.byType(DeliveryTimeOptionInfoModal), findsNothing);

      // Tap on "Dans 2 heures"
      await tester.ensureVisible(find.text('Dans 2 heures'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dans 2 heures'));
      await tester.pumpAndSettle();

      // Modal for 2 hours should be visible
      expect(find.byType(DeliveryTimeOptionInfoModal), findsOneWidget);
      expect(find.text('Dans 2 heures'), findsNWidgets(2)); // Tile + Modal
      expect(find.text('J’ai compris'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('J’ai compris'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryTimeOptionInfoModal), findsNothing);
    });

    testWidgets('Filled details in preview modal automatically pre-fill DeliveryOrderDetailsPage',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: DeliveryOrderFormModal(
              pickupAddress: 'Rue FN-55, 175',
              destinationAddress: 'Avenue Cheikh Anta Diop',
              deliveryType: 'moto',
              estimatedPrice: 700,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Ouvrir le modal d'aperçu de départ en cliquant sur "Point de départ"
      await tester.tap(find.text('Point de départ'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryAddressDetailsModal), findsOneWidget);

      // Saisir des détails dans les champs de l'aperçu
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(5)); // Entrée, Appartement, Étage, Interphone, Commentaire

      await tester.enterText(textFields.at(0), 'Bâtiment A');
      await tester.enterText(textFields.at(1), 'Appt 12');
      await tester.enterText(textFields.at(2), '3ème étage');
      await tester.enterText(textFields.at(3), 'Sonner 12');
      await tester.enterText(textFields.at(4), 'Code 1234');
      await tester.pumpAndSettle();

      // Valider via le bouton "Terminé"
      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryAddressDetailsModal), findsNothing);

      // 2. Cliquer sur "Saisissez les détails" pour accéder à la page récapitulative
      expect(find.text('Saisissez les détails'), findsOneWidget);
      await tester.tap(find.text('Saisissez les détails'));
      await tester.pumpAndSettle();

      // 3. Vérifier qu'on est sur DeliveryOrderDetailsPage et que les champs sont bien pré-remplis
      expect(find.byType(DeliveryOrderDetailsPage), findsOneWidget);
      expect(find.text('Bâtiment A'), findsOneWidget);
      expect(find.text('Appt 12'), findsOneWidget);
      expect(find.text('3ème étage'), findsOneWidget);
      expect(find.text('Sonner 12'), findsOneWidget);
      expect(find.text('Code 1234'), findsOneWidget);
    });

    testWidgets('DeliveryTrackingSheet renders step 1 (Image 1) and opens DeliveryOrderSummaryModal (Image 3)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      bool cancelled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: SingleChildScrollView(
              child: DeliveryTrackingSheet(
                pickupAddress: 'Rue LIB-41, 165',
                destinationAddress: 'Rue YF-644, 206',
                pickupPhone: '+221784226719',
                destinationPhone: '+221784226719',
                price: 500,
                paymentMethod: 'Espèces',
                initialStep: 1,
                onCancelOrder: () => cancelled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En-tête étape 1 (Image 1)
      expect(find.textContaining('Récupération avant'), findsOneWidget);
      expect(find.text('Cela prend généralement moins de 15 minutes'), findsOneWidget);

      // Boutons circulaires étape 1
      expect(find.textContaining('Préciser les'), findsOneWidget);
      expect(find.text('Partager'), findsOneWidget);

      // Switch
      expect(find.text('Montrer au coursier où je me trouve'), findsOneWidget);

      // Modalité de paiement
      expect(find.text('Espèces'), findsOneWidget);
      expect(find.text('500 F'), findsOneWidget);

      // Section Expéditeur & Destinataire
      expect(find.text('Expéditeur'), findsOneWidget);
      expect(find.text('Destinataire'), findsOneWidget);
      expect(find.text('Rue LIB-41, 165'), findsOneWidget);
      expect(find.text('Rue YF-644, 206'), findsOneWidget);
      expect(find.text('+221784226719'), findsNWidgets(2));

      // Bouton Annuler
      expect(find.text('Annuler la commande'), findsOneWidget);

      // Ouvrir le modal Détails de la commande (Image 3)
      await tester.tap(find.text('Détails de la commande'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryOrderSummaryModal), findsOneWidget);
      expect(find.text('Détails de la commande'), findsNWidgets(2)); // row + modal
      expect(find.text('classe de service Le jour même'), findsOneWidget);
      expect(find.text('Prix'), findsOneWidget);
      expect(find.text('Modalité de paiement'), findsNWidgets(2)); // Tracking row + Modal title
    });

    testWidgets('DeliveryTrackingSheet renders step 2 (Image 2) with driver assigned and handles cancellation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      bool cancelled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: SingleChildScrollView(
              child: DeliveryTrackingSheet(
                pickupAddress: 'Rue LIB-41, 165',
                destinationAddress: 'Rue YF-644, 206',
                pickupPhone: '+221784226719',
                destinationPhone: '+221784226719',
                price: 500,
                paymentMethod: 'Espèces',
                initialStep: 2,
                onCancelOrder: () => cancelled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En-tête étape 2 (Image 2)
      expect(find.text('Prise en charge dans ≈4 min'), findsOneWidget);
      expect(find.textContaining('Livraison d\'autres commandes'), findsOneWidget);

      // Profil du coursier assigné
      expect(find.text('Amour Juslaure Marland'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);

      // Boutons actions coursier
      expect(find.textContaining('Appeler'), findsOneWidget);
      expect(find.textContaining('Chat avec'), findsOneWidget);
      expect(find.textContaining('Préciser les'), findsOneWidget);

      // Test annulation avec affichage de l'écran d'annulation complet (Images 1 & 2)
      await tester.ensureVisible(find.text('Annuler la commande'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler la commande'));
      await tester.pumpAndSettle();

      // Titre "Commande annulée" et profil chauffeur figé
      expect(find.text('Commande annulée'), findsOneWidget);
      expect(find.text('Amour Juslaure Marland'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);

      // Raisons d'annulation présentes et sélectionnables
      expect(find.text('La livraison n\'est plus nécessaire'), findsOneWidget);
      expect(find.text('Attente trop longue'), findsOneWidget);
      await tester.tap(find.text('Attente trop longue'));
      await tester.pumpAndSettle();

      // Champ "Pouvez-vous décrire le problème ?"
      expect(find.text('Pouvez-vous décrire le problème ?'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Le livreur est trop en retard',
      );
      await tester.pumpAndSettle();
      expect(find.text('Le livreur est trop en retard'), findsOneWidget);

      // Modalité 0F et Détails de la commande
      expect(find.text('0F'), findsOneWidget);
      expect(find.text('Le jour même · 0F'), findsOneWidget);

      // Les sections Expéditeur / Destinataire ne doivent pas rediriger (isClickable: false)
      await tester.tap(find.text('Rue LIB-41, 165'));
      await tester.pumpAndSettle();
      expect(find.byType(DeliveryUpdateOrderModal), findsNothing);

      // Clic sur "Terminer"
      await tester.ensureVisible(find.text('Terminer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets(
        'DeliveryTrackingSheet cancellation at step 1 displays subtitle without driver (Image 3)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      bool cancelled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: SingleChildScrollView(
              child: DeliveryTrackingSheet(
                pickupAddress: 'Rue LIB-41, 165',
                destinationAddress: 'Rue DSM-358',
                pickupPhone: '+221784226719',
                destinationPhone: '+221784226719',
                price: 600,
                initialStep: 1,
                onCancelOrder: () => cancelled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clic sur "Annuler la commande"
      await tester.ensureVisible(find.text('Annuler la commande'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler la commande'));
      await tester.pumpAndSettle();

      // Titre "Commande annulée" et sous-titre (Image 3)
      expect(find.text('Commande annulée'), findsOneWidget);
      expect(
        find.text('Veuillez recommander si vous avez annulé par accident'),
        findsOneWidget,
      );

      // Pas de raisons d'annulation ni profil coursier
      expect(find.text('Amour Juslaure Marland'), findsNothing);
      expect(find.text('La livraison n\'est plus nécessaire'), findsNothing);

      // Détails de la commande avec 'Any nearest slow · 0F'
      expect(find.text('0F'), findsOneWidget);
      expect(find.text('Any nearest slow · 0F'), findsOneWidget);

      // Clic sur Terminer
      await tester.ensureVisible(find.text('Terminer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets(
        'DeliveryUpdateOrderModal displays according to reference screenshot and saves updated details',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      DeliveryAddressDetails? savedPickup;
      DeliveryAddressDetails? savedDestination;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: DeliveryUpdateOrderModal(
              pickupAddress: 'Rue LIB-41, 165',
              destinationAddress: 'Rue DSM-358',
              initialPickupDetails: const DeliveryAddressDetails(
                address: 'Rue LIB-41, 165',
                entry: 'Bâtiment A',
                apartment: '12',
                floor: '3',
                intercom: '12',
                comment: 'Laisser au gardien',
                contactPhone: '+221784226719',
              ),
              initialDestinationDetails: const DeliveryAddressDetails(
                address: 'Rue DSM-358',
                entry: 'Villa 5',
                apartment: 'Bureau 2',
                floor: 'RDC',
                intercom: '5',
                comment: 'Sonner fort',
                contactPhone: 'Ne pas lui communiquer',
              ),
              onSave: (p, d) {
                savedPickup = p;
                savedDestination = d;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En-tête et sous-titre
      expect(find.text('Mettez à jour votre commande'), findsOneWidget);
      expect(
        find.textContaining('Ces modifications n\'auront pas d\'incidence'),
        findsOneWidget,
      );

      // Section Expéditeur (De)
      expect(find.text('De'), findsOneWidget);
      expect(find.text('Rue LIB-41, 165'), findsOneWidget);
      expect(find.text('Bâtiment A'), findsOneWidget);
      expect(find.text('12'), findsNWidgets(2)); // appt and intercom
      expect(find.text('Laisser au gardien'), findsOneWidget);
      expect(find.text('+221784226719'), findsOneWidget);

      // Section Destinataire (Vers)
      expect(find.text('Vers'), findsOneWidget);
      expect(find.text('Rue DSM-358'), findsOneWidget);
      expect(find.text('Villa 5'), findsOneWidget);
      expect(find.text('Bureau 2'), findsOneWidget);
      expect(find.text('Sonner fort'), findsOneWidget);
      expect(find.text('Ne pas lui communiquer'), findsOneWidget);

      // "Numéro de contact" doit toujours être affiché en entier sans "..."
      expect(find.text('Numéro de contact'), findsNWidgets(2));

      // Cadenas
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));

      // Bouton Enregistrer
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(savedPickup, isNotNull);
      expect(savedPickup!.entry, 'Bâtiment A');
      expect(savedPickup!.contactPhone, '+221784226719');
      expect(savedDestination, isNotNull);
      expect(savedDestination!.entry, 'Villa 5');
      expect(savedDestination!.contactPhone, 'Ne pas lui communiquer');
    });

    testWidgets('DeliveryCallCourierModal displays in-app and phone options',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      const driver = DriverModel(
        id: 'courier_1',
        name: 'Amour Juslaure Marland',
        phone: '+221784226719',
        rating: 4.9,
        totalRides: 100,
        carModel: 'Moto',
        carColor: 'Rouge',
        licensePlate: 'DK-1234',
        rideType: RideType.eco,
        currentLocation: LatLng(14.7167, -17.4677),
        etaMinutes: 4,
        distanceKm: 1.0,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: DeliveryCallCourierModal(driver: driver),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appeler le coursier'), findsOneWidget);
      expect(find.textContaining('Amour Juslaure Marland'), findsOneWidget);
      expect(find.text('Appeler dans l\'application'), findsOneWidget);
      expect(find.text('Appeler par téléphone'), findsOneWidget);
      expect(find.text('Gratuit'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets(
        'Tapping Préciser les détails in DeliveryTrackingSheet opens DeliveryUpdateOrderModal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(
              child: DeliveryTrackingSheet(
                pickupAddress: 'Rue LIB-41, 165',
                destinationAddress: 'Rue DSM-358',
                pickupPhone: '+221784226719',
                destinationPhone: '+221784226719',
                price: 600,
                initialStep: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clic sur "Préciser les détails de l'adresse"
      await tester.tap(find.textContaining('Préciser les'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryUpdateOrderModal), findsOneWidget);
      expect(find.text('Mettez à jour votre commande'), findsOneWidget);
    });

    testWidgets(
        'Tapping Appeler le coursier in DeliveryTrackingSheet opens DeliveryCallCourierModal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(
              child: DeliveryTrackingSheet(
                pickupAddress: 'Rue LIB-41, 165',
                destinationAddress: 'Rue DSM-358',
                pickupPhone: '+221784226719',
                destinationPhone: '+221784226719',
                price: 600,
                initialStep: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clic sur "Appeler le coursier"
      await tester.tap(find.textContaining('Appeler'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryCallCourierModal), findsOneWidget);
      expect(find.text('Appeler le coursier'), findsOneWidget);
      expect(find.text('Appeler\nle coursier'), findsOneWidget);
      expect(find.text('Appeler dans l\'application'), findsOneWidget);
      expect(find.text('Appeler par téléphone'), findsOneWidget);
    });
  });
}
