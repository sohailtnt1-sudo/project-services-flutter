// Device location for AsaanKaam (Phase A map features).
// Thin wrapper around geolocator + pure helpers (haversine distance,
// radius check, city centres) that are unit-testable without a device.
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// City centres for the 6 cities the app serves — same list as
/// kServiceCities in repository.dart. Used as the map's default centre
/// when the customer's own position is unavailable.
const Map<String, LatLng> kCityCenters = {
  'Lahore': LatLng(31.5204, 74.3587),
  'Karachi': LatLng(24.8607, 67.0011),
  'Islamabad': LatLng(33.6844, 73.0479),
  'Rawalpindi': LatLng(33.5651, 73.0169),
  'Faisalabad': LatLng(31.4504, 73.1350),
  'Quetta': LatLng(30.1798, 66.9750),
};

/// The device's current position, or null when it cannot be obtained.
/// Never throws: location services disabled, permission denied,
/// denied-forever, or any platform error all return null. Requests
/// permission once when it is currently denied.
Future<LatLng?> getCurrentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition();
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}

/// Continuous position updates, throttled by distance moved.
/// The caller must cancel the subscription on dispose.
Stream<LatLng> positionStream({int distanceFilterMeters = 10}) {
  return Geolocator.getPositionStream(
    locationSettings: LocationSettings(distanceFilter: distanceFilterMeters),
  ).map((pos) => LatLng(pos.latitude, pos.longitude));
}

/// True when the app may share the device's location right now:
/// location services on AND permission granted.
Future<bool> isLocationSharingAvailable() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  } catch (_) {
    return false;
  }
}

// ---------- Pure helpers (unit-tested, no device needed) ----------

const double _earthRadiusKm = 6371;

/// Great-circle distance between two points, in kilometres (haversine).
double distanceKmBetween(LatLng a, LatLng b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * _earthRadiusKm * math.asin(math.sqrt(h));
}

/// True when [point] lies within [radiusKm] of [center].
bool isWithinRadiusKm(LatLng center, LatLng point, double radiusKm) =>
    distanceKmBetween(center, point) <= radiusKm;
