// Supabase data access for Project Services (same project as the website).
// Uses the anon client + the user's session only — never the service-role key.
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'models.dart';

const double kCommissionRate = 0.15;

/// Dues limit for providers (Rs. 2,000). DISPLAY ONLY — the real check is
/// server-side: public.wallet_dues_limit() + provider_can_accept_jobs()
/// (migration 005). If the DB limit ever changes, update this to match.
const num kWalletDuesLimitRs = 2000;
const String kMediaBucket = 'booking-media';

SupabaseClient get db => Supabase.instance.client;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
}

// ---------- Auth ----------

Future<Profile?> currentProfile() async {
  final user = db.auth.currentUser;
  if (user == null) return null;
  final res = await db.from('profiles').select().eq('id', user.id).maybeSingle();
  if (res == null) return null;
  return Profile.fromMap(res as Map<String, dynamic>);
}

/// Create the profiles row for a newly signed-up user (mirrors the website).
Future<void> ensureProfile({
  required String fullName,
  required String phone,
  required String role,
}) async {
  final user = db.auth.currentUser;
  if (user == null) return;
  final existing = await db.from('profiles').select('id').eq('id', user.id).maybeSingle();
  if (existing != null) return;
  await db.from('profiles').insert({
    'id': user.id,
    'full_name': fullName.trim(),
    'phone': phone.trim().isEmpty ? null : phone.trim(),
    'email': user.email,
    'role': role,
  });
}

/// Cities the app serves — same 6 as the website header selector.
const List<String> kServiceCities = [
  'Lahore',
  'Karachi',
  'Islamabad',
  'Rawalpindi',
  'Faisalabad',
  'Quetta',
];

/// Default city when the customer has not picked one yet.
const String kDefaultCity = 'Lahore';

String _normalizeCity(String? city) => (city ?? '').trim().toLowerCase();

/// True when a provider serves [city]: an exact (case-insensitive) match,
/// or the provider has no city set (treated as available everywhere, so
/// no existing provider ever vanishes from the list).
bool providerMatchesCity(String? providerCity, String? city) {
  final wanted = _normalizeCity(city);
  if (wanted.isEmpty) return true;
  final have = _normalizeCity(providerCity);
  if (have.isEmpty) return true;
  return have == wanted;
}

/// Filter a provider list to one city (case-insensitive; providers with
/// no city set are kept). Pure — unit-tested in test/city_filter_test.dart.
List<Provider> filterProvidersByCity(List<Provider> providers, String? city) {
  if (_normalizeCity(city).isEmpty) return List<Provider>.of(providers);
  return providers.where((p) => providerMatchesCity(p.city, city)).toList();
}

// ---------- Catalog (live) ----------

Future<List<Category>> fetchCategories() async {
  final res = await db
      .from('categories')
      .select('id, name, slug, description, is_active')
      .eq('is_active', true)
      .order('name');
  return (res as List).map((m) => Category.fromMap(m as Map<String, dynamic>)).toList();
}

Future<List<ServiceItem>> fetchServicesByCategory(String categoryId) async {
  final res = await db
      .from('services')
      .select('id, category_id, name, slug, description, base_price, is_active')
      .eq('category_id', categoryId)
      .eq('is_active', true)
      .order('name');
  return (res as List).map((m) => ServiceItem.fromMap(m as Map<String, dynamic>)).toList();
}

Future<List<ServiceItem>> searchServices(String query) async {
  final res = await db
      .from('services')
      .select('id, category_id, name, slug, description, base_price, is_active')
      .eq('is_active', true)
      .ilike('name', '%$query%')
      .order('name')
      .limit(20);
  return (res as List).map((m) => ServiceItem.fromMap(m as Map<String, dynamic>)).toList();
}

Future<List<ServiceItem>> fetchAllServices() async {
  final res = await db
      .from('services')
      .select('id, category_id, name, slug, description, base_price, is_active')
      .eq('is_active', true)
      .order('name');
  return (res as List).map((m) => ServiceItem.fromMap(m as Map<String, dynamic>)).toList();
}

// ---------- Providers (approved, live) ----------

