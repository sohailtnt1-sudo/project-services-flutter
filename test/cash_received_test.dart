// Unit tests for the "Cash received" declaration (migration 010 —
// no Supabase needed): amount validation/parsing, the single
// completion update carrying status + cash amount together, and the
// new strings keys existing in both languages.
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/l10n/strings.dart';
import 'package:project_services/models.dart';

void main() {
  group('parseCashAmount', () {
    test('plain whole rupees', () {
      expect(parseCashAmount('1500'), 1500);
    });

    test('decimals and surrounding spaces', () {
      expect(parseCashAmount(' 1500.50 '), 1500.50);
    });

    test('thousands separators are stripped', () {
      expect(parseCashAmount('15,000'), 15000);
    });

    test('non-numeric and empty input return null', () {
      expect(parseCashAmount('abc'), isNull);
      expect(parseCashAmount(''), isNull);
      expect(parseCashAmount('   '), isNull);
    });
  });

  group('isValidCashReceivedAmount', () {
    test('positive amounts are valid', () {
      expect(isValidCashReceivedAmount(1500), isTrue);
      expect(isValidCashReceivedAmount(0.5), isTrue);
    });

    test('null, zero and negative amounts are rejected', () {
      expect(isValidCashReceivedAmount(null), isFalse);
      expect(isValidCashReceivedAmount(0), isFalse);
      expect(isValidCashReceivedAmount(-100), isFalse);
    });
  });

  group('buildCashCompletionUpdate', () {
    test('one update carries status completed + the cash amount', () {
      final update = buildCashCompletionUpdate(1500);
      expect(update['status'], 'completed');
      expect(update['cash_received_amount'], 1500);
      // The whole point: a single call, so the commission trigger and
      // the cash-audit trigger fire on the same consistent row.
      expect(update.length, 2);
    });

    test('a parsed + validated dialog amount flows through unchanged', () {
      final amount = parseCashAmount(' 2,500 ');
      expect(isValidCashReceivedAmount(amount), isTrue);
      final update = buildCashCompletionUpdate(amount!);
      expect(update['cash_received_amount'], 2500);
    });
  });

  group('cash strings exist in both languages', () {
    const keys = [
      'cashReceived',
      'cashReceivedTitle',
      'cashAmountLabel',
      'cashAmountError',
      'cashReceivedNote',
      'cashPaid',
      'confirmCompletion',
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
