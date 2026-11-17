// Unit tests for the Phase A map services (no network, no device).
// Pure helpers + parsers only: haversine distance, radius check,
// Nominatim/OSRM parsers, RouteResult formatting, ProviderLocation parsing.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:project_services/models.dart';
import 'package:project_services/services/location_service.dart';
import 'package:project_services/services/map_api.dart';

void main() {
  group('distanceKmBetween (haversine)', () {
    test('Lahore centre to a nearby point is ~3.4 km', () {
      const a = LatLng(31.5204, 74.3587);
      const b = LatLng(31.5500, 74.3500);
      final d = distanceKmBetween(a, b);
      expect(d, greaterThan(3.0));
      expect(d, lessThan(3.8));
    });

    test('same point is 0 km', () {
      const a = LatLng(31.5204, 74.3587);
      expect(distanceKmBetween(a, a), 0);
    });

    test('distance is symmetric', () {
      const a = LatLng(31.5204, 74.3587);
      const b = LatLng(24.8607, 67.0011); // Karachi
      expect(distanceKmBetween(a, b), distanceKmBetween(b, a));
      expect(distanceKmBetween(a, b), greaterThan(1000));
    });
  });

  group('isWithinRadiusKm', () {
    const center = LatLng(31.5204, 74.3587);
    const near = LatLng(31.5500, 74.3500); // ~3.4 km away
    const far = LatLng(24.8607, 67.0011); // Karachi, ~1000 km away

    test('near point is within 5 km', () {
      expect(isWithinRadiusKm(center, near, 5), isTrue);
    });

    test('near point is NOT within 1 km', () {
      expect(isWithinRadiusKm(center, near, 1), isFalse);
    });

    test('far point is NOT within 5 km', () {
      expect(isWithinRadiusKm(center, far, 5), isFalse);
    });

    test('same point is within any radius', () {
      expect(isWithinRadiusKm(center, center, 0), isTrue);
    });
  });

  group('parseReverseGeocodeDisplayName', () {
    test('returns display_name when present', () {
      expect(
        parseReverseGeocodeDisplayName({
          'display_name': 'Mall Road, Lahore, Punjab, Pakistan',
          'lat': '31.5204',
          'lon': '74.3587',
        }),
        'Mall Road, Lahore, Punjab, Pakistan',
      );
    });

    test('returns null when display_name is absent', () {
      expect(parseReverseGeocodeDisplayName({'lat': '31.5204'}), isNull);
    });

    test('returns null when display_name is blank', () {
      expect(
        parseReverseGeocodeDisplayName({'display_name': '   '}),
        isNull,
      );
    });
  });

  group('parseSearchJson', () {
    test('parses 2 sample Nominatim rows', () {
      final out = parseSearchJson([
        {
          'display_name': 'Liberty Market, Lahore, Punjab, Pakistan',
          'lat': '31.5100',
          'lon': '74.3500',
        },
        {
          'display_name': 'Anarkali Bazaar, Lahore, Punjab, Pakistan',
          'lat': '31.5700',
          'lon': '74.3100',
        },
      ]);
      expect(out, hasLength(2));
      expect(out[0].displayName, 'Liberty Market, Lahore, Punjab, Pakistan');
      expect(out[0].latitude, 31.51);
      expect(out[0].longitude, 74.35);
      expect(out[1].latitude, 31.57);
    });

    test('skips rows without coordinates and returns empty for empty input',
        () {
      expect(parseSearchJson([]), isEmpty);
      expect(
        parseSearchJson([
          {'display_name': 'No coords here'},
          {'display_name': 'Bad lat', 'lat': 'abc', 'lon': '74.3'},
        ]),
        isEmpty,
      );
    });
  });

  group('parseRouteJson', () {
    test('maps [lng, lat] pairs to LatLng(lat, lng) in order', () {
      final route = parseRouteJson({
        'routes': [
          {
            'distance': 5200.0,
            'duration': 720.0,
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [74.3587, 31.5204],
                [74.3500, 31.5500],
                [74.3400, 31.5600],
              ],
            },
          },
        ],
      });
      expect(route, isNotNull);
      expect(route!.points, hasLength(3));
      expect(route.points[0], const LatLng(31.5204, 74.3587));
      expect(route.points[1], const LatLng(31.5500, 74.3500));
      expect(route.points[2], const LatLng(31.5600, 74.3400));
      expect(route.distanceMeters, 5200.0);
      expect(route.durationSeconds, 720.0);
    });

    test('returns null when routes are empty or geometry is missing', () {
      expect(parseRouteJson({'routes': []}), isNull);
      expect(parseRouteJson({}), isNull);
      expect(
        parseRouteJson({
          'routes': [
            {'distance': 100, 'duration': 60},
          ],
        }),
        isNull,
      );
    });
  });

  group('RouteResult formatting', () {
    test('distanceKm divides metres by 1000', () {
      const r = RouteResult(points: [], distanceMeters: 5200, durationSeconds: 720);
      expect(r.distanceKm, 5.2);
    });

    test('durationLabel formats seconds, minutes and hours', () {
      expect(
        const RouteResult(points: [], distanceMeters: 0, durationSeconds: 45)
            .durationLabel,
        '45 sec',
      );
      expect(
        const RouteResult(points: [], distanceMeters: 0, durationSeconds: 720)
            .durationLabel,
        '12 min',
      );
      expect(
        const RouteResult(points: [], distanceMeters: 0, durationSeconds: 3900)
            .durationLabel,
        '1 h 5 min',
      );
      expect(
        const RouteResult(points: [], distanceMeters: 0, durationSeconds: 3600)
            .durationLabel,
        '1 h',
      );
    });
  });

  group('ProviderLocation.fromMap', () {
    test('parses num lat/lng and optional fields', () {
      final loc = ProviderLocation.fromMap({
        'provider_id': 'prov-1',
        'latitude': 31.5204,
        'longitude': 74.3587,
        'accuracy_m': 12.5,
        'is_online': true,
        'updated_at': '2026-11-17T10:00:00Z',
      });
      expect(loc.providerId, 'prov-1');
      expect(loc.latitude, 31.5204);
      expect(loc.longitude, 74.3587);
      expect(loc.accuracyMeters, 12.5);
      expect(loc.isOnline, isTrue);
      expect(loc.updatedAt, DateTime.parse('2026-11-17T10:00:00Z'));
    });

    test('parses int lat/lng (num) and defaults is_online to true', () {
      final loc = ProviderLocation.fromMap({
        'provider_id': 'prov-2',
        'latitude': 31,
        'longitude': 74,
        'accuracy_m': null,
        'updated_at': '2026-11-17T10:00:00Z',
      });
      expect(loc.latitude, 31.0);
      expect(loc.longitude, 74.0);
      expect(loc.accuracyMeters, isNull);
      expect(loc.isOnline, isTrue);
    });
  });

  group('city centres', () {
    test('all 6 service cities have centres', () {
      expect(kCityCenters.keys.toSet(),
          {'Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Quetta'});
      expect(kCityCenters['Lahore'], const LatLng(31.5204, 74.3587));
      expect(kCityCenters['Quetta'], const LatLng(30.1798, 66.9750));
    });
  });
}