/// Approved providers who offer [serviceId], with their own charge.
/// Falls back to every approved provider when a service has no skill rows yet.
/// When [city] is given, only providers in that city are returned
/// (case-insensitive; providers with no city set are always included).
Future<List<Provider>> fetchProvidersForService(String serviceId, {String? city}) async {
  final skills = await db
      .from('provider_skills')
      .select('provider_id, price, service_id')
      .eq('service_id', serviceId);
  final priceByProvider = <String, num>{
    for (final s in (skills as List))
      (s as Map<String, dynamic>)['provider_id'] as String:
          ((s)['price'] as num?) ?? 0,
  };
  final profiles = await db
      .from('provider_profiles')
      .select('id, user_id, bio, city, experience_years, verification_status, is_available, average_rating')
      .eq('verification_status', 'approved')
      .order('average_rating', ascending: false);
  final rows = (profiles as List).cast<Map<String, dynamic>>();
  final wanted = priceByProvider.isEmpty
      ? rows
      : rows.where((r) => priceByProvider.containsKey(r['id'] as String)).toList();
  final providers = <Provider>[];
  for (final r in wanted) {
    final userId = r['user_id'] as String;
    final prof = await db
        .from('profiles')
        .select('full_name, email, phone')
        .eq('id', userId)
        .maybeSingle() as Map<String, dynamic>?;
    providers.add(Provider(
      id: r['id'] as String,
      userId: userId,
      name: (prof?['full_name'] as String?)?.trim().isNotEmpty == true
          ? (prof!['full_name'] as String)
          : 'Verified technician',
      email: prof?['email'] as String?,
      phone: prof?['phone'] as String?,
      bio: r['bio'] as String?,
      city: r['city'] as String?,
      experienceYears: (r['experience_years'] as num?)?.toInt() ?? 0,
      verificationStatus: r['verification_status'] as String,
      isAvailable: (r['is_available'] as bool?) ?? true,
      averageRating: (r['average_rating'] as num?) ?? 0,
      price: priceByProvider[r['id'] as String],
    ));
  }
  return filterProvidersByCity(providers, city);
}

Future<List<Provider>> fetchApprovedProviders({int limit = 6, String? city}) async {
  // Fetch generously, then filter by city and take [limit]: applying the
  // DB limit first could drop every provider in the selected city.
  final profiles = await db
      .from('provider_profiles')
      .select('id, user_id, bio, city, experience_years, verification_status, is_available, average_rating')
      .eq('verification_status', 'approved')
      .order('average_rating', ascending: false)
      .limit(50);
  final providers = <Provider>[];
  for (final r in (profiles as List).cast<Map<String, dynamic>>()) {
    final userId = r['user_id'] as String;
    final prof = await db
        .from('profiles')
        .select('full_name, email, phone')
        .eq('id', userId)
        .maybeSingle() as Map<String, dynamic>?;
    providers.add(Provider(
      id: r['id'] as String,
      userId: userId,
      name: (prof?['full_name'] as String?)?.trim().isNotEmpty == true
          ? (prof!['full_name'] as String)
          : 'Verified technician',
      email: prof?['email'] as String?,
      phone: prof?['phone'] as String?,
      bio: r['bio'] as String?,
      city: r['city'] as String?,
      experienceYears: (r['experience_years'] as num?)?.toInt() ?? 0,
      verificationStatus: r['verification_status'] as String,
      isAvailable: (r['is_available'] as bool?) ?? true,
      averageRating: (r['average_rating'] as num?) ?? 0,
    ));
  }
  final filtered = filterProvidersByCity(providers, city);
  return filtered.length > limit ? filtered.sublist(0, limit) : filtered;
}

// ---------- Bookings ----------

Future<String> createBooking({
  required String serviceId,
  required String? providerId,
  required String description,
  required DateTime scheduledAt,
  required String addressText,
  required String city,
  required num estimatedPrice,
  required num commissionAmount,
  double? latitude,
  double? longitude,
}) async {
  final user = db.auth.currentUser!;
  String? addressId;
  if (addressText.trim().isNotEmpty) {
    final addr = await db
        .from('addresses')
        .insert({
          'user_id': user.id,
          'label': 'Home',
          'address_line': addressText.trim(),
          'city': city.trim().isEmpty ? null : city.trim(),
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'is_default': false,
        })
        .select('id')
        .single();
    addressId = (addr as Map<String, dynamic>)['id'] as String;
  }
  final row = await db
      .from('bookings')
      .insert({
        'customer_id': user.id,
        'provider_id': providerId,
        'service_id': serviceId,
        'address_id': addressId,
        'description': description.trim(),
        'scheduled_at': scheduledAt.toIso8601String(),
        'estimated_price': estimatedPrice,
        'commission_amount': commissionAmount,
        'status': 'pending',
        'payment_status': 'pending',
      })
      .select('id')
      .single();
  return (row as Map<String, dynamic>)['id'] as String;
}

