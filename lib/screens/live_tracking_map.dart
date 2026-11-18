// Live tracking map (Phase C) — customer side.
// Shows the assigned technician moving live on the map, only while the
// job is active. Self-contained: owns its Realtime channel, the status
// poll timer and the route fetch.
//
// Privacy: the Realtime subscription exists ONLY while the booking is in
// an active status (accepted / confirmed / on_the_way / in_progress).
// On dispose the channel is always removed and the timer cancelled; a
// 20-second status poll also stops tracking the moment the job leaves
// the active set (completed / cancelled / rejected / disputed).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../repository.dart';
import '../services/location_service.dart';
import '../services/map_api.dart';
import '../theme.dart';
import 'job_route_screen.dart' show kActiveJobStatuses, resolveRoutePoints;

/// True when live tracking may be shown for a booking status.
bool isLiveTrackingActive(String status) =>
    kActiveJobStatuses.contains(status);

class LiveTrackingMap extends StatefulWidget {
  final Booking booking;
  const LiveTrackingMap({super.key, required this.booking});
  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  final MapController _mapController = MapController();
  final MapApi _mapApi = MapApi();

  ProviderLocation? _providerLoc;
  ServiceAddress? _address;
  RouteResult? _route;
  bool _routeFallback = false;
  bool _loading = true;
  bool _centered = false;

  RealtimeChannel? _channel;
  Timer? _pollTimer;
  String? _currentStatus;
  String? _stoppedStatus;

  LatLng? get _providerPoint => _providerLoc == null
      ? null
      : LatLng(_providerLoc!.latitude, _providerLoc!.longitude);

  LatLng? get _destination =>
      (_address != null &&
              _address!.latitude != null &&
              _address!.longitude != null)
          ? LatLng(_address!.latitude!, _address!.longitude!)
          : null;

  bool get _hasDestinationCoords => _destination != null;

  LatLng get _initialCenter =>
      _providerPoint ?? _destination ?? kCityCenters['Lahore']!;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.booking.status;
    _load();
    if (isLiveTrackingActive(widget.booking.status) &&
        widget.booking.providerId != null) {
      _subscribe();
    }
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _pollStatus());
  }

  Future<void> _load() async {
    try {
      // Last known position, so the map is not empty before the first
      // realtime event arrives.
      if (widget.booking.providerId != null) {
        final locations = await fetchProviderLocations();
        final match = locations.where(
          (l) => l.providerId == widget.booking.providerId,
        );
        if (match.isNotEmpty && mounted) {
          setState(() => _providerLoc = match.first);
        }
      }
      final address = await fetchBookingAddress(widget.booking.id);
      if (!mounted) return;
      setState(() {
        _address = address;
        _loading = false;
      });
      await _fetchRoute();
    } catch (_) {
      // Never a blank error screen: show the map with whatever is known.
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe([String? providerId]) {
    final id = providerId ?? widget.booking.providerId;
    if (id == null || _channel != null) return;
    _channel = subscribeToProviderLocation(id, (loc) {
      if (!mounted) return;
      setState(() => _providerLoc = loc);
      if (!_centered) {
        _centered = true;
        _mapController.move(
          LatLng(loc.latitude, loc.longitude),
          14,
        );
      }
      unawaited(_fetchRoute());
    });
  }

  /// Stop live tracking: remove the Realtime channel and cancel the
  /// status poll. Safe to call repeatedly.
  void _stopTracking({String? stoppedStatus}) {
    final channel = _channel;
    if (channel != null) {
      try {
        db.removeChannel(channel);
      } catch (_) {
        // Best-effort.
      }
      _channel = null;
    }
    _pollTimer?.cancel();
    _pollTimer = null;
    if (mounted) {
      setState(() => _stoppedStatus = stoppedStatus);
    }
  }

  Future<void> _pollStatus() async {
    try {
      final bookings = await fetchMyBookings();
      final match =
          bookings.where((b) => b.id == widget.booking.id);
      if (match.isEmpty || !mounted) return;
      final fresh = match.first;
      // Provider assigned after this screen opened (or the row was
      // momentarily absent): subscribe now so the rider's live
      // position appears instead of "Locating technician…" forever.
      if (fresh.providerId != null &&
          _channel == null &&
          isLiveTrackingActive(fresh.status)) {
        _subscribe(fresh.providerId);
      }
      final status = fresh.status;
      if (status == _currentStatus) return;
      setState(() => _currentStatus = status);
      if (!isLiveTrackingActive(status)) {
        _stopTracking(stoppedStatus: status);
      }
    } catch (_) {
      // A failed poll must not stop tracking; the next poll retries.
    }
  }

  Future<void> _fetchRoute() async {
    final from = _providerPoint;
    final to = _destination;
    if (from == null || to == null) return;
    final route = await _mapApi.fetchRoute(from, to);
    if (!mounted) return;
    setState(() {
      if (route != null) {
        _route = route;
        _routeFallback = false;
      } else if (_route == null) {
        _routeFallback = true;
      }
      // A failed re-fetch keeps the last good route.
    });
  }

  @override
  void dispose() {
    _stopTracking();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final providerPoint = _providerPoint;
    final destination = _destination;
    final resolved = (providerPoint != null && destination != null)
        ? resolveRoutePoints(route: _route, from: providerPoint, to: destination)
        : null;

    String headerText;
    if (_stoppedStatus != null) {
      headerText =
          'Job ${statusLabel(_stoppedStatus!)} — live tracking band ho gaya hai.';
    } else if (providerPoint == null) {
      headerText = 'Locating technician…';
    } else if (_route != null) {
      headerText =
          'Technician ${_route!.distanceKm.toStringAsFixed(1)} km away • ETA ~${_route!.durationLabel}';
    } else if (destination != null) {
      headerText =
          'Technician ${distanceKmBetween(providerPoint, destination).toStringAsFixed(1)} km away';
    } else {
      headerText = 'Technician live — on the way';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _stoppedStatus != null
                    ? Icons.location_off
                    : Icons.location_on,
                color: AppColors.teal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headerText,
                  style: const TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.projectservices.app',
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
                            ? StrokePattern.dashed(segments: const [8, 6])
                            : const StrokePattern.solid(),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (providerPoint != null)
                      Marker(
                        point: providerPoint,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.build,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    if (destination != null)
                      Marker(
                        point: destination,
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
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (b.providerId == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Abhi tak koi technician assign nahi hua.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ),
        if (!_hasDestinationCoords && _address?.addressLine != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Destination: ${_address!.addressLine!}',
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ),
        if (!_hasDestinationCoords && _address?.addressLine == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Customer ne map pin nahi lagaya — address text se jayein.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ),
        if (_routeFallback && providerPoint != null && destination != null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Route nahi mil saka — seedhi line dikhayi ja rahi hai',
              style: TextStyle(color: AppColors.amberDark),
            ),
          ),
      ],
    );
  }
}
