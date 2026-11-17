// Approved providers for one service, with their own charges.
// Tap a provider to start a booking with them.
import 'package:flutter/material.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import 'booking_screen.dart';

class ProvidersScreen extends StatefulWidget {
  final ServiceItem service;
  final String city;
  const ProvidersScreen({super.key, required this.service, this.city = kDefaultCity});
  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  late Future<List<Provider>> _providers;
  @override
  void initState() {
    super.initState();
    _providers = fetchProvidersForService(widget.service.id, city: widget.city);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.tealLight,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (s.description != null) Text(s.description!, style: const TextStyle(color: AppColors.inkSoft)),
                const SizedBox(height: 6),
                Text('Base price: ${formatRs(s.basePrice)}  ·  Platform fee 15% is shown before you confirm.',
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: AppColors.teal),
                    const SizedBox(width: 2),
                    Text('Showing providers in ${widget.city}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Provider>>(
              future: _providers,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Could not load technicians: ${snap.error}'));
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No providers in ${widget.city} for this service yet. '
                        'You can still book — an available technician will be assigned.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final p = list[i];
                    final price = p.price ?? s.basePrice;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.tealLight,
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                            if (p.verificationStatus == 'approved')
                              const Icon(Icons.verified, size: 18, color: AppColors.teal),
                          ],
                        ),
                        subtitle: Text(
                          '${p.experienceYears} yrs experience'
                          '${p.city != null ? ' · ${p.city}' : ''}'
                          '${p.averageRating > 0 ? ' · ★ ${p.averageRating}' : ''}'
                          '${p.isAvailable ? '' : ' · Offline'}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatRs(price),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal)),
                            const Text('per job', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BookingScreen(service: s, provider: p, price: price, city: widget.city),
                        )),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BookingScreen(service: s, provider: null, price: s.basePrice, city: widget.city),
                )),
                child: const Text('Book without choosing a technician'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