Future<void> uploadBookingPhotos(String bookingId, List<File> files) async {
  final user = db.auth.currentUser!;
  for (final file in files) {
    final name = file.path.split('/').last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '${user.id}/$bookingId/${DateTime.now().millisecondsSinceEpoch}-$name';
    await db.storage.from(kMediaBucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: false),
        );
    final url = '${AppConfig.supabaseUrl}/storage/v1/object/public/$kMediaBucket/$path';
    await db.from('booking_media').insert({
      'booking_id': bookingId,
      'media_type': 'photo',
      'media_url': url,
      'uploaded_by': user.id,
    });
  }
}

Future<List<Booking>> fetchMyBookings() async {
  final user = db.auth.currentUser!;
  final res = await db
      .from('bookings')
      .select('id, customer_id, provider_id, service_id, status, payment_status, description, scheduled_at, estimated_price, final_price, commission_amount, created_at, pickup_shop_name, pickup_address, pickup_latitude, pickup_longitude, services(name), provider_profiles(id, profiles(full_name))')
      .eq('customer_id', user.id)
      .order('created_at', ascending: false);
  return (res as List).map((m) {
    final row = m as Map<String, dynamic>;
    final svc = row['services'];
    final pp = row['provider_profiles'];
    String? providerName;
    if (pp is Map<String, dynamic>) {
      final p = pp['profiles'];
      if (p is Map<String, dynamic>) providerName = p['full_name'] as String?;
    }
    return Booking(
      id: row['id'] as String,
      customerId: row['customer_id'] as String,
      providerId: row['provider_id'] as String?,
      serviceId: row['service_id'] as String?,
      serviceName: svc is Map<String, dynamic> ? (svc['name'] as String? ?? 'Service') : 'Service',
      providerName: providerName,
      status: row['status'] as String,
      paymentStatus: row['payment_status'] as String,
      description: row['description'] as String?,
      scheduledAt: row['scheduled_at'] != null ? DateTime.parse(row['scheduled_at'] as String) : null,
      estimatedPrice: (row['estimated_price'] as num?),
      finalPrice: (row['final_price'] as num?),
      commissionAmount: (row['commission_amount'] as num?),
      createdAt: DateTime.parse(row['created_at'] as String),
      pickupShopName: row['pickup_shop_name'] as String?,
      pickupAddress: row['pickup_address'] as String?,
      pickupLatitude: (row['pickup_latitude'] as num?)?.toDouble(),
      pickupLongitude: (row['pickup_longitude'] as num?)?.toDouble(),
    );
  }).toList();
}

Future<List<BookingMedia>> fetchBookingMedia(String bookingId) async {
  final res = await db
      .from('booking_media')
      .select('id, media_type, media_url, created_at')
      .eq('booking_id', bookingId)
      .order('created_at', ascending: true);
  return (res as List).map((m) => BookingMedia.fromMap(m as Map<String, dynamic>)).toList();
}

Future<List<StatusEvent>> fetchBookingHistory(String bookingId) async {
  final res = await db
      .from('booking_status_history')
      .select('old_status, new_status, changed_at')
      .eq('booking_id', bookingId)
      .order('changed_at', ascending: true);
  return (res as List).map((m) => StatusEvent.fromMap(m as Map<String, dynamic>)).toList();
}

// ---------- Provider side ----------

Future<Map<String, dynamic>?> fetchMyProviderProfile() async {
  final user = db.auth.currentUser!;
  final res = await db
      .from('provider_profiles')
      .select('id, user_id, bio, city, experience_years, verification_status, is_available, average_rating')
      .eq('user_id', user.id)
      .maybeSingle();
  return res as Map<String, dynamic>?;
}

// ---------- Provider onboarding (mirrors the website /provider/onboarding) ----------
// Step 1: profile form (CNIC number, city, experience, bio, services +
// own charges). Step 2: CNIC front/back photos + selfie. Everything goes
// through RLS: a provider manages only their own rows, exactly like the
// website — no service-role key anywhere.

/// Create or update the provider_profiles row for a user.
/// Upserts on the UNIQUE(user_id) constraint (website: saveProviderProfile).
Future<Map<String, dynamic>> saveProviderProfile({
  required int experienceYears,
  required String? bio,
  required String? city,
}) async {
  final user = db.auth.currentUser!;
  final row = await db
      .from('provider_profiles')
      .upsert(
        {
          'user_id': user.id,
          'experience_years': experienceYears,
          'bio': bio,
          'city': city,
        },
        onConflict: 'user_id',
      )
      .select('id, user_id, bio, city, experience_years, verification_status, is_available, average_rating')
      .single();
  return row as Map<String, dynamic>;
}

