import 'package:flutter_test/flutter_test.dart';
import 'package:crownhike_app/models/peak.dart';

void main() {
  // Grupa testów dla modelu Peak
  group('Peak Model Tests', () {
    // Test 1: Sprawdzenie poprawnego parsowania pełnych danych
    test('fromJson should correctly parse valid JSON data', () {
      // 1. GIVEN
      final Map<String, dynamic> json = {
        'id': 101,
        'name': 'Rysy',
        'region': 'Tatry Wysokie',
        'height_m': 2499,
        'difficulty': 'EXPERT',
        'main_trail_color': 'RED',
        'lat': 49.179,
        'lng': 20.088,
        'description': 'Najwyższy szczyt Polski',
      };

      // 2. WHEN
      final peak = Peak.fromJson(json);

      // 3. THEN
      expect(peak.id, 101);
      expect(peak.name, 'Rysy');
      expect(peak.elevationM, 2499);
      expect(peak.difficulty, 'EXPERT');
      expect(peak.lat, 49.179);
    });

    // Test 2: Sprawdzenie obsługi brakujących danych (null safety)
    test('fromJson should handle missing optional fields', () {
      // 1. GIVEN
      final Map<String, dynamic> json = {
        'id': 202,
        'name': 'Mały Szczyt',
        'region': 'Beskidy',
      };

      // 2. WHEN
      final peak = Peak.fromJson(json);

      // 3. THEN
      expect(peak.id, 202);
      expect(peak.name, 'Mały Szczyt');
      expect(peak.elevationM, null);
      expect(peak.difficulty, null);
    });
  });
}
