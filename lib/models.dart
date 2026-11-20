// Data models matching the Supabase tables (see website migration 001/002).
import 'l10n/strings.dart';
class Category {
  final String id;
  final String name;
  final String slug;
  final String? description;
  Category({required this.id, required this.name, required this.slug, this.description});
  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        name: m['name'] as String,
        slug: m['slug'] as String,
        description: m['description'] as String?,
      );
}

class ServiceItem {
  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String? description;
  final num basePrice;
  ServiceItem({required this.id, required this.categoryId, required this.name, required this.slug, this.description, required this.basePrice});
  factory ServiceItem.fromMap(Map<String, dynamic> m) => ServiceItem(
        id: m['id'] as String,
        categoryId: m['category_id'] as String,
        name: m['name'] as String,
        slug: m['slug'] as String,
        description: m['description'] as String?,
        basePrice: (m['base_price'] as num?) ?? 0,
      );
}

class Provider {
  final String id; // provider_profiles.id
  final String userId;
  final String name;
  final String? email;
  final String? phone;
  final String? bio;
  final String? city;
  final int experienceYears;
  final String verificationStatus;
  final bool isAvailable;
  final num averageRating;
  final num? price; // price for the selected service (from provider_skills)
  Provider({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.bio,
    this.city,
    required this.experienceYears,
    required this.verificationStatus,
    required this.isAvailable,
    required this.averageRating,
    this.price,
  });
}

class Booking {
  final String id;
  final String customerId;
  final String? providerId;
  final String? serviceId;
  final String serviceName;
  final String? providerName;
  final String status;
  final String paymentStatus;
  final String? description;
  final DateTime? scheduledAt;
  final num? estimatedPrice;
  final num? finalPrice;
  final num? commissionAmount;
  // Cash received (migration 010): amount the provider declared taking
  // from the customer at completion + when it was declared. Null until
  // the provider declares it.
  final num? cashReceivedAmount;
  final DateTime? cashReceivedAt;
  final DateTime createdAt;
  // Delivery on Demand (migration 008): pickup point for rider jobs.
  // Null for normal service bookings.
  final String? pickupShopName;
  final String? pickupAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  Booking({
    required this.id,
    required this.customerId,
    this.providerId,
    this.serviceId,
    required this.serviceName,
    this.providerName,
    required this.status,
    required this.paymentStatus,
    this.description,
    this.scheduledAt,
    this.estimatedPrice,
    this.finalPrice,
    this.commissionAmount,
    this.cashReceivedAmount,
    this.cashReceivedAt,
    required this.createdAt,
    this.pickupShopName,
    this.pickupAddress,
    this.pickupLatitude,
    this.pickupLongitude,
  });

  /// True when this is a delivery booking with a pickup point
  /// (coordinates, or at least a pickup address text).
  bool get hasPickup =>
      (pickupLatitude != null && pickupLongitude != null) ||
      (pickupAddress != null && pickupAddress!.trim().isNotEmpty);
}

class BookingMedia {
  final String id;
  final String mediaType;
  final String? mediaUrl;
  BookingMedia({required this.id, required this.mediaType, this.mediaUrl});
  factory BookingMedia.fromMap(Map<String, dynamic> m) => BookingMedia(
        id: m['id'] as String,
        mediaType: m['media_type'] as String,
        mediaUrl: m['media_url'] as String?,
      );
}

class StatusEvent {
  final String? oldStatus;
  final String? newStatus;
  final DateTime changedAt;
  StatusEvent({this.oldStatus, this.newStatus, required this.changedAt});
  factory StatusEvent.fromMap(Map<String, dynamic> m) => StatusEvent(
        oldStatus: m['old_status'] as String?,
        newStatus: m['new_status'] as String?,
        changedAt: DateTime.parse(m['changed_at'] as String),
      );
}

class Profile {
  final String id;
  final String? fullName;
  final String? phone;
  final String email;
  final String role;
  Profile({required this.id, this.fullName, this.phone, required this.email, required this.role});
  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        fullName: m['full_name'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String,
        role: m['role'] as String? ?? 'customer',
      );
}