/// One service offered by the provider, with their own charge.
class ProviderSkillInput {
  final String serviceId;
  final num price;
  final int experienceYears;
  const ProviderSkillInput({
    required this.serviceId,
    required this.price,
    required this.experienceYears,
  });
}

/// Replace a provider's skill set with the given list: skills that are no
/// longer selected are deleted, the rest are upserted (website:
/// saveProviderSkills).
Future<void> saveProviderSkills(String providerId, List<ProviderSkillInput> skills) async {
  final wanted = skills.map((s) => s.serviceId).toList();
  var del = db.from('provider_skills').delete().eq('provider_id', providerId);
  if (wanted.isNotEmpty) {
    del = del.not('service_id', 'in', '(${wanted.join(',')})');
  }
  await del;
  if (skills.isEmpty) return;
  await db.from('provider_skills').upsert(
        skills
            .map((s) => {
                  'provider_id': providerId,
                  'service_id': s.serviceId,
                  'price': s.price,
                  'experience_years': s.experienceYears,
                  'is_active': true,
                })
            .toList(),
        onConflict: 'provider_id,service_id',
      );
}

/// All skills (service + own charge) for one provider, oldest first.
Future<List<Map<String, dynamic>>> fetchProviderSkills(String providerId) async {
  final res = await db
      .from('provider_skills')
      .select('id, provider_id, service_id, experience_years, price, is_active')
      .eq('provider_id', providerId)
      .order('created_at', ascending: true);
  return (res as List).cast<Map<String, dynamic>>();
}

/// All verification documents for one provider (owner / admin only, RLS).
Future<List<ProviderDocument>> fetchProviderDocuments(String providerId) async {
  final res = await db
      .from('provider_documents')
      .select('id, provider_id, document_type, document_url, document_number, verification_status, created_at')
      .eq('provider_id', providerId)
      .order('created_at', ascending: true);
  return (res as List)
      .map((m) => ProviderDocument.fromMap(m as Map<String, dynamic>))
      .toList();
}

/// Create or update one document row for a provider (keyed by
/// provider_id + document_type, e.g. 'cnic_front' / 'cnic_back' /
/// 'selfie'). There is no UNIQUE constraint on that pair, so this reads
/// first and then updates or inserts (website: upsertProviderDocument).
Future<ProviderDocument> upsertProviderDocument(
  String providerId,
  String documentType, {
  String? documentUrl,
  String? documentNumber,
}) async {
  final existing = await db
      .from('provider_documents')
      .select('id')
      .eq('provider_id', providerId)
      .eq('document_type', documentType)
      .maybeSingle() as Map<String, dynamic>?;
  final patch = <String, dynamic>{
    if (documentUrl != null) 'document_url': documentUrl,
    if (documentNumber != null) 'document_number': documentNumber,
  };
  if (existing != null) {
    final row = await db
        .from('provider_documents')
        .update(patch)
        .eq('id', existing['id'] as String)
        .select('id, provider_id, document_type, document_url, document_number, verification_status, created_at')
        .single();
    return ProviderDocument.fromMap(row as Map<String, dynamic>);
  }
  final row = await db
      .from('provider_documents')
      .insert({
        'provider_id': providerId,
        'document_type': documentType,
        'verification_status': 'pending',
        ...patch,
      })
      .select('id, provider_id, document_type, document_url, document_number, verification_status, created_at')
      .single();
  return ProviderDocument.fromMap(row as Map<String, dynamic>);
}

String? validateDocumentFile(File file) {
  final size = file.lengthSync();
  if (size == 0) return 'The photo is empty.';
  if (size > 10 * 1024 * 1024) {
    return 'The photo is over 10 MB — please pick a smaller photo.';
  }
  return null;
}

/// Upload one verification photo (CNIC front/back or selfie) to the
/// booking-media bucket under {user_id}/provider-docs/… — the same bucket
/// and path convention as the website — and point the matching document
/// row at it. A failed upload never creates a document row.
Future<ProviderDocument> uploadProviderDocument(
  String providerId,
  String documentType,
  File file, {
  String? documentNumber,
}) async {
  final problem = validateDocumentFile(file);
  if (problem != null) throw Exception(problem);
  final user = db.auth.currentUser!;
  final name = file.path.split('/').last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final path = '${user.id}/provider-docs/${DateTime.now().millisecondsSinceEpoch}-$name';
  await db.storage.from(kMediaBucket).upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: false),
      );
  final url = '${AppConfig.supabaseUrl}/storage/v1/object/public/$kMediaBucket/$path';
  return upsertProviderDocument(
    providerId,
    documentType,
    documentUrl: url,
    documentNumber: documentNumber,
  );
}

