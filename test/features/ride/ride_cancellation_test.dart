import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/ride/data/models/ride_cancel_result_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/ride/presentation/widgets/cancel_ride_reason_sheet.dart';

class MockCancelAssetLoader extends AssetLoader {
  const MockCancelAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'cancelled': {
        'title': 'Course annulée',
        'free_cancellation': 'Annulation gratuite : moins de 2 min après l\'acceptation',
        'amount_refunded': 'Montant remboursé',
        'to': 'Vers',
        'to_orange_money': 'Orange Money {}',
        'status': 'Statut',
        'refunded_pill': 'Remboursé',
        'ref_orange': 'Réf. Orange',
        'reorder': 'Recommander',
        'back_home': 'Retour à l\'accueil',
      },
    };
  }
}

Widget wrapWithLocalization(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('fr')],
    path: 'assets/translations',
    fallbackLocale: const Locale('fr'),
    startLocale: const Locale('fr'),
    assetLoader: const MockCancelAssetLoader(),
    child: Builder(
      builder: (context) {
        return MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: child,
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('RideCancelResultModel Tests', () {
    test('parses standard backend JSON with fee and refundAmount', () {
      final json = {
        'fee': 500,
        'refundAmount': 3000,
        'reason': 'Le chauffeur est trop loin',
        'status': 'CANCELLED',
      };

      final model = RideCancelResultModel.fromJson(json);

      expect(model.isSuccess, isTrue);
      expect(model.fee, 500);
      expect(model.refundAmount, 3000);
      expect(model.reason, 'Le chauffeur est trop loin');
      expect(model.status, 'CANCELLED');
      expect(model.isFree, isFalse);
    });

    test('parses free cancellation with fee: 0', () {
      final json = {
        'cancelFee': 0,
        'amountRefunded': 3500,
        'reason': 'Temps d\'attente trop long',
      };

      final model = RideCancelResultModel.fromJson(json);

      expect(model.fee, 0);
      expect(model.refundAmount, 3500);
      expect(model.isFree, isTrue);
    });

    test('fallback returns full refund when free', () {
      final model = RideCancelResultModel.fallback(
        originalPrice: 2500,
        reason: 'Le chauffeur est trop loin',
      );

      expect(model.fee, 0);
      expect(model.refundAmount, 2500);
      expect(model.isFree, isTrue);
      expect(model.reason, 'Le chauffeur est trop loin');
    });
  });

  group('RideService.cancelRide HTTP Tests', () {
    test('sends POST /v1/rides/{id}/cancel with reason and returns model', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/v1/rides/ride-12345/cancel'));
            expect(options.method, 'POST');
            expect(options.data, {'reason': 'Le chauffeur est trop loin'});
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'fee': 0,
                  'refundAmount': 3500,
                  'reason': 'Le chauffeur est trop loin',
                  'status': 'CANCELLED',
                },
              ),
            );
          },
        ),
      );

      final service = RideService(dio: dio);
      final result = await service.cancelRide(
        rideId: 'ride-12345',
        reason: 'Le chauffeur est trop loin',
        originalPrice: 3500,
      );

      expect(result.isSuccess, isTrue);
      expect(result.fee, 0);
      expect(result.refundAmount, 3500);
      expect(result.reason, 'Le chauffeur est trop loin');
    });
  });

  group('CancelRideReasonSheet Widget Tests', () {
    testWidgets('renders reasons and selects reason', (WidgetTester tester) async {
      String? chosenReason;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  chosenReason = await CancelRideReasonSheet.show(
                    context,
                    isDriverAssigned: false,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Annuler la course ?'), findsOneWidget);
      expect(find.text('Le chauffeur est trop loin'), findsOneWidget);
      expect(find.text('Temps d\'attente trop long'), findsOneWidget);

      // Tap Confirm
      await tester.ensureVisible(find.text('Confirmer l\'annulation'));
      await tester.tap(find.text('Confirmer l\'annulation'));
      await tester.pumpAndSettle();

      expect(chosenReason, 'Le chauffeur est trop loin');
    });
  });

  group('RideCancelledPage Widget Tests', () {
    const testOption = RideOptionModel(
      type: RideType.eco,
      title: 'Seddo Eco',
      subtitle: 'Course standard',
      price: 3500,
      capacity: 4,
      estimatedArrival: '2 min',
      pickupDuration: '15 min',
    );

    testWidgets('renders free cancellation with 3 500 FCFA refunded',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithLocalization(
          const RideCancelledPage(
            rideOption: testOption,
            cancellationFee: 0,
            refundAmount: 3500,
            reason: 'Le chauffeur est trop loin',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Course annulée'), findsOneWidget);
      expect(
          find.text('Annulation gratuite : moins de 2 min après l\'acceptation'),
          findsOneWidget);
      expect(find.text('3500 FCFA'), findsOneWidget);
      expect(find.text('Le chauffeur est trop loin'), findsOneWidget);
    });

    testWidgets('renders fee applied when cancellationFee > 0',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithLocalization(
          const RideCancelledPage(
            rideOption: testOption,
            cancellationFee: 500,
            refundAmount: 3000,
            reason: 'Changement d\'itinéraire ou de plan',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Frais d\'annulation appliqués : 500 FCFA'), findsOneWidget);
      expect(find.text('3000 FCFA'), findsOneWidget);
      expect(find.text('500 FCFA'), findsOneWidget);
      expect(find.text('Changement d\'itinéraire ou de plan'), findsOneWidget);
    });
  });
}
