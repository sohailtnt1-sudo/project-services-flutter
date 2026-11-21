// Customer shell: bottom nav Home | Categories | Bookings | Messages | Profile.
// Home shows live categories + approved providers + an OpenStreetMap view.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/language_toggle.dart';
import '../l10n/strings.dart';
import '../models.dart';
import '../repository.dart';
import '../services/location_service.dart';
import '../services/map_api.dart';
import '../theme.dart';
import 'booking_screen.dart';
import 'chat_screen.dart';
import 'services_screen.dart';
import 'providers_screen.dart';
import 'tracking_screen.dart';

class CustomerShell extends StatefulWidget {
  final Profile profile;
  const CustomerShell({super.key, required this.profile});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _tab = 0;
  // The customer's city for this session (default Lahore). It filters
  // every provider list in the app; kept in memory only, no new
  // dependency (shared_preferences is not in pubspec.yaml).
  String _selectedCity = kDefaultCity;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(
        profile: widget.profile,
        city: _selectedCity,
        onCityChanged: (c) => setState(() => _selectedCity = c),
      ),
      _CategoriesTab(city: _selectedCity),
      const _MyBookingsTab(),
      const ConversationsScreen(),
      _ProfileTab(profile: widget.profile),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.inkSoft,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: tr('home')),
          BottomNavigationBarItem(icon: const Icon(Icons.grid_view), label: tr('categories')),
          BottomNavigationBarItem(icon: const Icon(Icons.calendar_month), label: tr('bookings')),
          BottomNavigationBarItem(icon: const Icon(Icons.message), label: tr('messages')),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: tr('profile')),
        ],
      ),
    );
  }
}

// ---------------- Home ----------------

class _HomeTab extends StatefulWidget {
  final Profile profile;
  final String city;
  final ValueChanged<String> onCityChanged;
  const _HomeTab({required this.profile, required this.city, required this.onCityChanged});
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late Future<List<Category>> _cats;
  late Future<List<Provider>> _providers;
  final _search = TextEditingController();

  // ---- Phase B: interactive map state ----
  final _mapController = MapController();
  final _mapApi = MapApi();
  // Map centre: GPS position when known, else the selected city's centre.
  LatLng _mapCenter = const LatLng(31.5204, 74.3587); // Lahore
  LatLng? _myLocation;
  bool _mapReady = false;
  // Auto city select from the first GPS fix runs once per Home visit,
  // and only while the city is still the untouched default — a city
  // the customer picked by hand is never overridden.
  bool _didAutoSelectCity = false;
  // City change that came from the GPS fix: keep the exact GPS centre
  // instead of jumping back to the city centre in didUpdateWidget.
  bool _keepGpsCenter = false;
  double _radiusKm = 10;
  List<Provider> _mapProviders = [];
  List<ProviderLocation> _locations = [];
  String? _mapError;

  static const List<double> _radiusOptions = [5, 10, 25];

  @override
  void initState() {
    super.initState();
    _cats = fetchCategories();
    _providers = fetchApprovedProviders(city: widget.city);
    _mapCenter = kCityCenters[widget.city] ?? _mapCenter;
    _loadMapData();
    _locateMe(initial: true);
  }