Future<void> setAvailability(bool online) async {
  final profile = await fetchMyProviderProfile();
  if (profile == null) return;
  final providerId = profile['id'] as String;
  await db.from('provider_profiles').update({'is_available': online}).eq('id', providerId);
  // Keep the 7 per-day availability rows in sync (09:00-18:00 default).
  for (var day = 0; day < 7; day++) {
    await db.from('availability').upsert(
      {
        'provider_id': providerId,
        'day_of_week': day,
        'start_time': '09:00',
        'end_time': '18:00',
        'is_available': online,
      },
      onConflict: 'provider_id,day_of_week',
    );
  }
  // Going offline must also hide the live location. Best-effort: the
  // server-side hide_location_when_offline trigger (migration 007)
  // deletes the row anyway — this is just the fast path, and it must
  // never fail the availability toggle.
  if (!online) {
    try {
      await clearMyProviderLocation();
    } catch (_) {
      // Ignore — the DB trigger is the enforcement.
    }
  }
}

Future<List<Booking>> fetchProviderJobs() async {
  final profile = await fetchMyProviderProfile();
  if (profile == null) return [];
  final providerId = profile['id'] as String;
  final res = await db
      .from('bookings')
      .select('id, customer_id, provider_id, service_id, status, payment_status, description, scheduled_at, estimated_price, final_price, commission_amount, created_at, pickup_shop_name, pickup_address, pickup_latitude, pickup_longitude, services(name), profiles!bookings_customer_id_fkey(full_name)')
      .eq('provider_id', providerId)
      .order('created_at', ascending: false);
  return (res as List).map((m) {
    final row = m as Map<String, dynamic>;
    final svc = row['services'];
    final cust = row['profiles'];
    return Booking(
      id: row['id'] as String,
      customerId: row['customer_id'] as String,
      providerId: row['provider_id'] as String?,
      serviceId: row['service_id'] as String?,
      serviceName: svc is Map<String, dynamic> ? (svc['name'] as String? ?? 'Service') : 'Service',
      providerName: cust is Map<String, dynamic> ? (cust['full_name'] as String?) : null,
      status: row['status'] as String,
      paymentStatus: row['payment_status'] as String,
      description: row['description'] as String?,
      scheduledAt: row['scheduled_at'] != null ? DateTime.parse(row['scheduled_at'] as String) : null,
      estimatedPrice: (row['estimated_price'] as num?),
      finalPrice: (row['final_price'] as num?),
      commissionAmount: (row['commission_amount'] as num?),
      createdAt: DateTime.parse(row['created_at'] as String),
      pickupShopName: row['pickup_shop_name'] as String?,
      pickupAddress: row['pickup_address'] as String?,
      pickupLatitude: (row['pickup_latitude'] as num?)?.toDouble(),
      pickupLongitude: (row['pickup_longitude'] as num?)?.toDouble(),
    );
  }).toList();
}

Future<void> updateBookingStatus(String bookingId, String newStatus) async {
  await db.from('bookings').update({'status': newStatus}).eq('id', bookingId);
  // NOTE: do NOT insert into booking_status_history here. The database
  // trigger log_booking_status_change() (SECURITY DEFINER) writes the
  // history row automatically on every status change, and there is no
  // direct INSERT policy for clients on that table — a direct insert
  // fails with RLS 42501 ("new row violates row-level security policy").
}

Future<Map<String, num>> fetchProviderEarnings() async {
  final profile = await fetchMyProviderProfile();
  if (profile == null) return {'earned': 0, 'commission': 0, 'jobs': 0};
  final providerId = profile['id'] as String;
  final ledger = await db
      .from('commission_ledger')
      .select('provider_amount, commission_amount')
      .eq('provider_id', providerId);
  num earned = 0, commission = 0;
  for (final r in (ledger as List)) {
    earned += (r as Map<String, dynamic>)['provider_amount'] as num? ?? 0;
    commission += (r)['commission_amount'] as num? ?? 0;
  }
  final completedRows = await db
      .from('bookings')
      .select('id')
      .eq('provider_id', providerId)
      .eq('status', 'completed');
  final completed = (completedRows as List).length;
  return {'earned': earned, 'commission': commission, 'jobs': completed};
}

// ---------- Provider wallet (migration 005) ----------
// The wallet is the provider's prepaid balance. balance >= 0 is credit;
// balance < 0 is DUES owed to the platform. Commission is deducted
// server-side by a trigger when a job completes — the client never
// writes wallet rows; top-ups are recorded by an admin on the website.

