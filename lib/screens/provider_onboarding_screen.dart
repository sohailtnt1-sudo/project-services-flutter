// Provider onboarding in the app — register / update as a technician.
// Mirrors the website /provider/onboarding flow (same fields, validation
// and database writes), so providers no longer need a computer:
//   Step 1: profile form — CNIC number, city/area, years of experience,
//           bio, and the services offered with the provider's own charge.
//   Step 2: document upload — CNIC front + CNIC back photos and a
//           SELFIE (camera preferred) for face verification.
// Photos go to the booking-media bucket under {user_id}/provider-docs/…
// (same as the website) and the selfie is stored as a provider_documents
// row with document_type 'selfie' — visible to the admin on /admin.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/language_toggle.dart';
import '../l10n/strings.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';

/// Platform guideline warning for a provider's own charge, mirroring the
/// website: between 50% and 200% of the base price.
String? priceGuidelineWarning(num price, num basePrice) {
  if (basePrice <= 0) return null;
  if (price < basePrice * 0.5) {
    return 'Below the platform guideline (50% of the base price ${formatRs(basePrice)}).';
  }
  if (price > basePrice * 2) {
    return 'Above the platform guideline (200% of the base price ${formatRs(basePrice)}).';
  }
  return null;
}

class _ServiceChoice {
  bool selected;
  String price;
  _ServiceChoice({this.selected = false, this.price = ''});
}

class ProviderOnboardingScreen extends StatefulWidget {
  final Profile profile;
  const ProviderOnboardingScreen({super.key, required this.profile});

  @override
  State<ProviderOnboardingScreen> createState() => _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  bool _loading = true;
  String? _loadError;
  List<Category> _categories = [];
  List<ServiceItem> _services = [];
  Map<String, dynamic>? _existing;
  List<ProviderDocument> _docs = [];

  int _step = 1;
  final _cnic = TextEditingController();
  final _mobile = TextEditingController();
  final _city = TextEditingController();
  final _experience = TextEditingController(text: '1');
  final _bio = TextEditingController();
  final Map<String, _ServiceChoice> _choices = {};
  bool _saving = false;
  String? _error;

  // Step 2 state.
  final Map<String, XFile?> _localPhotos = {};
  String? _uploadingType;
  String? _docError;
  String? _docNotice;
  bool _cnicSaved = false;

  @override
  void initState() {
    super.initState();
    // Prefill the mobile number from the account profile (e.g. Humaiyo
    // already has 03063833728 saved from sign-up).
    _mobile.text = widget.profile.phone ?? '';
    _load();
  }

