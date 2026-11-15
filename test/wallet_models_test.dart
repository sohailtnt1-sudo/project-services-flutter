// Unit tests for the provider wallet models (migration 005).
// No Supabase needed — pure row parsing + dues maths.
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/models.dart';
import 'package:project_services/repository.dart';

void main() {
  test('ProviderWallet parses a row; negative balance is dues', () {
    final w = ProviderWallet.fromMap({
      'provider_id': 'prov-1',
      'balance': -2250,
      'updated_at': '2026-11-15T10:00:00Z',
    });
    expect(w.providerId, 'prov-1');
    expect(w.balance, -2250);
    expect(w.hasDues, isTrue);
    expect(w.dues, 2250);
  });

  test('ProviderWallet with credit has no dues', () {
    final w = ProviderWallet.fromMap({
      'provider_id': 'prov-1',
      'balance': 5000,
      'updated_at': '2026-11-15T10:00:00Z',
    });
    expect(w.hasDues, isFalse);
    expect(w.dues, 0);
  });

  test('WalletTransaction parses rows and labels kinds', () {
    final commission = WalletTransaction.fromMap({
      'id': 'txn-1',
      'provider_id': 'prov-1',
      'kind': 'commission',
      'amount': -2250,
      'booking_id': 'book-1',
      'reference': null,
      'note': '15% platform commission',
      'created_at': '2026-11-15T11:00:00Z',
    });
    expect(commission.kindLabel, 'Platform fee (15%)');
    expect(commission.isCredit, isFalse);
    expect(commission.bookingId, 'book-1');

    final topup = WalletTransaction.fromMap({
      'id': 'txn-2',
      'provider_id': 'prov-1',
      'kind': 'topup',
      'amount': 5000,
      'booking_id': null,
      'reference': 'JC123456',
      'note': 'JazzCash top-up',
      'created_at': '2026-11-15T09:00:00Z',
    });
    expect(topup.kindLabel, 'Top-up');
    expect(topup.isCredit, isTrue);
    expect(topup.reference, 'JC123456');
  });

  test('Dues limit constant matches the database limit (Rs. 2,000)', () {
    // Display-only constant — enforcement is server-side in
    // public.wallet_dues_limit() (migration 005). If the DB limit
    // changes, this must change to match.
    expect(kWalletDuesLimitRs, 2000);
    // A provider at exactly -2,000 is still allowed; -2,001 is not.
    expect(-2000 >= -kWalletDuesLimitRs, isTrue);
    expect(-2001 >= -kWalletDuesLimitRs, isFalse);
  });
}
