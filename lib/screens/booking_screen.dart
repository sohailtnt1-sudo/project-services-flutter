// Booking form: problem, photo, date/time, address, price breakdown.
// Saves a real booking row (+ photos to the booking-media bucket) and
// shows the booking ID with a link to tracking.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import 'pin_picker_screen.dart';
import 'tracking_screen.dart';

class BookingScreen extends StatefulWidget {
  final ServiceItem service;
  final Provider? provider;
  final num price;
  const BookingScreen({super.key, required this.service, required this.provider, required this.price});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController(text: 'Lahore');
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  final List<XFile> _photos = [];
  bool _busy = false;
  String? _error;
  String? _doneBookingId;
  // Optional map pin from PinPickerScreen — passed to createBooking
  // as latitude/longitude. Booking without a pin works as before.
  LatLng? _pickedPoint;

  @override
  void dispose() {
    _description.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  num get _jobValue => widget.price;
  num get _commission => (_jobValue * kCommissionRate).round();
  num get _techReceives => _jobValue - _commission;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    if (_photos.length >= 5) {
      setState(() => _error = 'You can attach up to 5 photos.');
      return;
    }
    setState(() {
      _photos.add(file);
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickOnMap() async {
    final city = _city.text.trim();
    final result = await Navigator.of(context).push<PinResult>(
      MaterialPageRoute(
        builder: (_) => PinPickerScreen(
          city: city.isEmpty ? 'Lahore' : city,
          initialPoint: _pickedPoint,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pickedPoint = result.point;
      _address.text = result.addressText;
      _city.text = result.city;
    });
  }

  Future<void> _confirm() async {
    if (_description.text.trim().isEmpty) {
      setState(() => _error = 'Please describe the problem.');
      return;
    }
    if (_address.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final scheduledAt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final bookingId = await createBooking(
        serviceId: widget.service.id,
        providerId: widget.provider?.id,
        description: _description.text,
        scheduledAt: scheduledAt,
        addressText: _address.text,
        city: _city.text,
        estimatedPrice: _jobValue,
        commissionAmount: _commission,
        latitude: _pickedPoint?.latitude,
        longitude: _pickedPoint?.longitude,
      );
      if (_photos.isNotEmpty) {
        final files = _photos.map((x) => File(x.path)).toList();
        try {
          await uploadBookingPhotos(bookingId, files);
        } catch (e) {
          // Photos failed but the booking is saved — the tracking page
          // lets the customer retry. Do not fail the booking.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Booking saved, but photos failed to upload: $e')),
            );
          }
        }
      }
      if (mounted) setState(() => _doneBookingId = bookingId);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save the booking: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final p = widget.provider;
    if (_doneBookingId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking confirmed')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.teal, size: 72),
              const SizedBox(height: 16),
              const Text('Your booking is confirmed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Booking ID: $_doneBookingId',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft)),
              const SizedBox(height: 4),
              Text('${s.name}${p != null ? ' with ${p.name}' : ''} · ${formatRs(_jobValue)} · Cash on delivery',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => TrackingScreen(bookingId: _doneBookingId!),
                  ));
                },
                child: const Text('Track my booking'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Book: ${s.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p != null)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.tealLight,
                    child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${p.experienceYears} yrs experience${p.city != null ? ' · ${p.city}' : ''}'),
                  trailing: const Icon(Icons.verified, color: AppColors.teal),
                ),
              )
            else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No technician chosen — an available technician will be assigned.'),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Describe the problem', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. The ceiling fan makes a loud noise and runs slowly.',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Photo of the problem (optional, up to 5)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._photos.map((x) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(x.path), width: 84, height: 84, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.remove(x)),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: AppColors.red,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )),
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.teal),
                    ),
                    child: const Icon(Icons.add_a_photo, color: AppColors.teal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Date & time', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('${_date.day}/${_date.month}/${_date.year}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _address,
              decoration: const InputDecoration(hintText: 'House, street, area'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickOnMap,
              icon: const Icon(Icons.map),
              label: const Text('Pick on map'),
            ),
            if (_pickedPoint != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.location_on,
                    size: 16, color: AppColors.teal),
                label: Text(
                  'Pinned: ${_pickedPoint!.latitude.toStringAsFixed(2)}, '
                  '${_pickedPoint!.longitude.toStringAsFixed(2)}',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 20),
            Card(
              color: AppColors.tealLight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _priceRow('Job price', formatRs(_jobValue)),
                    _priceRow('Platform fee (15%)', formatRs(_commission)),
                    const Divider(),
                    _priceRow('You pay (cash on delivery)', formatRs(_jobValue), bold: true),
                    _priceRow('Technician receives', formatRs(_techReceives)),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _confirm,
                child: Text(_busy ? 'Saving…' : 'Confirm booking — ${formatRs(_jobValue)}'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cash on delivery. You pay the technician after the work is done.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