/// The signed-in provider's wallet. A zero balance is returned when no
/// wallet row exists yet (new provider, no transactions so far).
Future<ProviderWallet?> getProviderWallet() async {
  final profile = await fetchMyProviderProfile();
  if (profile == null) return null;
  final providerId = profile['id'] as String;
  final res = await db
      .from('provider_wallets')
      .select('provider_id, balance, updated_at')
      .eq('provider_id', providerId)
      .maybeSingle();
  if (res == null) {
    return ProviderWallet(
      providerId: providerId,
      balance: 0,
      updatedAt: DateTime.now(),
    );
  }
  return ProviderWallet.fromMap(res as Map<String, dynamic>);
}

/// The signed-in provider's wallet ledger, newest first.
Future<List<WalletTransaction>> listWalletTransactions({int limit = 20}) async {
  final profile = await fetchMyProviderProfile();
  if (profile == null) return [];
  final providerId = profile['id'] as String;
  final res = await db
      .from('wallet_transactions')
      .select('id, provider_id, kind, amount, booking_id, reference, note, created_at')
      .eq('provider_id', providerId)
      .order('created_at', ascending: false)
      .limit(limit);
  return (res as List)
      .map((m) => WalletTransaction.fromMap(m as Map<String, dynamic>))
      .toList();
}

/// Server-side check (RPC): may this provider accept a new job?
/// Returns false when their dues are over the Rs. 2,000 limit. The same
/// check also runs in the database BEFORE UPDATE trigger on bookings,
/// so the app check is the friendly warning, not the enforcement.
Future<bool> providerCanAcceptJobs() async {
  final profile = await fetchMyProviderProfile();
  if (profile == null) return false;
  final res = await db.rpc(
    'provider_can_accept_jobs',
    params: {'p': profile['id'] as String},
  );
  return res as bool? ?? false;
}

Future<List<Map<String, dynamic>>> fetchProviderReviews() async {
  final profile = await fetchMyProviderProfile();
  if (profile == null) return [];
  final providerId = profile['id'] as String;
  final res = await db
      .from('reviews')
      .select('rating, comment, created_at, profiles!reviews_customer_id_fkey(full_name)')
      .eq('provider_id', providerId)
      .order('created_at', ascending: false)
      .limit(20);
  return (res as List).cast<Map<String, dynamic>>();
}

Future<List<Map<String, dynamic>>> fetchMyReviews() async {
  final user = db.auth.currentUser!;
  final res = await db
      .from('reviews')
      .select('rating, comment, created_at, bookings(services(name))')
      .eq('customer_id', user.id)
      .order('created_at', ascending: false)
      .limit(20);
  return (res as List).cast<Map<String, dynamic>>();
}

// ---------- FCM device tokens ----------

/// Save (or refresh) this device's FCM push token for the signed-in user.
/// Upserts on the token so a refreshed token replaces the old row.
Future<void> saveDeviceToken(String token) async {
  final user = db.auth.currentUser;
  if (user == null) return;
  await db.from('device_tokens').upsert(
    {
      'user_id': user.id,
      'token': token,
      'platform': 'android',
    },
    onConflict: 'token',
  );
}

// ---------- In-app chat ----------

/// Fill in a conversation's display fields (service, other party, last
/// message, unread count) from the booking + profiles + messages.
Future<Conversation> _enrichConversation(
  Conversation conv, {
  required bool iAmCustomer,
  required String myUserId,
}) async {
  var serviceName = 'Service';
  var otherName = iAmCustomer ? 'Technician' : 'Customer';
  final booking = await db
      .from('bookings')
      .select('id, service_id, customer_id, provider_id, services(name)')
      .eq('id', conv.bookingId)
      .maybeSingle() as Map<String, dynamic>?;
  if (booking != null) {
    final svc = booking['services'];
    if (svc is Map<String, dynamic>) {
      serviceName = (svc['name'] as String?) ?? 'Service';
    }
    if (iAmCustomer) {
      final pid = booking['provider_id'] as String?;
      if (pid != null) {
        final pp = await db
            .from('provider_profiles')
            .select('user_id')
            .eq('id', pid)
            .maybeSingle() as Map<String, dynamic>?;
        final uid = pp?['user_id'] as String?;
        if (uid != null) {
          final prof = await db
              .from('profiles')
              .select('full_name')
              .eq('id', uid)
              .maybeSingle() as Map<String, dynamic>?;
          final name = prof?['full_name'] as String?;
          if (name != null && name.trim().isNotEmpty) otherName = name;
        }
      }
    } else {
      final cid = booking['customer_id'] as String?;
      if (cid != null) {
        final prof = await db
            .from('profiles')
            .select('full_name')
            .eq('id', cid)
            .maybeSingle() as Map<String, dynamic>?;
        final name = prof?['full_name'] as String?;
        if (name != null && name.trim().isNotEmpty) otherName = name;
      }
    }
  }
  final last = await db
      .from('messages')
      .select('message_text, created_at')
      .eq('conversation_id', conv.id)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle() as Map<String, dynamic>?;
  final unreadRes = await db
      .from('messages')
      .select('id')
      .eq('conversation_id', conv.id)
      .eq('is_read', false)
      .neq('sender_id', myUserId);
  return conv.copyWith(
    serviceName: serviceName,
    otherPartyName: otherName,
    lastMessageText: last?['message_text'] as String?,
    lastMessageAt: last?['created_at'] != null
        ? DateTime.parse(last!['created_at'] as String)
        : null,
    unreadCount: (unreadRes as List).length,
  );
}

