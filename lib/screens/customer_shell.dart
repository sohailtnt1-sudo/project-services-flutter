// Customer shell: bottom nav Home | Categories | Bookings | Messages | Profile.
// Home shows live categories + approved providers + an OpenStreetMap view.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(profile: widget.profile),
      const _CategoriesTab(),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Categories'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ---------------- Home ----------------

class _HomeTab extends StatefulWidget {
  final Profile profile;
  const _HomeTab({required this.profile});
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late Future<List<Category>> _cats;
  late Future<List<Provider>> _providers;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cats = fetchCategories();
    _providers = fetchApprovedProviders();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
                      Text('Hello, $name',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.teal)),
                      const Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: AppColors.inkSoft),
                          SizedBox(width: 2),
                          Text('Lahore, Pakistan', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search a service — fan repair, plumber…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _doSearch,
                ),
              ),
              onSubmitted: (_) => _doSearch(),
            ),
            const SizedBox(height: 20),
            const Text('Popular categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  return _errorBox('Could not load categories: ${snap.error}');
                }
                final cats = snap.data ?? [];
                if (cats.isEmpty) return const Text('No categories yet.');
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: cats.length,
                  itemBuilder: (context, i) {
                    final c = cats[i];
                    return _CategoryCard(category: c);
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Service area',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(31.5204, 74.3587), // Lahore
                    initialZoom: 11,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.projectservices.app',
                    ),
                    const MarkerLayer(markers: [
                      Marker(
                        point: LatLng(31.5204, 74.3587),
                        width: 40,
                        height: 40,
                        child: Icon(Icons.location_on, color: AppColors.teal, size: 36),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const Text('OpenStreetMap — technicians serve Lahore and nearby areas.',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 20),
            const Text('Recommended technicians',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  return _errorBox('Could not load technicians: ${snap.error}');
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'No verified technicians yet. Technicians appear here once an admin approves them.'),
                    ),
                  );
                }
                return Column(
                  children: list.map((p) => _ProviderTile(provider: p)).toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Cash on delivery. The platform adds a 15% service fee on the job price — shown before you confirm.',
              style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
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
      builder: (_) => _SearchResultsScreen(query: q, results: results),
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
  const _CategoryCard({required this.category});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ServicesScreen(category: category),
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
                    Text(category.description ?? 'Professional home service',
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                        maxLines: 2,
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
          '${provider.experienceYears} yrs experience'
          '${provider.city != null ? ' · ${provider.city}' : ''}'
          '${provider.averageRating > 0 ? ' · ★ ${provider.averageRating}' : ''}',
        ),
        trailing: provider.isAvailable
            ? const Chip(label: Text('Online', style: TextStyle(fontSize: 12)), backgroundColor: AppColors.tealLight)
            : const Chip(label: Text('Offline', style: TextStyle(fontSize: 12))),
      ),
    );
  }
}

class _SearchResultsScreen extends StatelessWidget {
  final String query;
  final List<ServiceItem> results;
  const _SearchResultsScreen({required this.query, required this.results});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results for "$query"')),
      body: results.isEmpty
          ? const Center(child: Text('No services found.'))
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
                        builder: (_) => ProvidersScreen(service: s),
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
  const _CategoriesTab();
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
      appBar: AppBar(title: const Text('Categories')),
      body: FutureBuilder<List<Category>>(
        future: _cats,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Could not load categories: ${snap.error}'));
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
                    builder: (_) => ServicesScreen(category: c),
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
      appBar: AppBar(title: const Text('My bookings')),
      body: FutureBuilder<List<Booking>>(
        future: _bookings,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Could not load bookings: ${snap.error}'));
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No bookings yet. Pick a service from Home to book your first job.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _bookings = fetchMyBookings()),
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
      appBar: AppBar(title: const Text('Profile')),
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
                          Text(p.fullName ?? 'Customer',
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
            const Text('Booking history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<Booking>>(
              future: _bookings,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) return const Text('No bookings yet.');
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
            const Text('My ratings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviews,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) return const Text('You have not rated any job yet.');
                return Column(
                  children: list.map((r) {
                    final booking = r['bookings'];
                    final serviceName = booking is Map<String, dynamic>
                        ? (booking['services'] is Map<String, dynamic>
                            ? (booking['services'] as Map<String, dynamic>)['name'] as String? ?? 'Service'
                            : 'Service')
                        : 'Service';
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
                label: const Text('Log out'),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('AsaanKaam v1.0.0 — Cash on delivery',
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }
}