/// One chat thread — always tied to a single booking (customer ↔ provider).
class Conversation {
  final String id;
  final String bookingId;
  final String? customerId;
  final String? providerId;
  final DateTime createdAt;
  // Display fields, filled in by the repository from the booking + profiles.
  final String serviceName;
  final String otherPartyName;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  Conversation({
    required this.id,
    required this.bookingId,
    this.customerId,
    this.providerId,
    required this.createdAt,
    this.serviceName = 'Service',
    this.otherPartyName = 'Chat',
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
  });
  factory Conversation.fromMap(Map<String, dynamic> m) => Conversation(
        id: m['id'] as String,
        bookingId: m['booking_id'] as String,
        customerId: m['customer_id'] as String?,
        providerId: m['provider_id'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
  Conversation copyWith({
    String? serviceName,
    String? otherPartyName,
    String? lastMessageText,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) =>
      Conversation(
        id: id,
        bookingId: bookingId,
        customerId: customerId,
        providerId: providerId,
        createdAt: createdAt,
        serviceName: serviceName ?? this.serviceName,
        otherPartyName: otherPartyName ?? this.otherPartyName,
        lastMessageText: lastMessageText ?? this.lastMessageText,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

/// A single chat message inside a conversation.
class ChatMessage {
  final String id;
  final String conversationId;
  final String? senderId;
  final String? messageText;
  final bool isRead;
  final DateTime createdAt;
  ChatMessage({
    required this.id,
    required this.conversationId,
    this.senderId,
    this.messageText,
    required this.isRead,
    required this.createdAt,
  });
  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        conversationId: m['conversation_id'] as String,
        senderId: m['sender_id'] as String?,
        messageText: m['message_text'] as String?,
        isRead: (m['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// A provider's wallet (migration 005). balance >= 0 is prepaid credit;
/// balance < 0 is DUES the provider owes the platform (absolute value).
class ProviderWallet {
  final String providerId;
  final num balance;
  final DateTime updatedAt;
  ProviderWallet({required this.providerId, required this.balance, required this.updatedAt});
  factory ProviderWallet.fromMap(Map<String, dynamic> m) => ProviderWallet(
        providerId: m['provider_id'] as String,
        balance: (m['balance'] as num?) ?? 0,
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
  bool get hasDues => balance < 0;
  num get dues => balance < 0 ? -balance : 0;
}

/// One row of the wallet ledger (migration 005). Append-only: topup is
/// money in (positive), commission is the 15% fee (negative), refund /
/// adjustment are admin-recorded corrections.
class WalletTransaction {
  final String id;
  final String providerId;
  final String kind; // 'topup' | 'commission' | 'refund' | 'adjustment'
  final num amount;
  final String? bookingId;
  final String? reference;
  final String? note;
  final DateTime createdAt;
  WalletTransaction({
    required this.id,
    required this.providerId,
    required this.kind,
    required this.amount,
    this.bookingId,
    this.reference,
    this.note,
    required this.createdAt,
  });
  factory WalletTransaction.fromMap(Map<String, dynamic> m) => WalletTransaction(
        id: m['id'] as String,
        providerId: m['provider_id'] as String,
        kind: m['kind'] as String,
        amount: (m['amount'] as num?) ?? 0,
        bookingId: m['booking_id'] as String?,
        reference: m['reference'] as String?,
        note: m['note'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
  bool get isCredit => amount > 0;
  String get kindLabel {
    switch (kind) {
      case 'topup':
        return 'Top-up';
      case 'commission':
        return 'Platform fee (15%)';
      case 'refund':
        return 'Refund';
      case 'adjustment':
        return 'Adjustment';
      default:
        return kind;
    }
  }
}

/// A wallet top-up request (migration 014): the provider files the
/// amount + transaction reference + payment screenshot from the app;
/// the admin approves it on /admin and the wallet is credited then.
/// status is 'pending' | 'approved' | 'rejected'.
class TopupRequest {
  final String id;
  final String providerId;
  final num amount;
  final String reference;
  final String screenshotUrl;
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  TopupRequest({
    required this.id,
    required this.providerId,
    required this.amount,
    required this.reference,
    required this.screenshotUrl,
    required this.status,
    this.adminNote,
    required this.createdAt,
    this.reviewedAt,
  });
  factory TopupRequest.fromMap(Map<String, dynamic> m) => TopupRequest(
        id: m['id'] as String,
        providerId: m['provider_id'] as String,
        amount: (m['amount'] as num?) ?? 0,
        reference: m['reference'] as String,
        screenshotUrl: m['screenshot_url'] as String,
        status: (m['status'] as String?) ?? 'pending',
        adminNote: m['admin_note'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        reviewedAt: m['reviewed_at'] == null
            ? null
            : DateTime.parse(m['reviewed_at'] as String),
      );
  bool get isPending => status == 'pending';
}

/// A provider verification document (migration 001/002).
/// document_type is free text — 'cnic_front', 'cnic_back' or 'selfie'.
/// The CNIC *number* lives on the cnic_front row (document_number),
/// never on provider_profiles (those rows are publicly readable).
class ProviderDocument {  final String id;
  final String providerId;
  final String? documentType;
  final String? documentUrl;
  final String? documentNumber;
  final String verificationStatus;
  final DateTime createdAt;
  ProviderDocument({
    required this.id,
    required this.providerId,
    this.documentType,
    this.documentUrl,
    this.documentNumber,
    required this.verificationStatus,
    required this.createdAt,
  });
  factory ProviderDocument.fromMap(Map<String, dynamic> m) => ProviderDocument(
        id: m['id'] as String,
        providerId: m['provider_id'] as String,
        documentType: m['document_type'] as String?,
        documentUrl: m['document_url'] as String?,
        documentNumber: m['document_number'] as String?,
        verificationStatus: (m['verification_status'] as String?) ?? 'pending',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
  bool get isSelfie => documentType == 'selfie';
}

/// Pakistani CNIC: 13 digits, usually written 35202-1234567-1.
/// Mirrors the website (src/lib/provider.ts).
String normalizeCnic(String raw) => raw.replaceAll(RegExp(r'\D'), '');

bool isValidCnic(String raw) => normalizeCnic(raw).length == 13;

/// Pakistani mobile number: 11 digits starting with 03 (e.g.
/// 0300-1234567). Accepts spaces/dashes and the +92 form
/// (+92 300 1234567), which normalizes to 03001234567.
/// Mirrors the website (src/lib/provider.ts).
String normalizePakistaniMobile(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  // International form: 0092 300 … (14 digits) or +92 300 … (12 digits).
  if (digits.startsWith('0092') && digits.length == 14) {
    digits = '0${digits.substring(4)}';
  } else if (digits.startsWith('92') && digits.length == 12) {
    digits = '0${digits.substring(2)}';
  }
  return digits;
}

bool isValidPakistaniMobile(String raw) {
  final digits = normalizePakistaniMobile(raw);
  return digits.length == 11 && digits.startsWith('03');
}

/// Cash received at completion (migration 010): the provider must
/// declare a real amount (> 0). Parses the dialog input; null when the
/// text is not a number.
num? parseCashAmount(String raw) {
  final text = raw.trim().replaceAll(',', '');
  if (text.isEmpty) return null;
  final value = num.tryParse(text);
  if (value == null) return null;
  return value;
}

bool isValidCashReceivedAmount(num? amount) =>
    amount != null && amount > 0;

/// The single update the provider sends at completion: status ->
/// 'completed' together with the declared cash amount, so the DB
/// triggers (commission + cash audit) fire on one consistent row.
Map<String, dynamic> buildCashCompletionUpdate(num amount) => {
      'status': 'completed',
      'cash_received_amount': amount,
    };

/// Customer rating for a completed booking.
///
/// Whether the "Rate provider" card shows on the booking details
/// screen: only the booking's own customer, only once the job is
/// completed, only when a provider was assigned, and only while no
/// review exists yet for this booking. (The DB also enforces one
/// review per booking with the unique index idx_reviews_one_per_booking,
/// and the RLS policy reviews_insert_own only lets the booking's
/// customer insert — this is the matching UI-side gate.)
bool shouldShowRatingCard({
  required Booking booking,
  required String currentUserId,
  required bool hasReview,
}) =>
    booking.status == 'completed' &&
    booking.customerId == currentUserId &&
    booking.providerId != null &&
    !hasReview;

/// The review row the customer submits. Rating is 1-5 (CHECK
/// constraint in the DB); an empty comment is stored as NULL, not ''.
Map<String, dynamic> buildReviewInsert({
  required String bookingId,
  required String customerId,
  required String providerId,
  required int rating,
  String? comment,
}) =>
    {
      'booking_id': bookingId,
      'customer_id': customerId,
      'provider_id': providerId,
      'rating': rating,
      'comment': (comment == null || comment.trim().isEmpty)
          ? null
          : comment.trim(),
    };

/// Complaint status labels for the customer-facing complaint card and
/// the admin view. The DB CHECK constraint allows only these four.
String complaintStatusLabel(String status) {
  switch (status) {
    case 'open':
      return 'Open';
    case 'in_review':
      return 'In review';
    case 'resolved':
      return 'Resolved';
    case 'closed':
      return 'Closed';
    default:
      return status;
  }
}

/// Whether the "Report a problem" card shows on the booking details
/// screen: only the booking's own customer, and only while no complaint
/// exists yet for this booking. The complaints table has NO unique
/// constraint on booking_id, so this UI-side gate is what prevents a
/// second complaint for the same booking (the RLS policy
/// complaints_insert_own only lets the booking's customer insert).
bool shouldShowComplaintCard({
  required Booking booking,
  required String currentUserId,
  required bool hasComplaint,
}) =>
    booking.customerId == currentUserId && !hasComplaint;

/// The complaint row the customer files. providerId may be null when no
/// technician was assigned yet; the complaint text is required and
/// trimmed (empty text is rejected by the UI before this is built).
Map<String, dynamic> buildComplaintInsert({
  required String bookingId,
  required String customerId,
  required String? providerId,
  required String complaintText,
}) =>
    {
      'booking_id': bookingId,
      'customer_id': customerId,
      'provider_id': providerId,
      'complaint_text': complaintText.trim(),
    };

/// Per-job earnings for one completed booking (provider Earnings tab).
/// [jobValue] is what the job was worth, [commission] is the 15%
/// platform fee charged on it (from commission_ledger), and [earning]
/// is what the provider keeps.
class JobEarning {
  final String bookingId;
  final String serviceName;
  final DateTime date;
  final num jobValue;
  final num commission;
  JobEarning({
    required this.bookingId,
    required this.serviceName,
    required this.date,
    required this.jobValue,
    required this.commission,
  });

  /// What the provider keeps from this job: job value minus fee.
  num get earning => jobValue - commission;
}

/// The value of one job: the cash the provider declared at completion
/// (migration 010/011 — commission is 15% of this), else the final
/// price, else the estimate. 0 when the booking carries no amount.
num jobValueForBooking(Booking booking) =>
    booking.cashReceivedAmount ??
    booking.finalPrice ??
    booking.estimatedPrice ??
    0;

/// Merge completed bookings with their commission_ledger rows into a
/// per-job earnings list, newest first. Pure — unit-tested in
/// test/provider_job_earnings_test.dart. A booking with no ledger row
/// (commission not recorded yet) gets commission 0. The date is the
/// scheduled date, falling back to when the booking was created.
List<JobEarning> buildJobEarnings(
  List<Booking> bookings,
  List<Map<String, dynamic>> ledgerRows,
) {
  final commissionByBooking = <String, num>{
    for (final r in ledgerRows)
      if (r['booking_id'] is String)
        r['booking_id'] as String: (r['commission_amount'] as num?) ?? 0,
  };
  final out = bookings
      .map((b) => JobEarning(
            bookingId: b.id,
            serviceName: b.serviceName,
            date: b.scheduledAt ?? b.createdAt,
            jobValue: jobValueForBooking(b),
            commission: commissionByBooking[b.id] ?? 0,
          ))
      .toList();
  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}

/// A provider's live position (migration 007, table provider_locations).
/// One row per provider; visible to customers only while the provider is
/// online + approved + available (enforced server-side by RLS and by the
/// hide_location_when_offline trigger).
class ProviderLocation {
  final String providerId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final bool isOnline;
  final DateTime updatedAt;
  ProviderLocation({
    required this.providerId,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.isOnline,
    required this.updatedAt,
  });
  factory ProviderLocation.fromMap(Map<String, dynamic> m) => ProviderLocation(
        providerId: m['provider_id'] as String,
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        accuracyMeters: (m['accuracy_m'] as num?)?.toDouble(),
        isOnline: (m['is_online'] as bool?) ?? true,
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

/// A saved customer address (addresses table, migration 001) — the
/// booking's destination, with optional coordinates for the map.
class ServiceAddress {
  final String id;
  final String? addressLine;
  final String? city;
  final double? latitude;
  final double? longitude;
  ServiceAddress({
    required this.id,
    this.addressLine,
    this.city,
    this.latitude,
    this.longitude,
  });
  factory ServiceAddress.fromMap(Map<String, dynamic> m) => ServiceAddress(
        id: m['id'] as String,
        addressLine: m['address_line'] as String?,
        city: m['city'] as String?,
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
      );
}

/// Booking status labels + the ordered timeline used on the tracking screen.
/// Booking status code → l10n key (see statusLabel below).
const _statusLabelKeys = <String, String>{
  'pending': 'status_pending',
  'accepted': 'status_accepted',
  'rejected': 'status_rejected',
  'confirmed': 'status_confirmed',
  'on_the_way': 'status_on_the_way',
  'in_progress': 'status_in_progress',
  'completed': 'status_completed',
  'cancelled': 'status_cancelled',
  'disputed': 'status_disputed',
};

const bookingTimeline = ['pending', 'accepted', 'on_the_way', 'in_progress', 'completed'];

/// Translated booking status label — follows the app language through
/// tr(). Unknown codes fall back to the raw code, as before.
String statusLabel(String s) {
  final key = _statusLabelKeys[s];
  if (key == null) return s;
  return tr(key);
}