/// All conversations for the signed-in user — as a customer (their bookings)
/// or as a provider (their assigned jobs). Newest first.
Future<List<Conversation>> fetchMyConversations() async {
  final user = db.auth.currentUser!;
  final profile = await currentProfile();
  final iAmCustomer = profile?.role != 'provider';
  List<Map<String, dynamic>> rows;
  if (iAmCustomer) {
    final res = await db
        .from('conversations')
        .select()
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);
    rows = (res as List).cast<Map<String, dynamic>>();
  } else {
    final pp = await fetchMyProviderProfile();
    final providerId = pp?['id'] as String?;
    if (providerId == null) return [];
    final res = await db
        .from('conversations')
        .select()
        .eq('provider_id', providerId)
        .order('created_at', ascending: false);
    rows = (res as List).cast<Map<String, dynamic>>();
  }
  final out = <Conversation>[];
  for (final row in rows) {
    out.add(await _enrichConversation(
      Conversation.fromMap(row),
      iAmCustomer: iAmCustomer,
      myUserId: user.id,
    ));
  }
  return out;
}

/// The chat thread for a booking — returns the existing one, or creates it.
/// RLS: the customer creates it; the provider can also create it once
/// migration 003 (conversations_insert_provider) is applied.
Future<Conversation> getOrCreateConversation(String bookingId) async {
  final user = db.auth.currentUser!;
  final profile = await currentProfile();
  final iAmCustomer = profile?.role != 'provider';
  final existing = await db
      .from('conversations')
      .select()
      .eq('booking_id', bookingId)
      .maybeSingle();
  if (existing != null) {
    return _enrichConversation(
      Conversation.fromMap(existing),
      iAmCustomer: iAmCustomer,
      myUserId: user.id,
    );
  }
  final booking = await db
      .from('bookings')
      .select('id, customer_id, provider_id')
      .eq('id', bookingId)
      .single();
  final providerId = booking['provider_id'] as String?;
  if (providerId == null) {
    throw Exception('No technician assigned to this booking yet.');
  }
  final inserted = await db
      .from('conversations')
      .insert({
        'booking_id': bookingId,
        'customer_id': booking['customer_id'],
        'provider_id': providerId,
      })
      .select()
      .single();
  return _enrichConversation(
    Conversation.fromMap(inserted),
    iAmCustomer: iAmCustomer,
    myUserId: user.id,
  );
}

Future<List<ChatMessage>> fetchMessages(String conversationId) async {
  final res = await db
      .from('messages')
      .select()
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true);
  return (res as List)
      .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
      .toList();
}

Future<ChatMessage> sendMessage(String conversationId, String text) async {
  final user = db.auth.currentUser!;
  final row = await db
      .from('messages')
      .insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'message_text': text.trim(),
        'is_read': false,
      })
      .select()
      .single();
  return ChatMessage.fromMap(row);
}

/// Mark the other party's unread messages in this conversation as read.
Future<void> markMessagesRead(String conversationId) async {
  final user = db.auth.currentUser!;
  await db
      .from('messages')
      .update({'is_read': true})
      .eq('conversation_id', conversationId)
      .eq('is_read', false)
      .neq('sender_id', user.id);
}

