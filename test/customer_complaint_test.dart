// Unit tests for the customer complaint feature (no Supabase needed):
// when the "Report a problem" card shows, the complaint insert
// payload, and the status labels.
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/models.dart';

Booking _booking({
  String status = 'completed',
  String customerId = 'cust-1',
  String? providerId = 'prov-1',
}) =>
    Booking(
      id: 'bk-1',
      customerId: customerId,
      providerId: providerId,
      serviceName: 'Fan Repair',
      status: status,
      paymentStatus: 'paid',
      createdAt: DateTime(2026, 11, 20),
    );

void main() {
  group('shouldShowComplaintCard', () {
    test('shows for the own customer when no complaint exists yet', () {
      expect(
        shouldShowComplaintCard(
          booking: _booking(),
          currentUserId: 'cust-1',
          hasComplaint: false,
        ),
        isTrue,
      );
    });

    test('shows on any status, not only completed', () {
      for (final status in [
        'pending',
        'accepted',
        'on_the_way',
        'in_progress',
        'completed',
      ]) {
        expect(
          shouldShowComplaintCard(
            booking: _booking(status: status),
            currentUserId: 'cust-1',
            hasComplaint: false,
          ),
          isTrue,
          reason: 'status $status',
        );
      }
    });

    test('hides when a complaint already exists for the booking', () {
      expect(
        shouldShowComplaintCard(
          booking: _booking(),
          currentUserId: 'cust-1',
          hasComplaint: true,
        ),
        isFalse,
      );
    });

    test('hides for anyone but the booking customer', () {
      expect(
        shouldShowComplaintCard(
          booking: _booking(),
          currentUserId: 'someone-else',
          hasComplaint: false,
        ),
        isFalse,
      );
    });

    test('shows even when no provider is assigned yet', () {
      expect(
        shouldShowComplaintCard(
          booking: _booking(providerId: null),
          currentUserId: 'cust-1',
          hasComplaint: false,
        ),
        isTrue,
      );
    });
  });

  group('buildComplaintInsert', () {
    test('builds the complaint row with the given ids and text', () {
      expect(
        buildComplaintInsert(
          bookingId: 'bk-1',
          customerId: 'cust-1',
          providerId: 'prov-1',
          complaintText: 'Technician never arrived.',
        ),
        {
          'booking_id': 'bk-1',
          'customer_id': 'cust-1',
          'provider_id': 'prov-1',
          'complaint_text': 'Technician never arrived.',
        },
      );
    });

    test('trims the complaint text', () {
      final row = buildComplaintInsert(
        bookingId: 'bk-1',
        customerId: 'cust-1',
        providerId: 'prov-1',
        complaintText: '  Late by two hours.  ',
      );
      expect(row['complaint_text'], 'Late by two hours.');
    });

    test('keeps a null provider id when none is assigned', () {
      final row = buildComplaintInsert(
        bookingId: 'bk-1',
        customerId: 'cust-1',
        providerId: null,
        complaintText: 'No one accepted my booking.',
      );
      expect(row['provider_id'], isNull);
    });
  });

  group('complaintStatusLabel', () {
    test('labels all four statuses', () {
      expect(complaintStatusLabel('open'), 'Open');
      expect(complaintStatusLabel('in_review'), 'In review');
      expect(complaintStatusLabel('resolved'), 'Resolved');
      expect(complaintStatusLabel('closed'), 'Closed');
    });

    test('falls back to the raw value for an unknown status', () {
      expect(complaintStatusLabel('weird'), 'weird');
    });
  });
}
