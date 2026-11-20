// Unit tests for the customer rating feature (no Supabase needed):
// when the "Rate provider" card shows, the review insert payload,
// and the new strings keys existing in both languages.
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/l10n/strings.dart';
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
  group('shouldShowRatingCard', () {
    test('shows for the own customer on a completed job with no review', () {
      expect(
        shouldShowRatingCard(
          booking: _booking(),
          currentUserId: 'cust-1',
          hasReview: false,
        ),
        isTrue,
      );
    });

    test('hides when the job is not completed', () {
      for (final status in [
        'pending',
        'accepted',
        'on_the_way',
        'in_progress',
      ]) {
        expect(
          shouldShowRatingCard(
            booking: _booking(status: status),
            currentUserId: 'cust-1',
            hasReview: false,
          ),
          isFalse,
          reason: 'status $status',
        );
      }
    });

    test('hides when a review already exists', () {
      expect(
        shouldShowRatingCard(
          booking: _booking(),
          currentUserId: 'cust-1',
          hasReview: true,
        ),
        isFalse,
      );
    });

    test('hides for anyone but the booking customer', () {
      expect(
        shouldShowRatingCard(
          booking: _booking(),
          currentUserId: 'someone-else',
          hasReview: false,
        ),
        isFalse,
      );
    });

    test('hides when no provider was assigned', () {
      expect(
        shouldShowRatingCard(
          booking: _booking(providerId: null),
          currentUserId: 'cust-1',
          hasReview: false,
        ),
        isFalse,
      );
    });
  });

  group('buildReviewInsert', () {
    test('carries booking, customer, provider, rating', () {
      final row = buildReviewInsert(
        bookingId: 'bk-1',
        customerId: 'cust-1',
        providerId: 'prov-1',
        rating: 5,
        comment: 'Great work!',
      );
      expect(row['booking_id'], 'bk-1');
      expect(row['customer_id'], 'cust-1');
      expect(row['provider_id'], 'prov-1');
      expect(row['rating'], 5);
      expect(row['comment'], 'Great work!');
    });

    test('trims the comment and stores empty comment as null', () {
      final withComment = buildReviewInsert(
        bookingId: 'bk-1',
        customerId: 'cust-1',
        providerId: 'prov-1',
        rating: 4,
        comment: '  Good job  ',
      );
      expect(withComment['comment'], 'Good job');

      final empty = buildReviewInsert(
        bookingId: 'bk-1',
        customerId: 'cust-1',
        providerId: 'prov-1',
        rating: 4,
        comment: '   ',
      );
      expect(empty['comment'], isNull);

      final absent = buildReviewInsert(
        bookingId: 'bk-1',
        customerId: 'cust-1',
        providerId: 'prov-1',
        rating: 4,
      );
      expect(absent['comment'], isNull);
    });
  });

  group('rating strings exist in both languages', () {
    const keys = [
      'rateProvider',
      'rateProviderHint',
      'yourRating',
      'writeCommentOptional',
      'submitRating',
      'selectStars',
      'ratingSubmitted',
      'ratingFailed',
      'alreadyRated',
    ];
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
