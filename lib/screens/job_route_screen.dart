// Job route screen (Phase C) — provider side.
// Shows the route from the provider's current position to the customer's
// job address, and lets the provider share their live location with the
// customer while the job is active.
//
// Privacy: live location is published ONLY while this job is active
// (accepted / confirmed / on_the_way / in_progress). The location row
// is deleted ONLY on an explicit "Stop live location" tap, when the job
// reaches a terminal status (handled in _JobTile._setStatus), or when
// the provider goes offline (server-side trigger, migration 007).
// Leaving this screen must NOT delete the row — the customer would
// otherwise lose the rider the moment the provider checks another
// screen (that was the live-location bug of 18 Nov 2026).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../repository.dart';
import '../services/location_service.dart';
import '../services/map_api.dart';
import '../theme.dart';

/// Statuses in which a job is active and live location may be shared.
const Set<String> kActiveJobStatuses = {
  'accepted',
  'confirmed',
  'on_the_way',
  'in_progress',
};

/// Shown when the booking genuinely has no address at all — no pin and
/// no address text. It must NEVER appear when an address exists: the
/// 18 Nov 2026 bug showed this message while the pin existed in the
/// database, only because RLS blocked the provider from reading it
/// (fixed by migration 009).
const String kNoPinMessage =
    'Customer ne map pin nahi lagaya — address text se jayein';

/// Why live-location sharing is ending. The location row may be
/// deleted for every reason EXCEPT leaving the route screen: the row
/// is the customer's only view of the rider while the job is active.
enum LocationStopReason { explicitStop, jobTerminal, wentOffline, leftRouteScreen }

/// Pure policy (unit-tested): the live-location row is deleted on an
/// explicit stop, a terminal job status, or going offline — never just
/// because the provider left the route screen.
bool shouldDeleteLocationRow(LocationStopReason reason) =>
    reason != LocationStopReason.leftRouteScreen;

/// Pure helper (unit-tested): the Nominatim queries to try, in order,
/// when geocoding an address text. First the raw text; if a city is
/// known and not already in the text, retry with the city appended
/// (e.g. "Askari Mall, Airport Road" → "Askari Mall, Airport Road,
/// Quetta") — bare shop/street names often only resolve with the city.
List<String> geocodeQueryCandidates(String text, String? city) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return [];
  final cityName = (city ?? '').trim();
  if (cityName.isEmpty) return [trimmed];
  if (trimmed.toLowerCase().contains(cityName.toLowerCase())) {
    return [trimmed];
  }
  return [trimmed, '$trimmed, $cityName'];
}

/// Pure route-resolution helper (unit-tested in test/route_fallback_test.dart):
/// a real OSRM route wins; when fetchRoute returned null (or the route has
/// no points) the caller draws a straight line between the two points
/// instead and shows the fallback note.
({List<LatLng> points, bool isFallback}) resolveRoutePoints({
  required RouteResult? route,
  required LatLng from,
  required LatLng to,
}) {
  if (route != null && route.points.isNotEmpty) {
    return (points: route.points, isFallback: false);
  }
  return (points: [from, to], isFallback: true);
}

