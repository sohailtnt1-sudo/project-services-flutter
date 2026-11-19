// Unit tests for the per-job earnings breakdown on the provider
// Earnings tab (no Supabase needed): job-value precedence, earning
// math, missing ledger rows, and newest-first ordering — all through
// the pure merge in models.dart (buildJobEarnings).
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/l10n/strings.dart';
import 'package:project_services/models.dart';

Booking _booking({
  required String id,
  DateTime? scheduledAt,
  required DateTime createdAt,
  String serviceName = 'Fan Repair',
  num? cash,
  num? finalPrice,
  num? estimatedPrice,
}) =>
    Booking(
      id: id,
      customerId: 'cust-1',
      serviceName: serviceName,
      status: 'completed',
      paymentStatus: 'paid',
      scheduledAt: scheduledAt,
      estimatedPrice: estimatedPrice,
      finalPrice: finalPrice,
      cashReceivedAmount: cash,
      createdAt: createdAt,
    );

Map<String, dynamic> _ledger(String bookingId, num commission) => {
      'booking_id': bookingId,
      'booking_amount': 1000,
      'commission_amount': commission,
      'provider_amount': 1000 - commission,
    };

void main() {
  group('jobValueForBooking', () {
    test('cash received wins over final price and estimate', () {
      final b = _booking(
        id: 'b1',
        createdAt: DateTime(2026, 11, 19),
        cash: 1200,
        finalPrice: 1000,
        estimatedPrice: 900,
      );
      expect(jobValueForBooking(b), 1200);
    });

    test('final price wins when no cash was declared', () {
      final b = _booking(
        id: 'b1',
        createdAt: DateTime(2026, 11, 19),
        finalPrice: 1000,
        estimatedPrice: 900,
      );
      expect(jobValueForBooking(b), 1000);
    });

    test('estimate is the fallback when cash and final price are absent', () {
      final b = _booking(
        id: 'b1',
        createdAt: DateTime(2026, 11, 19),
        estimatedPrice: 900,
      );
      expect(jobValueForBooking(b), 900);
    });

    test('no amount anywhere is 0, never null', () {
      final b = _booking(id: 'b1', createdAt: DateTime(2026, 11, 19));
      expect(jobValueForBooking(b), 0);
    });
  });

  group('buildJobEarnings', () {
    test('earning is job value minus commission', () {
      final out = buildJobEarnings(
        [
          _booking(
            id: 'b1',
            createdAt: DateTime(2026, 11, 19),
            cash: 1000,
          ),
        ],
        [_ledger('b1', 150)],
      );
      expect(out, hasLength(1));
      expect(out.first.jobValue, 1000);
      expect(out.first.commission, 150);
      expect(out.first.earning, 850);
    });

    test('missing ledger row means commission 0 and full value kept', () {
      final out = buildJobEarnings(
        [
          _booking(
            id: 'b1',
            createdAt: DateTime(2026, 11, 19),
            cash: 2000,
          ),
        ],
        [],
      );
      expect(out.first.commission, 0);
      expect(out.first.earning, 2000);
    });

    test('ledger rows for other bookings are ignored', () {
      final out = buildJobEarnings(
        [
          _booking(
            id: 'b1',
            createdAt: DateTime(2026, 11, 19),
            cash: 1000,
          ),
        ],
        [_ledger('b1', 150), _ledger('someone-else', 999)],
      );
      expect(out.first.commission, 150);
      expect(out.first.earning, 850);
    });

    test('newest first by scheduled date', () {
      final out = buildJobEarnings(
        [
          _booking(
            id: 'old',
            scheduledAt: DateTime(2026, 11, 10, 10),
            createdAt: DateTime(2026, 11, 10),
            cash: 500,
          ),
          _booking(
            id: 'new',
            scheduledAt: DateTime(2026, 11, 18, 10),
            createdAt: DateTime(2026, 11, 18),
            cash: 1500,
          ),
          _booking(
            id: 'mid',
            scheduledAt: DateTime(2026, 11, 15, 10),
            createdAt: DateTime(2026, 11, 15),
            cash: 800,
          ),
        ],
        [],
      );
      expect(out.map((j) => j.bookingId).toList(), ['new', 'mid', 'old']);
    });

    test('date falls back to created_at when no scheduled date', () {
      final out = buildJobEarnings(
        [
          _booking(
            id: 'b1',
            createdAt: DateTime(2026, 11, 17, 9, 30),
            cash: 700,
          ),
        ],
        [],
      );
      expect(out.first.date, DateTime(2026, 11, 17, 9, 30));
    });

    test('service name and booking id carry through', () {
      final out = buildJobEarnings(
        [
          _booking(
            id: 'b1',
            serviceName: 'Grocery Delivery',
            createdAt: DateTime(2026, 11, 19),
            cash: 300,
          ),
        ],
        [_ledger('b1', 45)],
      );
      expect(out.first.bookingId, 'b1');
      expect(out.first.serviceName, 'Grocery Delivery');
      // 15% of 300 = 45 kept, 255 earned.
      expect(out.first.earning, 255);
    });

    test('empty input is an empty list', () {
      expect(buildJobEarnings([], []), isEmpty);
    });
  });

  group('per-job earnings strings exist in both languages', () {
    const keys = ['perJobEarnings', 'youKeep', 'noJobEarnings'];
    for (final key in keys) {
      test('$key has a non-empty English and Urdu value', () {
        expect(englishStrings[key], isNotNull);
        expect(englishStrings[key]!.trim().isNotEmpty, isTrue);
        expect(urduStrings[key], isNotNull);
        expect(urduStrings[key]!.trim().isNotEmpty, isTrue);
      });
    }
  });
}
