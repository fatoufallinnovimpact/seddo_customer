import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/services/receipt_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptPdfService Tests', () {
    test('generateReceiptPdfBytes generates valid non-empty PDF bytes', () async {
      final bytes = await ReceiptPdfService.generateReceiptPdfBytes(
        departureName: 'Sacré-Cœur 3',
        arrivalName: 'Almadies',
        departureTime: '18:19',
        arrivalTime: '18:41',
        distanceText: '7,8 km',
        durationText: '22 min',
        dateText: 'Jeudi 15 avril',
        priceText: '3 500 F',
        rideType: 'Seddo Eco',
        driverName: 'Moussa',
        driverCar: 'Toyota Corolla',
        driverPlate: 'DK 4521 AB',
        driverRating: '4',
        paymentPhone: '77 ••• 45 12',
        orangeRef: 'CI270415.1819.A3F2',
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);

      // Verify PDF header magic bytes "%PDF-"
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, equals('%PDF-'));
    });
  });
}