/// Pure destination-resolution helper (unit-tested in
/// test/route_fallback_test.dart):
/// - Delivery booking (has a pickup point): while the rider has not
///   picked up yet, the destination is the pickup point; once the job
///   is in_progress (picked up) the destination is the customer's
///   address.
/// - Normal booking: the customer's address.
/// [pickupPoint] is the pickup coordinates (from the booking row, or
/// geocoded from the pickup address text by the caller).
({LatLng? destination, String label, bool isPickup}) resolveRouteDestination({
  required Booking booking,
  required ServiceAddress? address,
  required LatLng? pickupPoint,
}) {
  const noPin = kNoPinMessage;
  final pickupLabel = (booking.pickupAddress != null &&
          booking.pickupAddress!.trim().isNotEmpty)
      ? booking.pickupAddress!.trim()
      : (booking.pickupShopName != null &&
              booking.pickupShopName!.trim().isNotEmpty)
          ? booking.pickupShopName!.trim()
          : 'Pickup point';
  final addressLabel = (address?.addressLine != null &&
          address!.addressLine!.isNotEmpty)
      ? address.addressLine!
      : noPin;
  final addressPoint = (address != null &&
          address.latitude != null &&
          address.longitude != null)
      ? LatLng(address.latitude!, address.longitude!)
      : null;

  final isDelivery = pickupPoint != null || booking.hasPickup;
  if (isDelivery && booking.status != 'in_progress') {
    // First leg: rider travels to the pickup (accepted / confirmed /
    // on_the_way). Coordinates may still be null when the pickup
    // address text could not be geocoded — the label still shows the
    // text so the rider can navigate by it.
    return (
      destination: pickupPoint,
      label: pickupLabel,
      isPickup: true,
    );
  }
  return (
    destination: addressPoint,
    label: addressLabel,
    isPickup: false,
  );
}

class JobRouteScreen extends StatefulWidget {
  final Booking booking;
  const JobRouteScreen({super.key, required this.booking});
  @override
  State<JobRouteScreen> createState() => _JobRouteScreenState();
}

class _JobRouteScreenState extends State<JobRouteScreen> {
  final MapController _mapController = MapController();
  final MapApi _mapApi = MapApi();
  final _search = TextEditingController();

  ServiceAddress? _address;
  LatLng? _pickupPoint; // Delivery bookings: resolved pickup coordinates.
  LatLng? _myPos;
  RouteResult? _route;
  bool _routeFallback = false;
  bool _loading = true;
  String? _loadError;

  // Manual destination from the map search below: when the automatic
  // resolution fails (or the rider wants a different place), the
  // provider searches a place and taps it — that becomes the
  // destination for this screen session.
  LatLng? _searchedDestination;
  String? _searchedLabel;
  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  String? _searchError;

  bool _sharing = false;
  bool _permissionOk = true;
  DateTime? _lastSharedAt;
  DateTime? _lastUploadAt;
  DateTime? _lastRouteAt;
  StreamSubscription<LatLng>? _posSub;

  bool get _jobActive => kActiveJobStatuses.contains(widget.booking.status);

  /// Resolved destination for the current leg: the pickup point for a
  /// delivery booking that has not been picked up yet, else the
  /// customer's address (see resolveRouteDestination). A place the
  /// provider picked from the map search overrides the automatic one.
  ({LatLng? destination, String label, bool isPickup})
      get _resolvedDestination => _searchedDestination != null
          ? (
              destination: _searchedDestination,
              label: _searchedLabel ?? 'Searched place',
              isPickup: false,
            )
          : resolveRouteDestination(
              booking: widget.booking,
              address: _address,
              pickupPoint: _pickupPoint,
            );

  bool get _hasDestinationCoords => _resolvedDestination.destination != null;

  LatLng? get _destination => _resolvedDestination.destination;

  String get _destinationLabel => _resolvedDestination.label;

  bool get _isPickupDestination => _resolvedDestination.isPickup;

