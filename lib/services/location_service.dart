// Device location for AsaanKaam (Phase A map features).
// Thin wrapper around geolocator + pure helpers (haversine distance,
// radius check, city centres) that are unit-testable without a device.
import 'dart:async';
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

/// Match a reverse-geocoded city name (e.g. from Nominatim) to one of
/// the served cities. Matches exactly (case-insensitive), or when the
/// name starts with a served city ("Quetta District", "Islamabad
/// Capital Territory"). Returns the canonical city name, or null when
/// the customer is outside the served cities.
String? matchServiceCity(String? placeCity) {
  final wanted = (placeCity ?? '').trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final city in kCityCenters.keys) {
    final name = city.toLowerCase();
    if (wanted == name || wanted.startsWith('$name ')) return city;
  }
  return null;
}

/// Neutral country-wide view of Pakistan — used ONLY as the map's very
/// first centre while live data (provider / destination / GPS) is still
/// loading. It is deliberately NOT a city: a map must never open on a
/// hardcoded city (the old bug opened every tracking map on Lahore).
const LatLng kPakistanOverview = LatLng(30.3753, 69.3451);

/// Pick a map's initial centre, in priority order:
/// provider point > destination > customer's GPS > the booking city's
/// centre. Returns null when nothing at all is known — the caller then
/// keeps the neutral [kPakistanOverview] until live data arrives.
/// Lahore is returned ONLY when the city actually is Lahore.
LatLng? resolveInitialCenter({
  LatLng? providerPoint,
  LatLng? destination,
  LatLng? gpsPoint,
  String? city,
}) {
  if (providerPoint != null) return providerPoint;
  if (destination != null) return destination;
  if (gpsPoint != null) return gpsPoint;
  final wanted = (city ?? '').trim();
  if (wanted.isEmpty) return null;
  for (final entry in kCityCenters.entries) {
    if (entry.key.toLowerCase() == wanted.toLowerCase()) return entry.value;
  }
  return null;
}

/// How long to wait for a GPS fix before giving up: the map must never
/// hang on a slow fix — callers fall back to the city centre instead.
const Duration kGpsTimeout = Duration(seconds: 6);

/// The device's current position, or null when it cannot be obtained.
/// Never throws: location services disabled, permission denied,
/// denied-forever, a slow GPS fix (see [kGpsTimeout]), or any platform
/// error all return null. Requests permission once when it is currently
/// denied.
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
    final pos =
        await Geolocator.getCurrentPosition().timeout(kGpsTimeout);
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
