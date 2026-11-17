// Data models matching the Supabase tables (see website migration 001/002).
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
  final DateTime createdAt;
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
    required this.createdAt,
  });
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

/// A provider verification document (migration 001/002).
/// document_type is free text — 'cnic_front', 'cnic_back' or 'selfie'.
/// The CNIC *number* lives on the cnic_front row (document_number),
/// never on provider_profiles (those rows are publicly readable).
class ProviderDocument {
  final String id;
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
const bookingStatusLabels = <String, String>{
  'pending': 'Pending',
  'accepted': 'Accepted',
  'rejected': 'Rejected',
  'confirmed': 'Confirmed',
  'on_the_way': 'On the way',
  'in_progress': 'Work started',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
  'disputed': 'Disputed',
};

const bookingTimeline = ['pending', 'accepted', 'on_the_way', 'in_progress', 'completed'];

String statusLabel(String s) => bookingStatusLabels[s] ?? s;