  @override
  void didUpdateWidget(covariant _HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city) {
      _providers = fetchApprovedProviders(city: widget.city);
      if (_keepGpsCenter) {
        // The city came from the GPS fix: the map is already centred
        // on the customer's exact position — do not jump back to the
        // city centre. Providers still reload for the new city.
        _keepGpsCenter = false;
      } else {
        // New city: re-centre on its centre and re-fetch map data.
        _mapCenter = kCityCenters[widget.city] ?? const LatLng(31.5204, 74.3587);
        if (_mapReady) _mapController.move(_mapCenter, 12);
      }
      _loadMapData();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Providers + their live locations for the map markers. The map join
  /// uses a wider provider fetch (limit 50) than the "Recommended"
  /// list below (limit 6) so markers are not capped by the list size.
  /// Providers with no location get no marker but still appear in the
  /// list below the map.
  Future<void> _loadMapData() async {
    try {
      final results = await Future.wait([
        fetchApprovedProviders(city: widget.city, limit: 50),
        fetchProviderLocations(city: widget.city),
      ]);
      if (!mounted) return;
      setState(() {
        _mapProviders = results[0] as List<Provider>;
        _locations = results[1] as List<ProviderLocation>;
        _mapError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _mapError = trf('cs_loadLocationsError', {'error': e.toString()}));
    }
  }

  /// Centre the map on the device's GPS position. Never throws and
  /// never crashes when permission is denied — the city centre stays.
  /// On the first fix, also infer the customer's city from the GPS
  /// position (reverse-geocode) and auto-select it when it is one of
  /// the served cities and the city is still the untouched default;
  /// otherwise the default stays.
  Future<void> _locateMe({bool initial = false}) async {
    final pos = await getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      if (!initial) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('cs_locationDenied')),
          ),
        );
      }
      return;
    }
    setState(() {
      _myLocation = pos;
      _mapCenter = pos;
    });
    if (_mapReady) _mapController.move(pos, 13);
    if (initial && !_didAutoSelectCity) {
      _didAutoSelectCity = true;
      if (widget.city == kDefaultCity) {
        final cityName = await _mapApi.reverseGeocodeCity(pos);
        final matched = matchServiceCity(cityName);
        if (matched != null && matched != widget.city && mounted) {
          _keepGpsCenter = true;
          widget.onCityChanged(matched);
        }
      }
    }
  }

  /// Providers with a live location, within the selected radius of the
  /// map centre. Joined on Provider.id == ProviderLocation.providerId.
  List<({Provider provider, ProviderLocation location})> get _visibleMarkers {
    final byId = {for (final p in _mapProviders) p.id: p};
    final out = <({Provider provider, ProviderLocation location})>[];
    for (final loc in _locations) {
      final p = byId[loc.providerId];
      if (p == null) continue;
      if (!isWithinRadiusKm(
          _mapCenter, LatLng(loc.latitude, loc.longitude), _radiusKm)) {
        continue;
      }
      out.add((provider: p, location: loc));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile.fullName ?? 'there';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.build_circle, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trf('hello', {'name': name}),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.teal)),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.inkSoft),
                          const SizedBox(width: 2),
                          Text('${widget.city}, Pakistan', style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                          const SizedBox(width: 4),
                          // City picker: filters every provider list in the
                          // app (home, categories, search) to this city.
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: widget.city,
                              isDense: true,
                              icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.teal),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.teal),
                              items: kServiceCities
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (c) {
                                if (c != null) widget.onCityChanged(c);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Language switch, on the home header.
                const LanguageToggle(),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: tr('searchHint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _doSearch,
                ),
              ),
              onSubmitted: (_) => _doSearch(),
            ),
            const SizedBox(height: 20),
            Text(tr('popularCategories'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<List<Category>>(
              future: _cats,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ));
                }
                if (snap.hasError) {
                  return _errorBox(trf('cs_loadCategoriesError', {'error': snap.error.toString()}));
                }
                final cats = snap.data ?? [];
                if (cats.isEmpty) return Text(tr('noCategories'));
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    // 0.70 keeps the text area tall enough for a 2-line name
                    // plus the description on a 360dp-wide phone; 0.78
                    // overflowed by 12px on "Security & Technology" and
                    // "Computer Hardware & Software" cards.
                    childAspectRatio: 0.70,
                  ),
                  itemCount: cats.length,
                  itemBuilder: (context, i) {
                    final c = cats[i];
                    return _CategoryCard(category: c, city: widget.city);
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            Text(tr('serviceArea'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _mapCenter,
                        initialZoom: 12,
                        onMapReady: () {
                          _mapReady = true;
                          _mapController.move(_mapCenter, 12);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.asaankaam.pk',
                        ),
                        MarkerLayer(
                          markers: [
                            // My own position (blue dot), when known.
                            if (_myLocation != null)
                              Marker(
                                point: _myLocation!,
                                width: 24,
                                height: 24,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            // One teal wrench marker per provider with a
                            // live location inside the radius.
                            for (final m in _visibleMarkers)
                              Marker(
                                point: LatLng(
                                    m.location.latitude, m.location.longitude),
                                width: 44,
                                height: 44,
                                child: GestureDetector(
                                  onTap: () =>
                                      _showProviderSheet(m.provider),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.teal,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.build,
                                        color: Colors.white, size: 22),
                                  ),
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
                          tooltip: tr('cs_myLocation'),
                          onPressed: () => _locateMe(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Radius chips on their own row: the count text used to sit
            // in this Row after a Spacer and the row overflowed by
            // 120 px on the right (seen 20 Nov 2026). The count now
            // lives on its own line below and wraps freely.
            Row(
              children: [
                Text(tr('within'),
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final r in _radiusOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${r.toInt()} km'),
                      selected: _radiusKm == r,
                      selectedColor: AppColors.tealLight,
                      onSelected: (selected) {
                        if (selected) setState(() => _radiusKm = r);
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              trf('cs_techniciansWithin', {'count': '${_visibleMarkers.length}', 'radius': '${_radiusKm.toInt()}'}),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSoft),
            ),
            if (_mapError != null) ...[
              const SizedBox(height: 6),
              Text(_mapError!,
                  style: const TextStyle(fontSize: 12, color: AppColors.red)),
            ],
            Text(trf('cs_mapNote', {'city': widget.city}),
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 20),
            Text(trf('recommendedTechnicians', {'city': widget.city}),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<List<Provider>>(
              future: _providers,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ));
                }
                if (snap.hasError) {
                  return _errorBox(trf('cs_loadTechniciansError', {'error': snap.error.toString()}));
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          trf('cs_noTechniciansCity', {'city': widget.city})),
                    ),
                  );
                }
                return Column(
                  children: list.map((p) => _ProviderTile(provider: p)).toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              tr('cs_codFeeNote'),
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet for a tapped map marker: provider details + a Book
  /// button that opens a service picker (the Home tab has no service
  /// context, so the customer picks the service here, then lands on
  /// BookingScreen with that provider pre-selected).
  void _showProviderSheet(Provider p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.tealLight,
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppColors.teal, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(p.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Chip(
                  label: Text(p.isAvailable ? tr('online') : tr('offline'),
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor:
                      p.isAvailable ? AppColors.tealLight : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${trf('cs_yearsExperience', {'years': '${p.experienceYears}'})}'
              '${p.city != null ? ' · ${p.city}' : ''}'
              '${p.averageRating > 0 ? ' · ★ ${p.averageRating}' : ''}',
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 6),
            Text(
              p.price != null
                  ? trf('cs_charges', {'amount': formatRs(p.price!)})
                  : tr('cs_chargesOnBooking'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (p.bio != null && p.bio!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p.bio!, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _showServicePicker(p);
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(tr('book')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showServicePicker(Provider p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trf('cs_bookFor', {'name': p.name}),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Flexible(
                child: FutureBuilder<List<ServiceItem>>(
                  future: fetchAllServices(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          trf('cs_loadServicesError', {'error': snap.error.toString()}),
                          style: const TextStyle(color: AppColors.red),
                        ),
                      );
                    }
                    final services = snap.data ?? [];
                    if (services.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(tr('noServices')),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: services.length,
                      itemBuilder: (context, i) {
                        final s = services[i];
                        return ListTile(
                          title: Text(s.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(s.description ?? ''),
                          trailing: Text(formatRs(s.basePrice),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.teal)),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => BookingScreen(
                                service: s,
                                provider: p,
                                price: p.price ?? s.basePrice,
                                city: widget.city,
                              ),
                            ));
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doSearch() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    final results = await searchServices(q);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SearchResultsScreen(query: q, results: results, city: widget.city),
    ));
  }

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(msg, style: const TextStyle(color: AppColors.red)),
      );
}

// Category image bundled under assets/images/categories/<slug>.webp.
// Falls back to the category icon if an image is missing.
String categoryImagePath(String slug) => 'assets/images/categories/$slug.webp';

class _CategoryCard extends StatelessWidget {
  final Category category;
  final String city;
  const _CategoryCard({required this.category, this.city = kDefaultCity});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ServicesScreen(category: category, city: city),
      )),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              categoryImagePath(category.slug),
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 96,
                color: AppColors.tealLight,
                child: Icon(_iconFor(category.slug), color: AppColors.teal, size: 40),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.teal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(category.description ?? tr('cs_categoryDefaultDesc'),
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String slug) {
    switch (slug) {
      case 'electrical':
        return Icons.bolt;
      case 'plumbing':
        return Icons.water_drop;
      case 'solar-installation':
        return Icons.wb_sunny;
      case 'appliance-repair':
        return Icons.kitchen;
      case 'security-technology':
        return Icons.videocam;
      case 'home-services':
        return Icons.home_repair_service;
      case 'computer-hardware-software':
        return Icons.laptop;
      default:
        return Icons.build;
    }
  }
}

class _ProviderTile extends StatelessWidget {
  final Provider provider;
  const _ProviderTile({required this.provider});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.tealLight,
          child: Text(
            provider.name.isNotEmpty ? provider.name[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(provider.name, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (provider.verificationStatus == 'approved')
              const Icon(Icons.verified, size: 18, color: AppColors.teal),
          ],
        ),
        subtitle: Text(
          '${trf('cs_yearsExperience', {'years': '${provider.experienceYears}'})}'
          '${provider.city != null ? ' · ${provider.city}' : ''}'
          '${provider.averageRating > 0 ? ' · ★ ${provider.averageRating}' : ''}',
        ),
        trailing: provider.isAvailable
            ? Chip(label: Text(tr('online'), style: const TextStyle(fontSize: 12)), backgroundColor: AppColors.tealLight)
            : Chip(label: Text(tr('offline'), style: const TextStyle(fontSize: 12))),
      ),
    );
  }
}

class _SearchResultsScreen extends StatelessWidget {
  final String query;
  final List<ServiceItem> results;
  final String city;
  const _SearchResultsScreen({required this.query, required this.results, this.city = kDefaultCity});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(trf('cs_searchResults', {'query': query}))),
      body: results.isEmpty
          ? Center(child: Text(tr('cs_noServicesFound')))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              itemBuilder: (context, i) {
                final s = results[i];
                return Card(
                  child: ListTile(
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(s.description ?? ''),
                    trailing: Text(formatRs(s.basePrice),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal)),
                    onTap: () {
                      // Open the service's providers list.
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProvidersScreen(service: s, city: city),
                      ));
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ---------------- Categories tab ----------------

class _CategoriesTab extends StatefulWidget {
  final String city;
  const _CategoriesTab({this.city = kDefaultCity});
  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  late Future<List<Category>> _cats;
  @override
  void initState() {
    super.initState();
    _cats = fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('categories')), actions: const [LanguageToggle()]),
      body: FutureBuilder<List<Category>>(
        future: _cats,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text(trf('cs_loadCategoriesError', {'error': snap.error.toString()})));
          final cats = snap.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cats.length,
            itemBuilder: (context, i) {
              final c = cats[i];
              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      categoryImagePath(c.slug),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: AppColors.tealLight,
                        child: const Icon(Icons.build, color: AppColors.teal),
                      ),
                    ),
                  ),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(c.description ?? ''),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ServicesScreen(category: c, city: widget.city),
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------- My bookings tab ----------------

class _MyBookingsTab extends StatefulWidget {
  const _MyBookingsTab();
  @override
  State<_MyBookingsTab> createState() => _MyBookingsTabState();
}

class _MyBookingsTabState extends State<_MyBookingsTab> {
  late Future<List<Booking>> _bookings;
  @override
  void initState() {
    super.initState();
    _bookings = fetchMyBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('myBookings')), actions: const [LanguageToggle()]),
      body: FutureBuilder<List<Booking>>(
        future: _bookings,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text(trf('cs_loadBookingsError', {'error': snap.error.toString()})));
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('noBookings')),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              // Same setState-Future bug as the provider Jobs tab: start
              // the fetch outside setState and assign with a block body,
              // then await so the spinner stays until the data arrives.
              final bookings = fetchMyBookings();
              if (mounted) {
                setState(() {
                  _bookings = bookings;
                });
              }
              await bookings;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final b = list[i];
                return Card(
                  child: ListTile(
                    title: Text(b.serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${statusLabel(b.status)}'
                      '${b.providerName != null ? ' · ${b.providerName}' : ''}'
                      '${b.scheduledAt != null ? '\n${b.scheduledAt!.day}/${b.scheduledAt!.month}/${b.scheduledAt!.year} ${b.scheduledAt!.hour}:${b.scheduledAt!.minute.toString().padLeft(2, '0')}' : ''}',
                    ),
                    trailing: b.estimatedPrice != null
                        ? Text(formatRs(b.estimatedPrice!),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal))
                        : null,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TrackingScreen(booking: b),
                    )),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Profile tab ----------------

class _ProfileTab extends StatefulWidget {
  final Profile profile;
  const _ProfileTab({required this.profile});
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late Future<List<Map<String, dynamic>>> _reviews;
  late Future<List<Booking>> _bookings;
  @override
  void initState() {
    super.initState();
    _reviews = fetchMyReviews();
    _bookings = fetchMyBookings();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      appBar: AppBar(title: Text(tr('profile')), actions: const [LanguageToggle()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.tealLight,
                      child: Text(
                        (p.fullName ?? p.email).isNotEmpty
                            ? (p.fullName ?? p.email)[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 24, color: AppColors.teal, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.fullName ?? tr('customer'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(p.email, style: const TextStyle(color: AppColors.inkSoft)),
                          if (p.phone != null) Text(p.phone!, style: const TextStyle(color: AppColors.inkSoft)),
                          Chip(
                            label: Text(p.role, style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppColors.tealLight,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr('bookingHistory'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<Booking>>(
              future: _bookings,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) return Text(tr('noBookingsShort'));
                return Column(
                  children: list.take(5).map((b) => Card(
                        child: ListTile(
                          title: Text(b.serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(statusLabel(b.status)),
                          trailing: b.estimatedPrice != null ? Text(formatRs(b.estimatedPrice!)) : null,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TrackingScreen(booking: b),
                          )),
                        ),
                      )).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(tr('myRatings'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviews,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) return Text(tr('noRatings'));
                return Column(
                  children: list.map((r) {
                    final booking = r['bookings'];
                    final serviceName = booking is Map<String, dynamic>
                        ? (booking['services'] is Map<String, dynamic>
                            ? (booking['services'] as Map<String, dynamic>)['name'] as String? ?? tr('cs_serviceName')
                            : tr('cs_serviceName'))
                        : tr('cs_serviceName');
                    return Card(
                      child: ListTile(
                        title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text((r['comment'] as String?) ?? ''),
                        trailing: Text('★ ${r['rating']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.amberDark)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async => db.auth.signOut(),
                icon: const Icon(Icons.logout),
                label: Text(tr('logOut')),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(tr('cs_versionFooter'),
                  style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }
}
