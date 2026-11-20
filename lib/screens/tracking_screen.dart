// Booking tracking: status timeline + uploaded photos.
// Accepts either a Booking object or just an id (loads the booking).
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
          SnackBar(content: Text(trf('trk_openChatError', {'error': e.toString()}))),
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
      appBar: AppBar(title: Text(tr('trk_title'))),
      body: FutureBuilder<Booking>(
        future: _booking,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text(trf('trk_loadError', {'error': snap.error.toString()})));
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
                        Text(trf('trk_bookingId', {'id': b.id}), style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                        if (b.providerName != null) Text(trf('trk_technician', {'name': b.providerName ?? ''})),
                        if (b.scheduledAt != null)
                          Text(trf('trk_scheduled', {
                            'date':
                                '${b.scheduledAt!.day}/${b.scheduledAt!.month}/${b.scheduledAt!.year} '
                                    '${b.scheduledAt!.hour}:${b.scheduledAt!.minute.toString().padLeft(2, '0')}',
                          })),
                        if (b.estimatedPrice != null)
                          Text(trf('trk_priceCod', {'amount': formatRs(b.estimatedPrice!)})),
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
                              label: Text(tr('trk_chat')),
                            ),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              tr('trk_chatNotAssigned'),
                              style: const TextStyle(color: AppColors.inkSoft),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Rate the technician — only on completed bookings. The
                // card itself shows the submitted rating when one already
                // exists, and stays hidden for anyone but the customer.
                if (b.status == 'completed') _RatingCard(booking: b),
                // Report a problem — the booking's own customer only.
                // The card shows the filed complaint (with its status)
                // instead of the form when one already exists.
                _ComplaintCard(booking: b),
                const SizedBox(height: 16),
                if (b.providerId != null &&
                    kActiveJobStatuses.contains(b.status)) ...[
                  Text(tr('trk_liveLocation'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    tr('trk_liveLocationNote'),
                    style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  LiveTrackingMap(booking: b),
                  const SizedBox(height: 16),
                ],
                Text(tr('trk_status'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    child: Text(trf('trk_bookingStatusNote', {'status': statusLabel(b.status).toLowerCase()}),
                        style: const TextStyle(color: AppColors.red)),
                  ),
                const SizedBox(height: 16),
                Text(tr('trk_problemPhotos'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FutureBuilder<List<BookingMedia>>(
                  future: _media,
                  builder: (context, msnap) {
                    if (msnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final media = msnap.data ?? [];
                    if (media.isEmpty) return Text(tr('trk_noPhotos'));
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
                Text(tr('trk_history'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FutureBuilder<List<StatusEvent>>(
                  future: _history,
                  builder: (context, hsnap) {
                    if (hsnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final events = hsnap.data ?? [];
                    if (events.isEmpty) {
                      return Text(tr('trk_createdWaiting'));
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

/// "Rate the technician" card on a completed booking's details screen.
/// Shows the star form while the job is unrated; once a review exists
/// it shows the submitted rating instead (one review per booking).
class _RatingCard extends StatefulWidget {
  final Booking booking;
  const _RatingCard({required this.booking});

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  late Future<Map<String, dynamic>?> _review;
  int _stars = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _review = fetchReviewForBooking(widget.booking.id);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      _showMessage(tr('selectStars'));
      return;
    }
    final booking = widget.booking;
    if (booking.providerId == null) return;
    setState(() => _submitting = true);
    try {
      await submitReview(
        bookingId: booking.id,
        providerId: booking.providerId!,
        rating: _stars,
        comment: _commentController.text,
      );
      if (!mounted) return;
      // Show the submitted rating right away, without a re-fetch.
      final comment = _commentController.text.trim();
      setState(() {
        _review = Future.value({
          'rating': _stars,
          'comment': comment.isEmpty ? null : comment,
        });
      });
      _showMessage(tr('ratingSubmitted'));
    } on PostgrestException catch (e) {
      // A second insert for the same booking hits the unique index
      // (23505): the job is already rated — show that rating instead.
      if (e.code == '23505') {
        setState(() => _review = fetchReviewForBooking(booking.id));
        _showMessage(tr('alreadyRated'));
      } else {
        _showMessage(trf('ratingFailed', {'error': e.message}));
      }
    } catch (e) {
      _showMessage(trf('ratingFailed', {'error': e.toString()}));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _review,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snap.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                trf('trk_ratingLoadError', {'error': snap.error.toString()}),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
            ),
          );
        }
        final existing = snap.data;
        if (existing != null) {
          final rating = (existing['rating'] as num?)?.toInt() ?? 0;
          final comment = existing['comment'] as String?;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('yourRating'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: AppColors.amberDark,
                        size: 28,
                      ),
                    ),
                  ),
                  if (comment != null && comment.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comment),
                  ],
                ],
              ),
            ),
          );
        }
        // No review yet: only the booking's own customer may rate.
        final currentUserId = db.auth.currentUser?.id;
        if (currentUserId == null ||
            !shouldShowRatingCard(
              booking: widget.booking,
              currentUserId: currentUserId,
              hasReview: false,
            )) {
          return const SizedBox.shrink();
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('rateProvider'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('rateProviderHint'),
                  style: const TextStyle(
                      color: AppColors.inkSoft, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _stars = i + 1),
                      icon: Icon(
                        i < _stars ? Icons.star : Icons.star_border,
                        color: i < _stars
                            ? AppColors.amberDark
                            : AppColors.inkSoft,
                        size: 32,
                      ),
                      tooltip: '${i + 1} / 5',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: tr('writeCommentOptional'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(tr('submitRating')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Report a problem" card on a booking's details screen. Shows the
/// complaint form while none exists for this booking; once a complaint
/// is filed it shows the complaint with its current status instead, so
/// a second complaint for the same booking cannot be filed. Plain
/// English labels (no strings.dart keys — Urdu coverage for this card
/// follows separately).
class _ComplaintCard extends StatefulWidget {
  final Booking booking;
  const _ComplaintCard({required this.booking});

  @override
  State<_ComplaintCard> createState() => _ComplaintCardState();
}

class _ComplaintCardState extends State<_ComplaintCard> {
  late Future<Map<String, dynamic>?> _complaint;
  final _textController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _complaint = fetchComplaintForBooking(widget.booking.id);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showMessage(tr('trk_complaintEmpty'));
      return;
    }
    setState(() => _submitting = true);
    try {
      await submitComplaint(
        bookingId: widget.booking.id,
        providerId: widget.booking.providerId,
        complaintText: text,
      );
      if (!mounted) return;
      setState(() {
        _complaint = Future.value({
          'complaint_text': text,
          'status': 'open',
          'resolution': null,
        });
      });
      _showMessage(tr('trk_complaintSubmitted'));
    } catch (e) {
      _showMessage(trf('trk_complaintFailed', {'error': e.toString()}));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _complaint,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snap.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                trf('trk_complaintLoadError', {'error': snap.error.toString()}),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
            ),
          );
        }
        final existing = snap.data;
        if (existing != null) {
          final status = (existing['status'] as String?) ?? 'open';
          final text = existing['complaint_text'] as String?;
          final resolution = existing['resolution'] as String?;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tr('trk_yourComplaint'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(complaintStatusLabel(status)),
                        backgroundColor: AppColors.tealLight,
                      ),
                    ],
                  ),
                  if (text != null && text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(text),
                  ],
                  if (resolution != null &&
                      resolution.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      trf('trk_resolution', {'resolution': resolution}),
                      style: const TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        // No complaint yet: only the booking's own customer may file one.
        final currentUserId = db.auth.currentUser?.id;
        if (currentUserId == null ||
            !shouldShowComplaintCard(
              booking: widget.booking,
              currentUserId: currentUserId,
              hasComplaint: false,
            )) {
          return const SizedBox.shrink();
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('trk_reportProblem'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('trk_reportProblemHint'),
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  maxLines: 4,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: tr('trk_whatWentWrong'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(tr('trk_submitComplaint')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
