// Approved providers for one service, with their own charges.
// Tap a provider to start a booking with them.
import 'package:flutter/material.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import 'booking_screen.dart';

class ProvidersScreen extends StatefulWidget {
  final ServiceItem service;
  const ProvidersScreen({super.key, required this.service});
  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  late Future<List<Provider>> _providers;
  @override
  void initState() {
    super.initState();
    _providers = fetchProvidersForService(widget.service.id);
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No verified technician offers this service yet. '
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
                          builder: (_) => BookingScreen(service: s, provider: p, price: price),
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
                  builder: (_) => BookingScreen(service: s, provider: null, price: s.basePrice),
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
