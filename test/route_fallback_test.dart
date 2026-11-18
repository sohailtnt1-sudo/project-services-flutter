// Phase C: route fallback + live-tracking gate (pure logic, no network).
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:project_services/models.dart';
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

  group('resolveRouteDestination', () {
    const pickup = LatLng(30.1833, 66.9667);
    const customer = LatLng(30.2000, 66.9900);
    final address = ServiceAddress(
      id: 'addr-1',
      addressLine: 'House 12, Samungli Road, Quetta',
      city: 'Quetta',
      latitude: customer.latitude,
      longitude: customer.longitude,
    );

    Booking booking({
      required String status,
      String? pickupAddress,
      double? pickupLatitude,
      double? pickupLongitude,
      String? pickupShopName,
    }) =>
        Booking(
          id: 'bk-1',
          customerId: 'cust-1',
          serviceName: 'Parcel & Item Pickup',
          status: status,
          paymentStatus: 'pending',
          createdAt: DateTime(2026, 11, 18),
          pickupShopName: pickupShopName,
          pickupAddress: pickupAddress,
          pickupLatitude: pickupLatitude,
          pickupLongitude: pickupLongitude,
        );

    test('delivery on_the_way routes to the pickup point', () {
      final resolved = resolveRouteDestination(
        booking: booking(
          status: 'on_the_way',
          pickupAddress: 'Al-Madina Medical Store, Samungli Road',
          pickupLatitude: pickup.latitude,
          pickupLongitude: pickup.longitude,
        ),
        address: address,
        pickupPoint: pickup,
      );
      expect(resolved.destination, pickup);
      expect(resolved.isPickup, isTrue);
      expect(resolved.label, 'Al-Madina Medical Store, Samungli Road');
    });

    test('delivery accepted also routes to the pickup (first leg)', () {
      final resolved = resolveRouteDestination(
        booking: booking(
          status: 'accepted',
          pickupAddress: 'Al-Madina Medical Store, Samungli Road',
          pickupLatitude: pickup.latitude,
          pickupLongitude: pickup.longitude,
        ),
        address: address,
        pickupPoint: pickup,
      );
      expect(resolved.destination, pickup);
      expect(resolved.isPickup, isTrue);
    });

    test('delivery in_progress routes to the customer address', () {
      final resolved = resolveRouteDestination(
        booking: booking(
          status: 'in_progress',
          pickupAddress: 'Al-Madina Medical Store, Samungli Road',
          pickupLatitude: pickup.latitude,
          pickupLongitude: pickup.longitude,
        ),
        address: address,
        pickupPoint: pickup,
      );
      expect(resolved.destination, customer);
      expect(resolved.isPickup, isFalse);
      expect(resolved.label, 'House 12, Samungli Road, Quetta');
    });

    test('delivery with pickup text but no coords shows the text, no point',
        () {
      final resolved = resolveRouteDestination(
        booking: booking(
          status: 'on_the_way',
          pickupAddress: 'Al-Madina Medical Store, Samungli Road',
        ),
        address: address,
        pickupPoint: null,
      );
      expect(resolved.destination, isNull);
      expect(resolved.isPickup, isTrue);
      expect(resolved.label, 'Al-Madina Medical Store, Samungli Road');
    });

    test('normal booking routes to the customer address', () {
      final resolved = resolveRouteDestination(
        booking: booking(status: 'on_the_way'),
        address: address,
        pickupPoint: null,
      );
      expect(resolved.destination, customer);
      expect(resolved.isPickup, isFalse);
      expect(resolved.label, 'House 12, Samungli Road, Quetta');
    });

    test('normal booking without an address has no destination', () {
      final resolved = resolveRouteDestination(
        booking: booking(status: 'on_the_way'),
        address: null,
        pickupPoint: null,
      );
      expect(resolved.destination, isNull);
      expect(resolved.isPickup, isFalse);
      expect(resolved.label, kNoPinMessage);
    });

    test(
        'REGRESSION 18 Nov 2026: delivery booking with NO pickup data '
        'routes to the customer address when it has coords', () {
      // The live Grocery Delivery booking had pickup_* all NULL but a
      // real address pin (Askari Mall, Airport Road, Quetta). The
      // route screen must route to that pin — not show "no pin".
      final resolved = resolveRouteDestination(
        booking: booking(status: 'on_the_way'),
        address: address,
        pickupPoint: null,
      );
      expect(resolved.destination, customer);
      expect(resolved.isPickup, isFalse);
      expect(resolved.label, 'House 12, Samungli Road, Quetta');
    });
  });

  group('geocodeQueryCandidates', () {
    test('raw text only when no city is known', () {
      expect(
        geocodeQueryCandidates('Askari Mall, Airport Road', null),
        ['Askari Mall, Airport Road'],
      );
      expect(
        geocodeQueryCandidates('Askari Mall, Airport Road', ''),
        ['Askari Mall, Airport Road'],
      );
    });

    test('retries with the city appended when the text lacks it', () {
      expect(
        geocodeQueryCandidates('Askari Mall, Airport Road', 'Quetta'),
        ['Askari Mall, Airport Road', 'Askari Mall, Airport Road, Quetta'],
      );
    });

    test('no duplicate when the text already contains the city', () {
      expect(
        geocodeQueryCandidates('Askari Mall, Airport Road, Quetta', 'Quetta'),
        ['Askari Mall, Airport Road, Quetta'],
      );
      expect(
        geocodeQueryCandidates('Airport Road, QUETTA', 'Quetta'),
        ['Airport Road, QUETTA'],
      );
    });

    test('empty text yields no queries', () {
      expect(geocodeQueryCandidates('   ', 'Quetta'), isEmpty);
    });
  });

  group('shouldDeleteLocationRow', () {
    test('leaving the route screen must NOT delete the row', () {
      // REGRESSION 18 Nov 2026: dispose() deleted the row the moment
      // the provider left the route screen, so the customer almost
      // never saw the rider live.
      expect(
        shouldDeleteLocationRow(LocationStopReason.leftRouteScreen),
        isFalse,
      );
    });

    test('explicit stop, terminal status and going offline DO delete', () {
      expect(
        shouldDeleteLocationRow(LocationStopReason.explicitStop),
        isTrue,
      );
      expect(
        shouldDeleteLocationRow(LocationStopReason.jobTerminal),
        isTrue,
      );
      expect(
        shouldDeleteLocationRow(LocationStopReason.wentOffline),
        isTrue,
      );
    });
  });
}
