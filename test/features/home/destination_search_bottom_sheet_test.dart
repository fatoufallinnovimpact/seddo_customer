import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/presentation/widgets/destination_search_bottom_sheet.dart';
import 'package:seddo/services/places_service.dart';

void main() {
  group('DestinationSearchBottomSheet Tests', () {
    testWidgets(
        'Renders editable departure, clear button, orange flag, map icon, star saved places, and Dakar place list',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DestinationSearchBottomSheet(
              initialPickup: 'Rue FN-48, 12',
            ),
          ),
        ),
      );

      await tester.pump();

      // 1. Ligne départ avec icône hail, TextField éditable et bouton effacer
      expect(find.byIcon(Icons.hail_rounded), findsOneWidget);
      expect(find.text('Rue FN-48, 12'), findsOneWidget);
      expect(find.byTooltip('Effacer le point de départ'), findsOneWidget);

      // 2. Ligne arrivée avec drapeau orange direct et hint text "Où allez-vous ?"
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Où allez-vous ?'), findsOneWidget);

      // 3. Icône Carte
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);

      // 4. Ligne "Lieux enregistrés" avec l'étoile
      expect(find.text('Lieux enregistrés'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      // 5. Lieux récents avec titres de quartiers/lieux connus en grand titre
      expect(find.text('Liberté 6 Extension'), findsOneWidget);
      expect(find.text('Place 116'), findsOneWidget);
      expect(find.text('Grand Yoff'), findsOneWidget);
      expect(find.text('Point E'), findsOneWidget);
      expect(find.text('Guédiawaye'), findsOneWidget);

      // 6. Les rues se trouvent bien dans le sous-titre des adresses
      expect(find.text('Rue LIB 42, Dakar'), findsOneWidget);
      expect(find.text('8 Avenue Place 116, Dakar'), findsOneWidget);
      expect(find.text('2527 Rue DD 98, Dakar'), findsOneWidget);
      expect(find.text('Rue PE 24, Dakar'), findsOneWidget);

      // 7. Icônes d'historique avec couleur grise douce (pas trop foncée)
      final historyIcons = tester.widgetList<Icon>(
        find.byIcon(Icons.history_rounded),
      );
      expect(historyIcons.isNotEmpty, isTrue);
      expect(historyIcons.first.color, equals(AppColors.recentTripIconGrey));
    });

    testWidgets(
        'When departure is cleared, shows black current location icon and location tile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DestinationSearchBottomSheet(
              initialPickup: 'Rue FN-48, 12',
              currentAddressDetails: 'Grand Dakar',
            ),
          ),
        ),
      );

      await tester.pump();

      // Vérifier le départ initial
      expect(find.text('Rue FN-48, 12'), findsOneWidget);

      // Cliquer sur le bouton effacer le départ
      final clearDepartureButton = find.byTooltip('Effacer le point de départ');
      expect(clearDepartureButton, findsOneWidget);
      await tester.tap(clearDepartureButton);
      await tester.pump();

      // Le départ est maintenant vide
      expect(find.text('Rue FN-48, 12'), findsNothing);
      expect(find.text('Point de départ'), findsOneWidget);

      // L'icône de prise de position en NOIR apparaît dans le champ de départ
      final myLocationIcons = tester.widgetList<Icon>(
        find.byIcon(Icons.my_location_rounded),
      );
      expect(myLocationIcons.isNotEmpty, isTrue);
      expect(myLocationIcons.first.color, equals(AppColors.nearBlack));

      // La tuile "Votre position actuelle" avec l'icône en noir est affichée en tête de liste
      expect(find.text('Votre position actuelle'), findsOneWidget);

      // Cliquer sur l'icône pour reprendre la position actuelle
      final myLocationBtn = find.byTooltip('Prendre ma position actuelle');
      expect(myLocationBtn, findsOneWidget);
      await tester.tap(myLocationBtn);
      await tester.pump();

      // La position actuelle est réassignée dans le champ départ
      expect(find.text('Rue FN-48, 12'), findsOneWidget);
    });

    test(
        'sanitizePlaceHierarchy faithfully preserves backend label and address without duplicating Dakar Senegal',
        () {
      // Cas 1 : Titre et sous-titre renvoyés fidèlement tels que fournis par le backend
      final res1 = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
        'Grand Yoff',
        '2527 Rue DD 98, Dakar',
      );
      expect(res1.title, equals('Grand Yoff'));
      expect(res1.subtitle, equals('2527 Rue DD 98, Dakar'));

      // Cas 2 : Titre quartier avec rue en sous-titre
      final res2 = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
        'Liberté 6 Extension',
        'Rue LIB 42, Dakar',
      );
      expect(res2.title, equals('Liberté 6 Extension'));
      expect(res2.subtitle, equals('Rue LIB 42, Dakar'));

      // Cas 3 : Titre avec Plus Code Google Maps -> Nettoyé
      final res3 = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
        'Point E / MHJ3+JXC',
        'Rue PE 24, Dakar',
      );
      expect(res3.title, equals('Point E'));
      expect(res3.subtitle, equals('Rue PE 24, Dakar'));

      // Cas 4 : Élimination de toute répétition interne de "Dakar, Sénégal"
      final res4 = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
        'Point E',
        'Dakar, Sénégal, Dakar, Sénégal',
      );
      expect(res4.subtitle, equals('Dakar, Sénégal'));

      // Cas 5 : Label et adresse identiques ("Dakar, Sénégal" et "Dakar, Sénégal") -> aucun sous-titre dupliqué
      final res5 = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
        'Dakar, Sénégal',
        'Dakar, Sénégal',
      );
      expect(res5.title, equals('Dakar, Sénégal'));
      expect(res5.subtitle, equals(''));

      // Cas 6 : Adresse vide pour "Dakar, Sénégal" -> grand titre sans sous-titre dupliqué
      final res6 = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
        'Dakar, Sénégal',
        '',
      );
      expect(res6.title, equals('Dakar, Sénégal'));
      expect(res6.subtitle, equals(''));

      // Cas 7 : Adresse complète avec virgules reçue dans le label -> grand titre + sous-titre extraits
      final res7 = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
        'Point E, Rue PE 24, Dakar',
        '',
      );
      expect(res7.title, equals('Point E'));
      expect(res7.subtitle, equals('Rue PE 24, Dakar'));

      // Cas 8 : Quartier simple sans adresse reçue -> sous-titre "Dakar, Sénégal" toujours visible
      final res8 = DestinationSearchBottomSheet.sanitizePlaceHierarchy(
        'Almadies',
        '',
      );
      expect(res8.title, equals('Almadies'));
      expect(res8.subtitle, equals('Dakar, Sénégal'));
    });

    test('refineDakarDistrict transforms Fann-Point E-Amitie into Point E when at Point E', () {
      // Cas Point E
      expect(
        PlacesService.refineDakarDistrict(
          'Fann-Point E-Amitié',
          route: 'Rue PE 24',
          lat: 14.6912,
          lng: -17.4589,
        ),
        equals('Point E'),
      );

      // Cas Fann
      expect(
        PlacesService.refineDakarDistrict(
          'Fann-Point E-Amitié',
          route: 'Rue FN 48',
          lat: 14.6853,
          lng: -17.4682,
        ),
        equals('Fann'),
      );

      // Cas Mermoz-Sacré-Cœur
      expect(
        PlacesService.refineDakarDistrict(
          'Mermoz-Sacré-Cœur',
          route: 'Rue SC 12',
        ),
        equals('Sacré-Cœur'),
      );
    });
  });
}
