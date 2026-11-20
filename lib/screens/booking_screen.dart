// Booking form: problem, photo, date/time, address, price breakdown.
// Saves a real booking row (+ photos to the booking-media bucket) and
// shows the booking ID with a link to tracking.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/language_toggle.dart';
import '../l10n/strings.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import 'pin_picker_screen.dart';
import 'tracking_screen.dart';

class BookingScreen extends StatefulWidget {
  final ServiceItem service;
  final Provider? provider;
  final num price;
  // The customer's currently selected city (threaded from the Home /
  // providers flow) — the city field defaults to it, not to Lahore.
  final String city;
  // Category slug of the service, when the caller knows it (threaded
  // from ServicesScreen → ProvidersScreen). When null the screen
  // resolves it once via fetchCategorySlugForService — the delivery
  // fields gate on this slug (kDeliveryCategorySlug).
  final String? categorySlug;
  const BookingScreen(
      {super.key,
      required this.service,
      required this.provider,
      required this.price,
      this.city = kDefaultCity,
      this.categorySlug});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _description = TextEditingController();
  final _address = TextEditingController();
  late final _city = TextEditingController(text: widget.city);
  // Delivery on Demand fields (mirror the website booking form):
  // pickup shop name + pickup address (+ optional pin) + estimated
  // item cost. Only shown for the delivery category.
  final _pickupShop = TextEditingController();
  final _pickupAddress = TextEditingController();
  final _itemCost = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  final List<XFile> _photos = [];
  bool _busy = false;
  String? _error;
  String? _doneBookingId;
  // Optional map pin from PinPickerScreen — passed to createBooking
  // as latitude/longitude. Booking without a pin works as before.
  LatLng? _pickedPoint;
  // Optional pickup pin (delivery only): the shop the rider collects
  // from. Separate from the customer's delivery-address pin above.
  LatLng? _pickupPoint;
  String? _categorySlug;
  num? _lastItemCostShown;

  @override
  void initState() {
    super.initState();
    _categorySlug = widget.categorySlug;
    if (_categorySlug == null) {
      // Category was not threaded through (e.g. the provider sheet on
      // Home) — resolve it once; the delivery fields appear when it
      // comes back as the delivery category.
      fetchCategorySlugForService(widget.service.id).then((slug) {
        if (!mounted || slug == _categorySlug) return;
        setState(() => _categorySlug = slug);
      }).catchError((_) {});
    }
    // Keep the delivery-fee summary live as the item cost is typed.
    _itemCost.addListener(() {
      final parsed = num.tryParse(_itemCost.text.trim());
      if (parsed != _lastItemCostShown) {
        _lastItemCostShown = parsed;
        if (mounted) setState(() {});
      }
    });
  }

  bool get _isDelivery => _categorySlug == kDeliveryCategorySlug;