  @override
  void dispose() {
    _cnic.dispose();
    _mobile.dispose();
    _city.dispose();
    _experience.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cats = await fetchCategories();
      final svcs = await fetchAllServices();
      final prof = await fetchMyProviderProfile();
      List<ProviderDocument> docs = [];
      if (prof != null) {
        docs = await fetchProviderDocuments(prof['id'] as String);
        final skills = await fetchProviderSkills(prof['id'] as String);
        for (final s in skills) {
          _choices[s['service_id'] as String] = _ServiceChoice(
            selected: true,
            price: (s['price'] as num?) != null ? (s['price'] as num).toString() : '',
          );
        }
        final front = docs.where((d) => d.documentType == 'cnic_front').firstOrNull;
        if (front?.documentNumber != null) _cnic.text = front!.documentNumber!;
      }
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _services = svcs;
        _existing = prof;
        _docs = docs;
        if (prof != null) {
          _city.text = (prof['city'] as String?) ?? '';
          _experience.text = ((prof['experience_years'] as num?) ?? 1).toString();
          _bio.text = (prof['bio'] as String?) ?? '';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Could not load the registration form: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ProviderDocument? _docOf(String type) {
    for (final d in _docs) {
      if (d.documentType == type) return d;
    }
    return null;
  }

  Future<void> _saveStep1() async {
    setState(() => _error = null);
    if (!isValidCnic(_cnic.text)) {
      setState(() => _error = 'Please enter a valid 13-digit CNIC number (e.g. 35202-1234567-1).');
      return;
    }
    if (!isValidPakistaniMobile(_mobile.text)) {
      setState(() => _error = tr('mobileInvalid'));
      return;
    }
    if (_city.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your city / area.');
      return;
    }
    final exp = int.tryParse(_experience.text.trim());
    if (exp == null || exp < 0 || exp > 60) {
      setState(() => _error = 'Please enter your years of experience (0–60).');
      return;
    }
    final selected = _services.where((s) => _choices[s.id]?.selected == true).toList();
    if (selected.isEmpty) {
      setState(() => _error = 'Please select at least one service you offer.');
      return;
    }
    for (final s in selected) {
      final price = num.tryParse(_choices[s.id]?.price.trim() ?? '');
      if (price == null || price <= 0) {
        setState(() => _error = 'Please enter your charge for ${s.name}.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final prof = await saveProviderProfile(
        experienceYears: exp,
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        city: _city.text.trim(),
      );
      // Mobile number lives on profiles.phone (never on
      // provider_profiles) — visible to the provider himself and the
      // admin only, never to customers.
      await updateMyPhone(normalizePakistaniMobile(_mobile.text));
      await saveProviderSkills(
        prof['id'] as String,
        selected
            .map((s) => ProviderSkillInput(
                  serviceId: s.id,
                  price: num.parse(_choices[s.id]!.price.trim()),
                  experienceYears: exp,
                ))
            .toList(),
      );
      await upsertProviderDocument(
        prof['id'] as String,
        'cnic_front',
        documentNumber: normalizeCnic(_cnic.text),
      );
      final docs = await fetchProviderDocuments(prof['id'] as String);
      if (!mounted) return;
      setState(() {
        _existing = prof;
        _docs = docs;
        _step = 2;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save your registration: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveCnicNumber() async {
    if (_existing == null) return;
    setState(() {
      _docError = null;
      _cnicSaved = false;
    });
    if (!isValidCnic(_cnic.text)) {
      setState(() => _docError = 'Please enter a valid 13-digit CNIC number (e.g. 35202-1234567-1).');
      return;
    }
    try {
      final row = await upsertProviderDocument(
        _existing!['id'] as String,
        'cnic_front',
        documentNumber: normalizeCnic(_cnic.text),
      );
      setState(() {
        _docs = [
          ..._docs.where((d) => d.documentType != 'cnic_front'),
          row,
        ];
        _cnicSaved = true;
      });
    } catch (e) {
      if (mounted) setState(() => _docError = 'The CNIC number could not be saved: $e');
    }
  }

  Future<void> _pickPhoto(String type, ImageSource source) async {
    if (_existing == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _docError = null;
      _docNotice = null;
      _uploadingType = type;
    });
    try {
      final row = await uploadProviderDocument(
        _existing!['id'] as String,
        type,
        File(file.path),
        documentNumber: type == 'cnic_front' && isValidCnic(_cnic.text)
            ? normalizeCnic(_cnic.text)
            : null,
      );
      if (!mounted) return;
      setState(() {
        _localPhotos[type] = file;
        _docs = [
          ..._docs.where((d) => d.documentType != type),
          row,
        ];
        _docNotice = '${_docLabel(type)} uploaded.';
      });
    } catch (e) {
      if (mounted) setState(() => _docError = 'The photo could not be uploaded: $e');
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  static String _docLabel(String type) {
    switch (type) {
      case 'cnic_front':
        return tr('cnicFront');
      case 'cnic_back':
        return tr('cnicBack');
      case 'selfie':
        return tr('selfie');
      default:
        return type;
    }
  }

  static String _docHint(String type) {
    switch (type) {
      case 'cnic_front':
        return 'Photo of the front of your CNIC card.';
      case 'cnic_back':
        return 'Photo of the back of your CNIC card.';
      case 'selfie':
        return 'A clear photo of your face, so the admin can match it with your CNIC.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing != null ? tr('updateRegistration') : tr('registerProvider')),
        actions: const [LanguageToggle()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('onboardingIntro'),
                        style: const TextStyle(color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _stepChip(1, tr('yourDetails'), _step == 1)),
                          const SizedBox(width: 8),
                          Expanded(child: _stepChip(2, tr('cnicSelfieStep'), _step == 2)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_step == 1) _step1Form() else _step2Docs(),
                    ],
                  ),
                ),
    );
  }

  Widget _stepChip(int n, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.teal : AppColors.tealLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        '$n · $label',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? Colors.white : AppColors.teal,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _step1Form() {
    final grouped = _categories
        .map((c) => MapEntry(c, _services.where((s) => s.categoryId == c.id).toList()))
        .where((e) => e.value.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _cnic,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr('cnicNumber'),
            hintText: '35202-1234567-1',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        MobileNumberField(controller: _mobile),
        const SizedBox(height: 12),
        TextField(
          controller: _city,
          decoration: InputDecoration(
            labelText: tr('cityArea'),
            hintText: 'Lahore — Gulberg',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _experience,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr('experienceYears'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bio,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: tr('shortBio'),
            hintText: 'Example: Licensed electrician with 5 years of experience in home wiring, fans and fittings.',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text(tr('servicesOffer'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Text(
          'You set your own charges. Platform guideline: between 50% and 200% of the base price shown. '
          'The platform commission is 15% of the job value.',
          style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 8),
        ...grouped.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(entry.key.name.toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.inkSoft)),
              ),
              ...entry.value.map((s) {
                final choice = _choices[s.id] ?? _ServiceChoice();
                final priceNum = num.tryParse(choice.price);
                final warning = choice.selected && priceNum != null && priceNum > 0
                    ? priceGuidelineWarning(priceNum, s.basePrice)
                    : null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Platform base price ${formatRs(s.basePrice)}'),
                          value: choice.selected,
                          onChanged: (v) => setState(() {
                            _choices[s.id] = _ServiceChoice(selected: v ?? false, price: choice.price);
                          }),
                        ),
                        if (choice.selected)
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: tr('yourCharge'),
                              border: const OutlineInputBorder(),
                            ),
                            controller: TextEditingController(text: choice.price)
                              ..selection = TextSelection.fromPosition(
                                TextPosition(offset: choice.price.length),
                              ),
                            onChanged: (v) => _choices[s.id] = _ServiceChoice(selected: true, price: v),
                          ),
                        if (warning != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(warning, style: const TextStyle(fontSize: 12, color: AppColors.amberDark)),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        }),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveStep1,
            child: Text(_saving
                ? tr('saving')
                : _existing != null
                    ? tr('saveChangesContinue')
                    : tr('saveContinue')),
          ),
        ),
      ],
    );
  }

  Widget _step2Docs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('uploadCnicSelfie'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(
          tr('uploadCnicSelfieHint'),
          style: const TextStyle(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _cnic,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('cnicNumber'),
                  hintText: '35202-1234567-1',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _saveCnicNumber, child: const Text('Save')),
          ],
        ),
        Text(
          tr('cnicPrivateNote'),
          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
        if (_cnicSaved)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(tr('cnicSaved'), style: const TextStyle(color: AppColors.teal)),
          ),
        const SizedBox(height: 16),
        _docTile('cnic_front'),
        const SizedBox(height: 12),
        _docTile('cnic_back'),
        const SizedBox(height: 12),
        _docTile('selfie'),
        if (_docError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_docError!, style: const TextStyle(color: Colors.red)),
          ),
        if (_docNotice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_docNotice!, style: const TextStyle(color: AppColors.teal)),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 16, color: AppColors.teal),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr('docsPrivateNote'),
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check),
            label: Text(tr('doneDashboard')),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _step = 1),
            child: Text(tr('backToDetails')),
          ),
        ),
      ],
    );
  }

  Widget _docTile(String type) {
    final doc = _docOf(type);
    final local = _localPhotos[type];
    final uploading = _uploadingType == type;
    final isSelfie = type == 'selfie';
    Widget preview;
    if (local != null) {
      preview = Image.file(File(local.path), height: 144, width: double.infinity, fit: BoxFit.cover);
    } else if (doc?.documentUrl != null) {
      preview = Image.network(doc!.documentUrl!, height: 144, width: double.infinity, fit: BoxFit.cover);
    } else {
      preview = Container(
        height: 144,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(style: BorderStyle.solid, color: AppColors.sandDark),
        ),
        child: const Text('No photo uploaded yet', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_docLabel(type), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(_docHint(type), style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(12), child: preview),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: uploading ? null : () => _pickPhoto(type, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: Text(uploading
                      ? 'Uploading…'
                      : isSelfie
                          ? 'Take selfie'
                          : 'Take photo'),
                ),
                OutlinedButton.icon(
                  onPressed: uploading ? null : () => _pickPhoto(type, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: Text(doc != null ? 'Replace photo' : 'Choose from gallery'),
                ),
                if (doc != null)
                  Chip(
                    label: Text(
                      doc.verificationStatus == 'approved'
                          ? 'Verified'
                          : doc.verificationStatus == 'rejected'
                              ? 'Rejected'
                              : 'Verification pending',
                    ),
                    backgroundColor: doc.verificationStatus == 'approved'
                        ? AppColors.tealLight
                        : const Color(0xFFFFF3D6),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The Step 1 mobile-number field, extracted so it can be widget-tested
/// in isolation (the full onboarding screen needs live Supabase to
/// load). Label + hint come from the language strings.
class MobileNumberField extends StatelessWidget {
  final TextEditingController controller;
  const MobileNumberField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: tr('mobileNumber'),
        hintText: '0300-1234567',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
