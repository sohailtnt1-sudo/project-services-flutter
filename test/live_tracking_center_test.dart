// Unit tests for the live-tracking map centre selection (Task 3):
// the map must open on the provider / destination / GPS / booking city
// — never on a hardcoded Lahore.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:project_services/services/location_service.dart';

void main() {
  group('resolveInitialCenter', () {
    const quetta = LatLng(30.1798, 66.9750);
    const lahore = LatLng(31.5204, 74.3587);
    const provider = LatLng(30.2000, 67.0000);
    const destination = LatLng(30.2201, 67.0078);
    const gps = LatLng(30.1900, 66.9900);

    test('provider point wins over destination, GPS and city', () {
      expect(
        resolveInitialCenter(
          providerPoint: provider,
          destination: destination,
          gpsPoint: gps,
          city: 'Quetta',
        ),
        provider,
      );
    });

    test('destination wins over GPS and city', () {
      expect(
        resolveInitialCenter(
          destination: destination,
          gpsPoint: gps,
          city: 'Quetta',
        ),
        destination,
      );
    });

    test('GPS wins over the booking city', () {
      expect(
        resolveInitialCenter(gpsPoint: gps, city: 'Quetta'),
        gps,
      );
    });

    test('booking city centre is used when nothing else is known', () {
      expect(resolveInitialCenter(city: 'Quetta'), quetta);
      expect(resolveInitialCenter(city: 'quetta'), quetta);
      expect(resolveInitialCenter(city: '  Quetta  '), quetta);
    });

    test('Lahore is returned ONLY when the city actually is Lahore', () {
      expect(resolveInitialCenter(city: 'Lahore'), lahore);
      expect(resolveInitialCenter(city: 'Quetta'), isNot(lahore));
    });

    test('unknown city returns null — never a blind Lahore default', () {
      expect(resolveInitialCenter(city: 'Multan'), isNull);
      expect(resolveInitialCenter(city: ''), isNull);
      expect(resolveInitialCenter(city: null), isNull);
      expect(resolveInitialCenter(), isNull);
    });
  });

  group('kPakistanOverview', () {
    test('is a neutral country view, not a city', () {
      expect(kPakistanOverview.latitude, 30.3753);
      expect(kPakistanOverview.longitude, 69.3451);
      expect(kPakistanOverview, isNot(kCityCenters['Lahore']));
      expect(kPakistanOverview, isNot(kCityCenters['Quetta']));
    });
  });
}
