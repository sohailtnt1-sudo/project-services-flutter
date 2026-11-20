// Unit tests for wallet top-up requests (migration 014, no Supabase
// needed): the TopupRequest model parses a row (including null admin
// note / reviewed_at), and the amount validation reused from the cash
// declaration accepts only amounts above Rs. 0.
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/models.dart';

void main() {
  group('TopupRequest.fromMap', () {
    Map<String, dynamic> row({String status = 'pending'}) => {
          'id': 'req-1',
          'provider_id': 'prov-1',
          'amount': 1000,
          'reference': 'TXN12345',
          'screenshot_url': 'https://example.com/proof.jpg',
          'status': status,
          'admin_note': null,
          'created_at': '2026-11-20T10:00:00.000Z',
          'reviewed_at': null,
        };

    test('parses a pending request', () {
      final r = TopupRequest.fromMap(row());
      expect(r.id, 'req-1');
      expect(r.providerId, 'prov-1');
      expect(r.amount, 1000);
      expect(r.reference, 'TXN12345');
      expect(r.screenshotUrl, 'https://example.com/proof.jpg');
      expect(r.status, 'pending');
      expect(r.isPending, isTrue);
      expect(r.adminNote, isNull);
      expect(r.reviewedAt, isNull);
      expect(r.createdAt, DateTime.parse('2026-11-20T10:00:00.000Z'));
    });

    test('approved and rejected are not pending', () {
      expect(TopupRequest.fromMap(row(status: 'approved')).isPending,
          isFalse);
      expect(TopupRequest.fromMap(row(status: 'rejected')).isPending,
          isFalse);
    });

    test('parses an approved request with admin note', () {
      final r = TopupRequest.fromMap({
        ...row(status: 'approved'),
        'admin_note': 'Verified on JazzCash.',
        'reviewed_at': '2026-11-20T11:00:00.000Z',
      });
      expect(r.adminNote, 'Verified on JazzCash.');
      expect(r.reviewedAt, DateTime.parse('2026-11-20T11:00:00.000Z'));
    });
  });

  group('top-up amount validation', () {
    test('accepts a positive amount', () {
      expect(isValidCashReceivedAmount(parseCashAmount('1000')), isTrue);
      expect(isValidCashReceivedAmount(parseCashAmount('1,000.50')),
          isTrue);
    });

    test('rejects zero, negative and empty amounts', () {
      expect(isValidCashReceivedAmount(parseCashAmount('0')), isFalse);
      expect(isValidCashReceivedAmount(parseCashAmount('-50')), isFalse);
      expect(isValidCashReceivedAmount(parseCashAmount('')), isFalse);
      expect(isValidCashReceivedAmount(parseCashAmount('abc')), isFalse);
    });
  });
}
