// Booking tracking: status timeline + uploaded photos.
// Accepts either a Booking object or just an id (loads the booking).
import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'job_route_screen.dart' show kActiveJobStatuses;
import 'live_tracking_map.dart';

class TrackingScreen extends StatefulWidget {
  final Booking? booking;
  final String? bookingId;
  const TrackingScreen({super.key, this.booking, this.bookingId})
      : assert(booking != null || bookingId != null);
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late Future<Booking> _booking;
  late Future<List<BookingMedia>> _media;
  late Future<List<StatusEvent>> _history;
  bool _chatBusy = false;

  Future<void> _openChat(Booking b) async {
    if (_chatBusy) return;
    setState(() => _chatBusy = true);
    try {
      final conv = await getOrCreateConversation(b.id);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatDetailScreen(conversation: conv),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _chatBusy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final id = widget.booking?.id ?? widget.bookingId!;
    _booking = _loadBooking(id);
    _media = fetchBookingMedia(id);
    _history = fetchBookingHistory(id);
  }

  Future<Booking> _loadBooking(String id) async {
    if (widget.booking != null) return widget.booking!;
    final list = await fetchMyBookings();
    return list.firstWhere(
      (b) => b.id == id,
      orElse: () => Booking(
        id: id,
        customerId: '',
        serviceName: 'Booking',
        status: 'pending',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track booking')),
      body: FutureBuilder<Booking>(
        future: _booking,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Could not load booking: ${snap.error}'));
          final b = snap.data!;
          final currentIdx = bookingTimeline.indexOf(b.status);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.serviceName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Booking ID: ${b.id}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                        if (b.providerName != null) Text('Technician: ${b.providerName}'),
                        if (b.scheduledAt != null)
                          Text('Scheduled: ${b.scheduledAt!.day}/${b.scheduledAt!.month}/${b.scheduledAt!.year} '
                              '${b.scheduledAt!.hour}:${b.scheduledAt!.minute.toString().padLeft(2, '0')}'),
                        if (b.estimatedPrice != null)
                          Text('Price: ${formatRs(b.estimatedPrice!)} · Cash on delivery'),
                        // Cash receipt (migration 010): the amount the
                        // provider declared taking from the customer.
                        // The same receipt also appears in the chat.
                        if (b.cashReceivedAmount != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${trf('cashPaid', {'amount': formatRs(b.cashReceivedAmount!)})}'
                              '${b.cashReceivedAt != null ? ' · ${b.cashReceivedAt!.day}/${b.cashReceivedAt!.month}/${b.cashReceivedAt!.year}' : ''}',
                              style: const TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(statusLabel(b.status)),
                          backgroundColor: AppColors.tealLight,
                        ),
                        if (b.providerId != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _chatBusy ? null : () => _openChat(b),
                              icon: _chatBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.chat_bubble_outline),
                              label: const Text('Chat'),
                            ),
                          ),
                        ] else
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Chat opens once a technician is assigned to this booking.',
                              style: TextStyle(color: AppColors.inkSoft),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (b.providerId != null &&
                    kActiveJobStatuses.contains(b.status)) ...[
                  const Text('Live location',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Live location sirf is job ke doran dikhayi jati hai.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  LiveTrackingMap(booking: b),
                  const SizedBox(height: 16),
                ],
                const Text('Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...bookingTimeline.asMap().entries.map((e) {
                  final idx = e.key;
                  final step = e.value;
                  final done = currentIdx >= 0 && idx <= currentIdx;
                  final isCurrent = step == b.status;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Icon(
                            done ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: done ? AppColors.teal : AppColors.inkSoft,
                          ),
                          if (idx < bookingTimeline.length - 1)
                            Container(width: 2, height: 24, color: done ? AppColors.teal : AppColors.line),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          statusLabel(step),
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? AppColors.teal : AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (b.status == 'rejected' || b.status == 'cancelled' || b.status == 'disputed')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('This booking is ${statusLabel(b.status).toLowerCase()}.',
                        style: const TextStyle(color: AppColors.red)),
                  ),
                const SizedBox(height: 16),
                const Text('Problem photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FutureBuilder<List<BookingMedia>>(
                  future: _media,
                  builder: (context, msnap) {
                    if (msnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final media = msnap.data ?? [];
                    if (media.isEmpty) return const Text('No photos attached to this booking.');
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: media
                          .where((m) => m.mediaUrl != null)
                          .map((m) => ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  m.mediaUrl!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 100,
                                    height: 100,
                                    color: AppColors.tealLight,
                                    child: const Icon(Icons.broken_image, color: AppColors.inkSoft),
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FutureBuilder<List<StatusEvent>>(
                  future: _history,
                  builder: (context, hsnap) {
                    if (hsnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final events = hsnap.data ?? [];
                    if (events.isEmpty) {
                      return const Text('Created — waiting for a technician to accept.');
                    }
                    return Column(
                      children: events.map((e) => ListTile(
                            leading: const Icon(Icons.history, size: 18, color: AppColors.inkSoft),
                            title: Text(
                              '${e.oldStatus != null ? '${statusLabel(e.oldStatus!)} → ' : ''}${statusLabel(e.newStatus ?? '')}',
                            ),
                            subtitle: Text(
                              '${e.changedAt.day}/${e.changedAt.month}/${e.changedAt.year} '
                              '${e.changedAt.hour}:${e.changedAt.minute.toString().padLeft(2, '0')}',
                            ),
                          )).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