  LatLng get _initialCenter =>
      _myPos ?? _destination ?? kCityCenters['Lahore']!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Geocode a pickup address text: raw text first, then with the
  /// booking city appended (see geocodeQueryCandidates). Returns null
  /// when Nominatim finds nothing — the caller keeps the address text
  /// as the label so the rider can still navigate by it.
  Future<LatLng?> _geocodePickup(String text, String? city) async {
    for (final query in geocodeQueryCandidates(text, city)) {
      final hits = await _mapApi.searchPlaces(query);
      if (hits.isNotEmpty) {
        return LatLng(hits.first.latitude, hits.first.longitude);
      }
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final address = await fetchBookingAddress(widget.booking.id);
      // Delivery bookings: resolve the pickup point — coordinates from
      // the booking row when the customer dropped a pin, else geocode
      // the pickup address text (Nominatim search, Pakistan; city
      // appended as a second try when the raw text finds nothing).
      LatLng? pickupPoint;
      final b = widget.booking;
      if (b.pickupLatitude != null && b.pickupLongitude != null) {
        pickupPoint = LatLng(b.pickupLatitude!, b.pickupLongitude!);
      } else if (b.pickupAddress != null && b.pickupAddress!.trim().isNotEmpty) {
        pickupPoint =
            await _geocodePickup(b.pickupAddress!, address?.city);
      }
      var myPos = await getCurrentPosition();
      myPos ??= _fallbackCenter(address?.city);
      if (!mounted) return;
      setState(() {
        _address = address;
        _pickupPoint = pickupPoint;
        _myPos = myPos;
        _loading = false;
      });
      await _fetchRoute();
      // Auto-start sharing once on the way / work started.
      if (mounted &&
          (widget.booking.status == 'on_the_way' ||
              widget.booking.status == 'in_progress')) {
        await _startSharing();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  /// City-centre fallback when the device position is unavailable:
  /// the address city (case-insensitive), else Lahore.
  LatLng _fallbackCenter(String? city) {
    final wanted = (city ?? '').trim().toLowerCase();
    for (final entry in kCityCenters.entries) {
      if (entry.key.toLowerCase() == wanted) return entry.value;
    }
    return kCityCenters['Lahore']!;
  }

  /// Fetch the OSRM route provider → destination. On failure the last
  /// good route is kept during a refresh; on first load the straight
  /// line fallback is used instead.
  Future<void> _fetchRoute({bool isRefresh = false}) async {
    final from = _myPos;
    final to = _destination;
    if (from == null || to == null) {
      if (mounted) setState(() => _routeFallback = true);
      return;
    }
    final route = await _mapApi.fetchRoute(from, to);
    if (!mounted) return;
    setState(() {
      _lastRouteAt = DateTime.now();
      if (route != null) {
        _route = route;
        _routeFallback = false;
      } else if (!isRefresh || _route == null) {
        // First load (or no good route yet): straight-line fallback.
        _routeFallback = true;
      }
      // Refresh failure with a good route already shown: keep it.
    });
  }

  Future<void> _startSharing() async {
    if (_sharing || !_jobActive) return;
    final available = await isLocationSharingAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() => _permissionOk = false);
      return;
    }
    setState(() {
      _sharing = true;
      _permissionOk = true;
    });
    _posSub = positionStream(distanceFilterMeters: 10).listen((pos) async {
      if (!mounted) return;
      setState(() => _myPos = pos);
      // Re-fetch the route at most once per 60 seconds while sharing.
      final lastRoute = _lastRouteAt;
      if (lastRoute == null ||
          DateTime.now().difference(lastRoute).inSeconds >= 60) {
        await _fetchRoute(isRefresh: true);
      }
      // Upload at most once per 10 seconds.
      final lastUpload = _lastUploadAt;
      if (lastUpload != null &&
          DateTime.now().difference(lastUpload).inSeconds < 10) {
        return;
      }
      _lastUploadAt = DateTime.now();
      try {
        await upsertMyProviderLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        if (mounted) setState(() => _lastSharedAt = DateTime.now());
      } catch (_) {
        // Best-effort: a failed upload must not stop sharing or crash.
      }
    });
    // Publish the current position immediately so the customer sees the
    // provider without waiting for the first 10 m movement.
    final now = _myPos;
    if (now != null) {
      _lastUploadAt = DateTime.now();
      try {
        await upsertMyProviderLocation(
          latitude: now.latitude,
          longitude: now.longitude,
        );
        if (mounted) setState(() => _lastSharedAt = DateTime.now());
      } catch (_) {
        // Best-effort.
      }
    }
  }

  /// Search places (Nominatim, Pakistan) for the map search bar.
  /// Suggestions appear under the field; tapping one makes it the
  /// destination for this screen session and fetches the route.
  Future<void> _searchPlaces() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
    });
    final results = await _mapApi.searchPlaces(q);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _suggestions = results;
      if (results.isEmpty) {
        _searchError = 'No places found — try another search.';
      }
    });
  }

  void _useSearchedPlace(PlaceSuggestion s) {
    setState(() {
      _searchedDestination = LatLng(s.latitude, s.longitude);
      _searchedLabel = s.displayName;
      _suggestions = [];
      _searchError = null;
      _route = null;
      _routeFallback = false;
    });
    _mapController.move(LatLng(s.latitude, s.longitude), 14);
    unawaited(_fetchRoute());
  }

  void _clearSearchedPlace() {
    setState(() {
      _searchedDestination = null;
      _searchedLabel = null;
      _route = null;
      _routeFallback = false;
    });
    unawaited(_fetchRoute());
  }

  /// Stop the position stream and delete the live-location row.
  /// Only for the explicit "Stop live location" tap — see
  /// shouldDeleteLocationRow: leaving the screen must NOT delete the
  /// row (use _pauseSharingStream for that). Never throws.
  Future<void> _stopSharing() async {
    await _posSub?.cancel();
    _posSub = null;
    if (_sharing) {
      setState(() => _sharing = false);
    }
    if (!shouldDeleteLocationRow(LocationStopReason.explicitStop)) return;
    try {
      await clearMyProviderLocation();
    } catch (_) {
      // clearMyProviderLocation is already best-effort; ignore.
    }
  }

  /// Pause the position stream when leaving this screen WITHOUT
  /// deleting the live-location row: the customer keeps seeing the
  /// rider's last-known position while the job is active, and sharing
  /// resumes automatically when the screen is opened again. The row is
  /// deleted only by an explicit stop, a terminal job status, or going
  /// offline (migration 007 trigger).
  Future<void> _pauseSharingStream() async {
    await _posSub?.cancel();
    _posSub = null;
    // Deliberately NO clearMyProviderLocation() here — see
    // shouldDeleteLocationRow(LocationStopReason.leftRouteScreen).
  }

  /// My-location button: jump the map to the provider's current GPS
  /// and move the "You" marker there. A failed/denied lookup shows a
  /// short message and never crashes.
  Future<void> _goToMyLocation() async {
    final pos = await getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permission nahi mili — apni location nahi dikhayi ja sakti'),
        ),
      );
      return;
    }
    setState(() => _myPos = pos);
    _mapController.move(pos, 15);
  }

  @override
  void dispose() {
    // Cancel the GPS stream only. The location row stays: the job is
    // still active and the customer must keep seeing the rider.
    unawaited(_pauseSharingStream());
    _mapController.dispose();
    _search.dispose();
    super.dispose();
  }

  String _timeLabel(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final resolved = (_myPos != null && _destination != null)
        ? resolveRoutePoints(route: _route, from: _myPos!, to: _destination!)
        : null;
    final showFallbackNote =
        _hasDestinationCoords && _routeFallback;
    // No coordinates at all: no line is drawn, so do NOT claim a
    // straight line is shown. The address text is already in the
    // header card above — this note only says to navigate by it, and
    // only when there IS an address text (otherwise the header already
    // says the customer left no pin/address).
    final showNoCoordsNote =
        !_hasDestinationCoords && _destinationLabel != kNoPinMessage;
    return Scaffold(
      appBar: AppBar(title: const Text('Job route')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load the route: $_loadError'),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- Header card ----
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      b.serviceName,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(statusLabel(b.status)),
                                    backgroundColor: AppColors.tealLight,
                                  ),
                                ],
                              ),
                              if (b.providerName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Customer: ${b.providerName}'),
                                ),
                              if (b.scheduledAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Scheduled: ${b.scheduledAt!.day}/${b.scheduledAt!.month}/${b.scheduledAt!.year} '
                                    '${b.scheduledAt!.hour}:${b.scheduledAt!.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        color: AppColors.inkSoft),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                _destinationLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              if (_route != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${_route!.distanceKm.toStringAsFixed(1)} km · ETA ~${_route!.durationLabel}',
                                    style: const TextStyle(
                                        color: AppColors.teal,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ---- Map search: when the automatic destination
                      // is missing or wrong, the rider searches a place
                      // (e.g. "Askari Mall") and taps it — that becomes
                      // the destination and the route is fetched.
                      Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            hintText: 'Search a place — Askari Mall…',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_searchedDestination != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    tooltip: 'Clear searched place',
                                    onPressed: _clearSearchedPlace,
                                  ),
                                _searching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : IconButton(
                                        icon:
                                            const Icon(Icons.arrow_forward),
                                        onPressed: _searchPlaces,
                                      ),
                              ],
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12),
                          ),
                          onSubmitted: (_) => _searchPlaces(),
                        ),
                      ),
                      if (_searchError != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_searchError!,
                              style:
                                  const TextStyle(color: AppColors.red)),
                        ),
                      if (_suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            itemBuilder: (context, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                leading: const Icon(Icons.location_on,
                                    color: AppColors.teal),
                                title: Text(s.displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                onTap: () => _useSearchedPlace(s),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      // ---- Map ----
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 320,
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _initialCenter,
                                  initialZoom: 13,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.projectservices.app',
                                  ),
                                  if (resolved != null)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: resolved.points,
                                          color: resolved.isFallback
                                              ? AppColors.amber
                                              : AppColors.teal,
                                          strokeWidth: 4,
                                          pattern: resolved.isFallback
                                              ? StrokePattern.dashed(
                                                  segments: const [8, 6])
                                              : const StrokePattern.solid(),
                                        ),
                                      ],
                                    ),
                                  MarkerLayer(
                                    markers: [
                                      if (_myPos != null)
                                        Marker(
                                          point: _myPos!,
                                          width: 60,
                                          height: 50,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.teal,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'You',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                              const Icon(
                                                Icons.location_on,
                                                color: AppColors.teal,
                                                size: 30,
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (_destination != null)
                                        Marker(
                                          point: _destination!,
                                          width: 40,
                                          height: 40,
                                          child: const Icon(
                                            Icons.location_on,
                                            color: AppColors.red,
                                            size: 36,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.white,
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  child: IconButton(
                                    icon: const Icon(Icons.my_location,
                                        color: AppColors.teal),
                                    tooltip: 'My location',
                                    onPressed: _goToMyLocation,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isPickupDestination)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Pickup: $_destinationLabel',
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                        )
                      else if (_address?.addressLine != null &&
                          _address!.addressLine!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Destination: ${_address!.addressLine!}'
                            '${_address!.city != null ? ' · ${_address!.city}' : ''}',
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                        ),
                      if (showFallbackNote)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Route nahi mil saka — seedhi line dikhayi ja rahi hai',
                            style: TextStyle(color: AppColors.amberDark),
                          ),
                        ),
                      if (showNoCoordsNote)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Is address ke coordinates nahi hain — upar diya gaya address parh kar jayein',
                            style: TextStyle(color: AppColors.amberDark),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // ---- Live location sharing ----
                      if (!_jobActive)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Job complete ya cancel ho gaya hai — live location sharing band hai.',
                              style: TextStyle(color: AppColors.inkSoft),
                            ),
                          ),
                        )
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _sharing ? _stopSharing : _startSharing,
                            icon: Icon(
                              _sharing
                                  ? Icons.location_off
                                  : Icons.share_location,
                            ),
                            label: Text(_sharing
                                ? 'Stop live location'
                                : 'Share live location'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_sharing && _lastSharedAt != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4EA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.circle,
                                    color: AppColors.green, size: 12),
                                const SizedBox(width: 8),
                                Text(
                                  'Sharing live • updated ${_timeLabel(_lastSharedAt!)}',
                                  style: const TextStyle(
                                      color: AppColors.green,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        if (!_permissionOk)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Location permission nahi hai — Settings se location on karein',
                              style: TextStyle(color: AppColors.red),
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Customer ko aapki live location sirf is job ke doran dikhayi jati hai.',
                            style: TextStyle(
                                color: AppColors.inkSoft, fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
