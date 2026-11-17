// Phase C: route fallback + live-tracking gate (pure logic, no network).
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:project_services/screens/job_route_screen.dart';
import 'package:project_services/screens/live_tracking_map.dart';
import 'package:project_services/services/map_api.dart';

void main() {
  group('resolveRoutePoints', () {
    const from = LatLng(31.5204, 74.3587);
    const to = LatLng(31.5500, 74.3500);

    test('uses the OSRM route points when fetchRoute succeeds', () {
      const route = RouteResult(
        points: [from, LatLng(31.53, 74.355), to],
        distanceMeters: 5200,
        durationSeconds: 720,
      );
      final resolved =
          resolveRoutePoints(route: route, from: from, to: to);
      expect(resolved.isFallback, isFalse);
      expect(resolved.points, hasLength(3));
      expect(resolved.points.first, from);
      expect(resolved.points.last, to);
    });

    test('falls back to a straight line when fetchRoute returns null', () {
      final resolved = resolveRoutePoints(route: null, from: from, to: to);
      expect(resolved.isFallback, isTrue);
      expect(resolved.points, [from, to]);
    });

    test('falls back to a straight line when the route has no points', () {
      const route = RouteResult(
        points: [],
        distanceMeters: 0,
        durationSeconds: 0,
      );
      final resolved =
          resolveRoutePoints(route: route, from: from, to: to);
      expect(resolved.isFallback, isTrue);
      expect(resolved.points, [from, to]);
    });
  });

  group('isLiveTrackingActive', () {
    test('active only for accepted/confirmed/on_the_way/in_progress', () {
      for (final s in [
        'accepted',
        'confirmed',
        'on_the_way',
        'in_progress',
      ]) {
        expect(isLiveTrackingActive(s), isTrue, reason: s);
      }
      for (final s in [
        'pending',
        'rejected',
        'completed',
        'cancelled',
        'disputed',
      ]) {
        expect(isLiveTrackingActive(s), isFalse, reason: s);
      }
    });
  });
}