/// Live updates for new messages in a conversation (Supabase Realtime).
/// Returns the channel — the caller must remove it on dispose with
/// `db.removeChannel(channel)`. Needs the messages table in the
/// supabase_realtime publication (migration 003).
RealtimeChannel subscribeToConversationMessages(
  String conversationId,
  void Function(ChatMessage) onInsert,
) {
  final channel = db.channel('chat-$conversationId');
  channel.onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'messages',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'conversation_id',
      value: conversationId,
    ),
    callback: (payload) {
      final row = payload.newRecord;
      if (row.isEmpty) return;
      try {
        onInsert(ChatMessage.fromMap(Map<String, dynamic>.from(row)));
      } catch (_) {
        // Ignore malformed realtime payloads; the list refresh covers it.
      }
    },
  );
  channel.subscribe();
  return channel;
}

// ---------- Provider live locations (migration 007, Phase A map) ----------

/// Live positions of online + approved + available providers — the
/// nearby markers on the customer map. RLS already restricts the rows
/// to online/approved/available; this also filters client-side by
/// verification_status + is_available (+ city when given) so a row can
/// never slip through if the policy ever widens.
Future<List<ProviderLocation>> fetchProviderLocations({String? city}) async {
  final profiles = await db
      .from('provider_profiles')
      .select('id, city, verification_status, is_available')
      .eq('verification_status', 'approved')
      .eq('is_available', true);
  final byId = <String, Map<String, dynamic>>{
    for (final r in (profiles as List).cast<Map<String, dynamic>>())
      r['id'] as String: r,
  };
  final res = await db
      .from('provider_locations')
      .select('provider_id, latitude, longitude, accuracy_m, is_online, updated_at')
      .eq('is_online', true);
  final out = <ProviderLocation>[];
  for (final m in (res as List).cast<Map<String, dynamic>>()) {
    final profile = byId[m['provider_id'] as String];
    if (profile == null) continue;
    if (!providerMatchesCity(profile['city'] as String?, city)) continue;
    out.add(ProviderLocation.fromMap(m));
  }
  return out;
}

/// Publish (or refresh) my live position. Resolves my provider profile
/// first; does nothing when I have no provider profile.
Future<void> upsertMyProviderLocation({
  required double latitude,
  required double longitude,
  double? accuracyMeters,
}) async {
  final profile = await fetchMyProviderProfile();
  if (profile == null) return;
  await db.from('provider_locations').upsert(
    {
      'provider_id': profile['id'] as String,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyMeters,
      'is_online': true,
      'updated_at': DateTime.now().toIso8601String(),
    },
    onConflict: 'provider_id',
  );
}

/// Delete my live-location row (going offline). Best-effort: never
/// throws when there is no profile or no row.
Future<void> clearMyProviderLocation() async {
  try {
    final profile = await fetchMyProviderProfile();
    if (profile == null) return;
    await db
        .from('provider_locations')
        .delete()
        .eq('provider_id', profile['id'] as String);
  } catch (_) {
    // Best-effort — the hide_location_when_offline trigger (migration
    // 007) deletes the row server-side when availability flips off.
  }
}

/// Live updates for one provider's position (Supabase Realtime).
/// Returns the channel — the caller must remove it on dispose with
/// `db.removeChannel(channel)`. Needs provider_locations in the
/// supabase_realtime publication (migration 007).
RealtimeChannel subscribeToProviderLocation(
  String providerId,
  void Function(ProviderLocation) onUpdate,
) {
  final channel = db.channel('provider-location-$providerId');
  channel.onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'provider_locations',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'provider_id',
      value: providerId,
    ),
    callback: (payload) {
      final row = payload.newRecord;
      if (row.isEmpty) return;
      try {
        onUpdate(ProviderLocation.fromMap(Map<String, dynamic>.from(row)));
      } catch (_) {
        // Ignore malformed realtime payloads; a refetch covers it.
      }
    },
  );
  channel.onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'provider_locations',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'provider_id',
      value: providerId,
    ),
    callback: (payload) {
      final row = payload.newRecord;
      if (row.isEmpty) return;
      try {
        onUpdate(ProviderLocation.fromMap(Map<String, dynamic>.from(row)));
      } catch (_) {
        // Ignore malformed realtime payloads; a refetch covers it.
      }
    },
  );
  channel.subscribe();
  return channel;
}

/// The saved address (with coordinates, when present) for a booking.
/// Returns null when the booking has no address.
Future<ServiceAddress?> fetchBookingAddress(String bookingId) async {
  final booking = await db
      .from('bookings')
      .select('address_id')
      .eq('id', bookingId)
      .maybeSingle();
  final addressId = booking?['address_id'] as String?;
  if (addressId == null) return null;
  final row = await db
      .from('addresses')
      .select('id, address_line, city, latitude, longitude')
      .eq('id', addressId)
      .maybeSingle();
  if (row == null) return null;
  return ServiceAddress.fromMap(row);
}
