// Pin picker: the customer taps the map (or searches) to drop a pin
// for the exact service address. Returns a PinResult to the caller
// (BookingScreen) — the pin is optional there, booking without one
// still works exactly as before.
//
// Works with no GPS permission (city centre default) and with no
// network for tiles (the map may be blank, but pin / address /
// search-error handling never crashes). Reverse-geocoding runs once
// per pin placement, never continuously while the map moves.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/map_api.dart';
import '../theme.dart';

/// The picked point + the (editable) address text + city, returned via
/// Navigator.pop when the user confirms.
class PinResult {
  final LatLng point;
  final String addressText;
  final String city;
  const PinResult({
    required this.point,
    required this.addressText,
    required this.city,
  });
}

class PinPickerScreen extends StatefulWidget {
  final String city;
  final LatLng? initialPoint;
  const PinPickerScreen({super.key, required this.city, this.initialPoint});
  @override
  State<PinPickerScreen> createState() => _PinPickerScreenState();
}

class _PinPickerScreenState extends State<PinPickerScreen> {
  final _mapController = MapController();
  final _mapApi = MapApi();
  final _address = TextEditingController();
  final _search = TextEditingController();

  late LatLng _center;
  LatLng? _pin;
  bool _mapReady = false;
  bool _resolving = false;
  bool _addressFailed = false;
  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _center = widget.initialPoint ??
        kCityCenters[widget.city] ??
        const LatLng(31.5204, 74.3587); // Lahore fallback
    if (widget.initialPoint != null) {
      _pin = widget.initialPoint;
      _resolveAddress(_pin!);
    } else {
      // No pin yet: start on the customer's own position when GPS is
      // available (city centre above stays until the fix arrives, and
      // Lahore is only the last-resort fallback). No pin is dropped —
      // the customer taps to place one.
      _locateMe();
    }
  }

  /// Centre the map on the device position when available. Never
  /// throws, never blocks the screen; on failure the city centre stays.
  Future<void> _locateMe() async {
    final pos = await getCurrentPosition();
    if (!mounted || _pin != null) return;
    if (pos == null) return;
    setState(() => _center = pos);
    if (_mapReady) _mapController.move(pos, 15);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _address.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Drop (or move) the pin, then reverse-geocode it exactly once.
  void _placePin(LatLng point, {bool moveMap = true}) {
    setState(() {
      _pin = point;
      _center = point;
      _suggestions = [];
      _searchError = null;
    });
    if (moveMap && _mapReady) _mapController.move(point, 15);
    _resolveAddress(point);
  }

  Future<void> _resolveAddress(LatLng point) async {
    setState(() {
      _resolving = true;
      _addressFailed = false;
    });
    final name = await _mapApi.reverseGeocode(point);
    if (!mounted) return;
    setState(() {
      _resolving = false;
      if (name != null && name.isNotEmpty) {
        _address.text = name;
      } else {
        _addressFailed = true;
      }
    });
  }

  Future<void> _useMyLocation() async {
    final pos = await getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permission nahi mili — city centre dikhaya ja raha hai'),
        ),
      );
      return;
    }
    _placePin(pos);
  }

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

  void _confirm() {
    final pin = _pin;
    if (pin == null) return;
    Navigator.of(context).pop(PinResult(
      point: pin,
      addressText: _address.text.trim(),
      city: widget.city,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick location on map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Use my location',
            onPressed: _useMyLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onMapReady: () => _mapReady = true,
              onTap: (_, point) => _placePin(point, moveMap: false),
              onLongPress: (_, point) => _placePin(point, moveMap: false),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.projectservices.app',
              ),
              if (_pin != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pin!,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on,
                          color: AppColors.red, size: 44),
                    ),
                  ],
                ),
            ],
          ),
          // Address search at the top.
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search a place — Airport Road…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
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
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: _searchPlaces,
                            ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
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
                        style: const TextStyle(color: AppColors.red)),
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
                          onTap: () => _placePin(
                              LatLng(s.latitude, s.longitude)),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Bottom address bar + confirm.
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: AppColors.red, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _pin == null
                                ? 'Map pe tap kar ke pin lagayein'
                                : 'Pin lag gaya — address check kar lein',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_resolving)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _address,
                      decoration: const InputDecoration(
                        hintText: 'Address (edit kar sakte hain)',
                      ),
                    ),
                    if (_addressFailed)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Address nahi mil saka — khud likh lein',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.red),
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _pin == null ? null : _confirm,
                      child: const Text('Confirm this location'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
