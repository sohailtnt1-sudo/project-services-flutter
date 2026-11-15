// Services in a category (live prices) → providers for a service.
import 'package:flutter/material.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import 'providers_screen.dart';

// Service photo bundled under assets/images/services/<slug>.webp.
// Falls back to the service's category image, then to an icon.
String serviceImagePath(String slug) => 'assets/images/services/$slug.webp';

class ServicesScreen extends StatefulWidget {
  final Category category;
  final String city;
  const ServicesScreen({super.key, required this.category, this.city = kDefaultCity});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late Future<List<ServiceItem>> _services;
  @override
  void initState() {
    super.initState();
    _services = fetchServicesByCategory(widget.category.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: FutureBuilder<List<ServiceItem>>(
        future: _services,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Could not load services: ${snap.error}'));
          final list = snap.data ?? [];
          if (list.isEmpty) return const Center(child: Text('No services in this category yet.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      serviceImagePath(s.slug),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/categories/${widget.category.slug}.webp',
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
                  ),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(s.description ?? ''),
                  trailing: Text(formatRs(s.basePrice),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProvidersScreen(service: s, city: widget.city),
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
