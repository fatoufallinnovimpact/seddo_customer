import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/presentation/widgets/orange_money_payment_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/select_payment_method_sheet.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  final testOption = RideOptionModel(
    type: RideType.eco,
    title: 'Seddo Eco',
    subtitle: 'Arrivée dans 4 min',
    capacity: 4,
    price: 3500,
    estimatedArrival: '14:30',
    pickupDuration: '4 min',
  );

  group('SelectPaymentMethodSheet Widget Tests', () {
    testWidgets('Renders Wave, Orange Money, and Espèces options matching mockup',
        (tester) async {
      PaymentMethodType? selectedResult;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await SelectPaymentMethodSheet.show(
                    ctx,
                    initialMethod: PaymentMethodType.cash,
                  );
                },
                child: const Text('Open Methods'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Methods'));
      await tester.pumpAndSettle();

      // Verify title & all 3 payment methods
      expect(find.text('Mode de paiement'), findsOneWidget);
      expect(find.text('Wave'), findsOneWidget);
      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text('Paiement en espèces'), findsOneWidget);
      expect(find.text('Confirmer et payer'), findsOneWidget);
      expect(find.text('Paiement 100% sécurisé'), findsOneWidget);

      // Tap Wave
      await tester.tap(find.text('Wave'));
      await tester.pumpAndSettle();

      // Tap Confirmer et payer
      await tester.tap(find.text('Confirmer et payer'));
      await tester.pumpAndSettle();

      expect(selectedResult, PaymentMethodType.wave);
    });
  });

  group('OrangeMoneyPaymentSheet Multi-method Confirmation Tests', () {
    testWidgets('Renders Cash confirmation without keypad and validates',
        (tester) async {
      OrangeMoneyPaymentResult? result;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await OrangeMoneyPaymentSheet.show(
                    ctx,
                    rideOption: testOption,
                    paymentMethod: PaymentMethodType.cash,
                  );
                },
                child: const Text('Confirm Cash'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Cash'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmer le paiement'), findsOneWidget);
      expect(find.text('3500 FCFA'), findsOneWidget);
      expect(find.text('Paiement en espèces à destination'), findsOneWidget);

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(result, OrangeMoneyPaymentResult.success);
    });

    testWidgets('Renders Wave confirmation with secret code and validates',
        (tester) async {
      OrangeMoneyPaymentResult? result;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await OrangeMoneyPaymentSheet.show(
                    ctx,
                    rideOption: testOption,
                    phoneDisplay: '77 ••• 12 34',
                    paymentMethod: PaymentMethodType.wave,
                  );
                },
                child: const Text('Confirm Wave'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Wave'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmer le paiement'), findsOneWidget);
      expect(find.text('3500 FCFA'), findsOneWidget);
      expect(find.textContaining('Wave 77 ••• 12 34'), findsOneWidget);

      // Keypad inputs
      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('3'));
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(result, OrangeMoneyPaymentResult.success);
    });
  });
}
