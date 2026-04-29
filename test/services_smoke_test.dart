import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecity/services/location_service.dart';
import 'package:pulsecity/services/places_service.dart';
import 'package:pulsecity/services/runtime_config_service.dart';

void main() {
  group('RuntimeConfigService', () {
    test('defaults to empty keys in test environment', () {
      expect(RuntimeConfigService.googlePlacesApiKey, isEmpty);
      expect(RuntimeConfigService.mapboxAccessToken, isEmpty);
      expect(RuntimeConfigService.hasGooglePlacesApiKey, isFalse);
      expect(RuntimeConfigService.hasMapboxAccessToken, isFalse);
    });
  });

  group('LocationService', () {
    final service = LocationService();

    test('formats short distances in meters', () {
      expect(service.formatDistance(850), '850m');
    });

    test('formats long distances in kilometers', () {
      expect(service.formatDistance(1500), '1.5km');
    });
  });

  group('PlacesService', () {
    test('returns empty photo url when config is missing', () {
      expect(PlacesService.getPhotoUrl(''), isEmpty);
      expect(PlacesService.getPhotoUrl('photo-ref'), isEmpty);
    });
  });
}
