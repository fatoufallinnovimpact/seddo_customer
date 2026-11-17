import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/payment/data/services/payment_methods_service.dart';
import 'package:seddo/features/payment/presentation/widgets/payment_method_modal.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('PaymentMethodsService tests', () {
    test('Default code is CASH and human labels are correct', () {
      final service = PaymentMethodsService();
      expect(service.currentCode, 'CASH');
      expect(PaymentMethodsService.getLabelForCode('CASH'), 'Espèces');
      expect(PaymentMethodsService.getLabelForCode('WAVE'), 'Wave');
      expect(PaymentMethodsService.getLabelForCode('ORANGE_MONEY'), 'Orange Money');
    });

    test('selectPaymentMethod updates notifier and rejects invalid code', () async {
      final service = PaymentMethodsService();
      
      final okWave = await service.selectPaymentMethod('WAVE');
      expect(okWave, isTrue);
      expect(service.currentCode, 'WAVE');

      final okInvalid = await service.selectPaymentMethod('BITCOIN');
      expect(okInvalid, isFalse);
      expect(service.currentCode, 'WAVE');

      final okCash = await service.selectPaymentMethod('CASH');
      expect(okCash, isTrue);
      expect(service.currentCode, 'CASH');
    });
  });

  group('PaymentMethodModal widget tests', () {
    testWidgets('Renders Orange, Wave, Espèces and selects options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => PaymentMethodModal.show(ctx),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Check all 3 payment options exist
      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text('Wave'), findsOneWidget);
      expect(find.text('Espèces'), findsOneWidget);
      expect(find.text('Terminer'), findsOneWidget);

      // Tap Wave option
      await tester.tap(find.text('Wave'));
      await tester.pumpAndSettle();

      // Tap Terminer button
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      // Verify modal is closed and service saved WAVE
      expect(find.text('Terminer'), findsNothing);
      expect(PaymentMethodsService().currentCode, 'WAVE');
    });
  });
}