  @override
  void dispose() {
    _description.dispose();
    _address.dispose();
    _city.dispose();
    _pickupShop.dispose();
    _pickupAddress.dispose();
    _itemCost.dispose();
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
      setState(() => _error = tr('bk_photoLimit'));
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
          city: city.isEmpty ? widget.city : city,
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

  Future<void> _pickPickupOnMap() async {
    final city = _city.text.trim();
    final result = await Navigator.of(context).push<PinResult>(
      MaterialPageRoute(
        builder: (_) => PinPickerScreen(
          city: city.isEmpty ? widget.city : city,
          initialPoint: _pickupPoint,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pickupPoint = result.point;
      // The reverse-geocoded shop address fills the pickup field; the
      // customer can still edit it (shop name, floor, landmark).
      if (result.addressText.isNotEmpty) {
        _pickupAddress.text = result.addressText;
      }
    });
  }

  Future<void> _confirm() async {
    if (_description.text.trim().isEmpty) {
      setState(() => _error = _isDelivery
          ? tr('bk_describeFetch')
          : tr('bk_describeProblem'));
      return;
    }
    if (_isDelivery && _pickupAddress.text.trim().isEmpty) {
      setState(() => _error = tr('bk_pickupAddressRequired'));
      return;
    }
    if (_address.text.trim().isEmpty) {
      setState(() => _error = tr('bk_addressRequired'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final scheduledAt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final itemCostNum = num.tryParse(_itemCost.text.trim());
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
        pickupShopName: _isDelivery ? _pickupShop.text : null,
        pickupAddress: _isDelivery ? _pickupAddress.text : null,
        pickupLatitude: _isDelivery ? _pickupPoint?.latitude : null,
        pickupLongitude: _isDelivery ? _pickupPoint?.longitude : null,
        itemCost: _isDelivery ? itemCostNum : null,
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
              SnackBar(content: Text(trf('bk_photosFailed', {'error': e.toString()}))),
            );
          }
        }
      }
      if (mounted) setState(() => _doneBookingId = bookingId);
    } catch (e) {
      if (mounted) setState(() => _error = trf('bk_saveFailed', {'error': e.toString()}));
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
        appBar: AppBar(title: Text(tr('bookingConfirmed')), actions: const [LanguageToggle()]),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.teal, size: 72),
              const SizedBox(height: 16),
              Text(tr('bookingConfirmedMsg'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(trf('bk_bookingId', {'id': _doneBookingId!}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft)),
              const SizedBox(height: 4),
              Text('${s.name}${p != null ? trf('bk_withProvider', {'name': p.name}) : ''} · ${formatRs(_jobValue)} · ${tr('bk_cashOnDelivery')}',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => TrackingScreen(bookingId: _doneBookingId!),
                  ));
                },
                child: Text(tr('trackBooking')),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(tr('backToHome')),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(trf('bookTitle', {'service': s.name})), actions: const [LanguageToggle()]),
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
                  subtitle: Text('${trf('cs_yearsExperience', {'years': '${p.experienceYears}'})}${p.city != null ? ' · ${p.city}' : ''}'),
                  trailing: const Icon(Icons.verified, color: AppColors.teal),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(tr('noTechnician')),
                ),
              ),
            const SizedBox(height: 16),
            Text(_isDelivery ? tr('fetchProblem') : tr('describeProblem'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _isDelivery
                    ? tr('bk_fetchExample')
                    : tr('bk_problemExample'),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr('photoProblem'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
            if (_isDelivery) ...[
              Text(tr('pickupDetails'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(tr('pickupHint'),
                  style: const TextStyle(color: AppColors.inkSoft)),
              const SizedBox(height: 6),
              TextField(
                controller: _pickupShop,
                decoration: InputDecoration(
                  labelText: tr('pickupShopName'),
                  hintText: tr('bk_pickupShopExample'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pickupAddress,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('pickupAddress'),
                  hintText: tr('bk_pickupAddressExample'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickPickupOnMap,
                icon: const Icon(Icons.map),
                label: Text(tr('pickPickupOnMap')),
              ),
              if (_pickupPoint != null) ...[
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(Icons.location_on,
                      size: 16, color: AppColors.teal),
                  label: Text(
                    trf('bk_pickupPinned', {'lat': _pickupPoint!.latitude.toStringAsFixed(2), 'lng': _pickupPoint!.longitude.toStringAsFixed(2)}),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _itemCost,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('itemCost'),
                  hintText: tr('bk_itemCostExample'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('itemCostHint'),
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
            ],
            Text(tr('dateTime'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
            Text(_isDelivery ? tr('deliveryAddress') : tr('address'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _address,
              decoration: InputDecoration(
                hintText: _isDelivery
                    ? tr('bk_deliveryAddressHint')
                    : tr('bk_addressHint'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickOnMap,
              icon: const Icon(Icons.map),
              label: Text(tr('pickOnMap')),
            ),
            if (_pickedPoint != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.location_on,
                    size: 16, color: AppColors.teal),
                label: Text(
                  trf('bk_pinned', {'lat': _pickedPoint!.latitude.toStringAsFixed(2), 'lng': _pickedPoint!.longitude.toStringAsFixed(2)}),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _city,
              decoration: InputDecoration(labelText: tr('city')),
            ),
            const SizedBox(height: 20),
            Card(
              color: AppColors.tealLight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _priceRow(tr('jobPrice'), formatRs(_jobValue)),
                    _priceRow(tr('platformFee'), formatRs(_commission)),
                    if (_isDelivery &&
                        (num.tryParse(_itemCost.text.trim()) ?? 0) > 0)
                      _priceRow(tr('itemCostCash'),
                          formatRs(num.parse(_itemCost.text.trim()))),
                    const Divider(),
                    _priceRow(tr('youPayCod'), formatRs(_jobValue), bold: true),
                    _priceRow(tr('technicianReceives'), formatRs(_techReceives)),
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
                child: Text(_busy ? tr('saving') : trf('confirmBooking', {'price': formatRs(_jobValue)})),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isDelivery ? tr('codNoteDelivery') : tr('codNoteBooking'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
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
