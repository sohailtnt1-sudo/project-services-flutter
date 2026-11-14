// Unit tests for the in-app chat models (no Supabase needed).
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/models.dart';

void main() {
  test('Conversation parses a row and copyWith fills display fields', () {
    final c = Conversation.fromMap({
      'id': 'conv-1',
      'booking_id': 'book-1',
      'customer_id': 'cust-1',
      'provider_id': 'prov-1',
      'created_at': '2026-11-13T10:00:00Z',
    });
    expect(c.id, 'conv-1');
    expect(c.bookingId, 'book-1');
    expect(c.serviceName, 'Service');
    expect(c.otherPartyName, 'Chat');
    expect(c.unreadCount, 0);

    final filled = c.copyWith(
      serviceName: 'Fan Repair',
      otherPartyName: 'Ahmed Raza',
      lastMessageText: 'Hello',
      unreadCount: 2,
    );
    expect(filled.serviceName, 'Fan Repair');
    expect(filled.otherPartyName, 'Ahmed Raza');
    expect(filled.lastMessageText, 'Hello');
    expect(filled.unreadCount, 2);
    // The original is unchanged.
    expect(c.serviceName, 'Service');
    expect(c.unreadCount, 0);
  });

  test('ChatMessage parses a row, unread by default', () {
    final m = ChatMessage.fromMap({
      'id': 'msg-1',
      'conversation_id': 'conv-1',
      'sender_id': 'cust-1',
      'message_text': 'Assalam-o-Alaikum, kab aayenge?',
      'is_read': false,
      'created_at': '2026-11-13T10:05:00Z',
    });
    expect(m.id, 'msg-1');
    expect(m.conversationId, 'conv-1');
    expect(m.senderId, 'cust-1');
    expect(m.messageText, 'Assalam-o-Alaikum, kab aayenge?');
    expect(m.isRead, isFalse);
    expect(m.createdAt.year, 2026);
  });
}
