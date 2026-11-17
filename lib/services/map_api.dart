// Map APIs for AsaanKaam (Phase A) — OpenStreetMap only, zero budget:
// Nominatim for reverse geocoding + place search, OSRM for routes.
// No keys needed. The http.Client is injectable (MapApi({client})) so
// unit tests never hit the network; the pure parsers below are also
// top-level functions for the same reason.
//
// Nominatim usage policy (https://operations.osmfoundation.org/policies/nominatim/):
// at most 1 request/second and an identifying User-Agent — both are
// enforced here (kNominatimMinInterval throttle + kMapUserAgent header).
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Nominatim requires at most 1 request per second.
const Duration kNominatimMinInterval = Duration(seconds: 1);

/// Identifying User-Agent required by the Nominatim usage policy.
const String kMapUserAgent =
    'AsaanKaam/1.0 (https://servicehub-tawny.vercel.app)';

const String _nominatimBase = 'https://nominatim.openstreetmap.org';
const String _osrmBase = 'https://router.project-osrm.org';

/// One place-search hit.
class PlaceSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  const PlaceSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

/// A route from OSRM: the polyline points plus distance / duration.
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000;

  /// Human label: "12 min", "1 h 5 min", "45 sec".
  String get durationLabel {
    final totalSeconds = durationSeconds.round();
    if (totalSeconds < 60) return '$totalSeconds sec';
    final minutes = totalSeconds ~/ 60;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }
}

// ---------- Pure parsers (unit-tested, no network) ----------

/// The human-readable address from a Nominatim reverse-geocode response.
String? parseReverseGeocodeDisplayName(Map<String, dynamic> json) {
  final name = json['display_name'];
  if (name is String && name.trim().isNotEmpty) return name;
  return null;
}

/// The city name from a Nominatim reverse-geocode response
/// (addressdetails=1): city, else town / village / municipality /
/// county. Returns null when none is present.
String? parseReverseGeocodeCity(Map<String, dynamic> json) {
  final address = json['address'];
  if (address is! Map<String, dynamic>) return null;
  for (final key in ['city', 'town', 'village', 'municipality', 'county']) {
    final value = address[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// Parse a Nominatim search response (a JSON array) into suggestions.
List<PlaceSuggestion> parseSearchJson(List<dynamic> json) {
  final out = <PlaceSuggestion>[];
  for (final item in json) {
    if (item is! Map<String, dynamic>) continue;
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    final name = item['display_name'];
    if (lat == null || lon == null || name is! String) continue;
    out.add(PlaceSuggestion(
      displayName: name,
      latitude: lat,
      longitude: lon,
    ));
  }
  return out;
}

/// Parse an OSRM route response. geometry.coordinates is a list of
/// [longitude, latitude] pairs — note the order, it is NOT [lat, lng].
/// Returns null when there is no route or no geometry.
RouteResult? parseRouteJson(Map<String, dynamic> json) {
  final routes = json['routes'];
  if (routes is! List || routes.isEmpty) return null;
  final first = routes.first;
  if (first is! Map<String, dynamic>) return null;
  final geometry = first['geometry'];
  if (geometry is! Map<String, dynamic>) return null;
  final coordinates = geometry['coordinates'];
  if (coordinates is! List) return null;
  final points = <LatLng>[];
  for (final pair in coordinates) {
    if (pair is! List || pair.length < 2) continue;
    final lng = (pair[0] as num?)?.toDouble();
    final lat = (pair[1] as num?)?.toDouble();
    if (lng == null || lat == null) continue;
    points.add(LatLng(lat, lng));
  }
  if (points.isEmpty) return null;
  return RouteResult(
    points: points,
    distanceMeters: (first['distance'] as num?)?.toDouble() ?? 0,
    durationSeconds: (first['duration'] as num?)?.toDouble() ?? 0,
  );
}

// ---------- Live clients ----------

class MapApi {
  final http.Client _client;

  /// Pass a client (e.g. a MockClient) in tests; defaults to a real one.
  MapApi({http.Client? client}) : _client = client ?? http.Client();

  DateTime? _lastNominatimAt;

  /// Wait until at least [kNominatimMinInterval] has passed since the
  /// last Nominatim request (usage policy: max 1 request/second).
  Future<void> _throttleNominatim() async {
    final last = _lastNominatimAt;
    if (last == null) return;
    final elapsed = DateTime.now().difference(last);
    if (elapsed < kNominatimMinInterval) {
      await Future.delayed(kNominatimMinInterval - elapsed);
    }
  }

  Map<String, String> get _nominatimHeaders => {
        'User-Agent': kMapUserAgent,
      };

  /// Raw reverse-geocode response for a point, or null on any failure.
  /// Never throws. Shared by [reverseGeocode] and [reverseGeocodeCity]
  /// so the two callers do not issue duplicate requests.
  Future<Map<String, dynamic>?> _reverseGeocodeJson(LatLng point) async {
    try {
      await _throttleNominatim();
      final uri = Uri.parse(
        '$_nominatimBase/reverse?format=jsonv2&lat=${point.latitude}'
        '&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final res = await _client.get(uri, headers: _nominatimHeaders);
      _lastNominatimAt = DateTime.now();
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return null;
      return json;
    } catch (_) {
      return null;
    }
  }

  /// Human-readable address for a point, or null on any failure.
  /// Never throws.
  Future<String?> reverseGeocode(LatLng point) async {
    final json = await _reverseGeocodeJson(point);
    if (json == null) return null;
    return parseReverseGeocodeDisplayName(json);
  }

  /// City name for a point (from the reverse-geocode address details),
  /// or null on any failure. Never throws.
  Future<String?> reverseGeocodeCity(LatLng point) async {
    final json = await _reverseGeocodeJson(point);
    if (json == null) return null;
    return parseReverseGeocodeCity(json);
  }

  /// Place suggestions for a query (Pakistan by default). Empty list on
  /// any failure. Never throws.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    String? countryCode,
  }) async {
    try {
      await _throttleNominatim();
      final uri = Uri.parse(
        '$_nominatimBase/search?format=jsonv2&q=${Uri.encodeComponent(query)}'
        '&limit=5&countrycodes=${countryCode ?? 'pk'}',
      );
      final res = await _client.get(uri, headers: _nominatimHeaders);
      _lastNominatimAt = DateTime.now();
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body);
      if (json is! List) return [];
      return parseSearchJson(json);
    } catch (_) {
      return [];
    }
  }

  /// Driving route between two points, or null on any failure — the
  /// caller falls back to a straight line. Never throws.
  Future<RouteResult?> fetchRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        '$_osrmBase/route/v1/driving/${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}?overview=full&geometries=geojson',
      );
      final res = await _client.get(uri);
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return null;
      return parseRouteJson(json);
    } catch (_) {
      return null;
    }
  }
}
