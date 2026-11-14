// Services in a category (live prices) → providers for a service.
import 'package:flutter/material.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import 'providers_screen.dart';

class ServicesScreen extends StatefulWidget {
  final Category category;
  const ServicesScreen({super.key, required this.category});
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
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(s.description ?? ''),
                  trailing: Text(formatRs(s.basePrice),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProvidersScreen(service: s),
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
