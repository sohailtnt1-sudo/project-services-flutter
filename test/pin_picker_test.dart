// Phase B tests (no network, no device): PinResult carries its values,
// and the radius-filter rule the home map uses (distance from the map
// centre <= selected radius) behaves as expected.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:project_services/screens/pin_picker_screen.dart';
import 'package:project_services/services/location_service.dart';

void main() {
  group('PinResult', () {
    test('holds point, address text and city', () {
      const r = PinResult(
        point: LatLng(31.5204, 74.3587),
        addressText: 'Mall Road, Lahore',
        city: 'Lahore',
      );
      expect(r.point, const LatLng(31.5204, 74.3587));
      expect(r.addressText, 'Mall Road, Lahore');
      expect(r.city, 'Lahore');
    });
  });

  group('home map radius filter rule', () {
    const center = LatLng(31.5204, 74.3587); // Lahore
    const near = LatLng(31.5500, 74.3500); // ~3.4 km away
    const far = LatLng(31.4504, 73.1350); // Faisalabad, ~120 km away

    test('near provider is inside the default 10 km radius', () {
      expect(isWithinRadiusKm(center, near, 10), isTrue);
    });

    test('far provider is outside 5 / 10 / 25 km radii', () {
      expect(isWithinRadiusKm(center, far, 5), isFalse);
      expect(isWithinRadiusKm(center, far, 10), isFalse);
      expect(isWithinRadiusKm(center, far, 25), isFalse);
    });

    test('radius chips: 5 km excludes a ~3.4 km provider only when < 3.4', () {
      expect(isWithinRadiusKm(center, near, 5), isTrue);
      expect(isWithinRadiusKm(center, near, 1), isFalse);
    });
  });
}
