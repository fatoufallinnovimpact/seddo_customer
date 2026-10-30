import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/services/map_style_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapStyleService Tests', () {
    test('default map style is not empty and contains expected JSON tokens', () {
      final style = MapStyleService.style;
      expect(style, isNotEmpty);
      expect(style, contains('#F6F3EE'));
      expect(style, contains('#FFD9B8'));
      expect(style, contains('#CFE8F3'));
      expect(style, contains('poi.park'));
      expect(style, contains('landscape.man_made'));
    });

    test('loadMapStyle loads or fallbacks gracefully without throwing', () async {
      final style = await MapStyleService.loadMapStyle();
      expect(style, isNotEmpty);
      expect(style, contains('geometry'));
    });
  });
}
