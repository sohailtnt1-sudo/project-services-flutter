// Unit tests for provider onboarding helpers (no Supabase needed):
// CNIC validation/normalisation, the ProviderDocument model, and the
// platform guideline warning for a provider's own charge.
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/models.dart';
import 'package:project_services/screens/provider_onboarding_screen.dart';

void main() {
  group('CNIC helpers', () {
    test('normalizeCnic strips dashes and spaces', () {
      expect(normalizeCnic('35202-1234567-1'), '3520212345671');
      expect(normalizeCnic('35202 1234567 1'), '3520212345671');
      expect(normalizeCnic('3520212345671'), '3520212345671');
    });

    test('isValidCnic accepts exactly 13 digits', () {
      expect(isValidCnic('35202-1234567-1'), isTrue);
      expect(isValidCnic('3520212345671'), isTrue);
      expect(isValidCnic('35202-1234567'), isFalse);
      expect(isValidCnic('35202-1234567-12'), isFalse);
      expect(isValidCnic(''), isFalse);
      expect(isValidCnic('abc'), isFalse);
    });
  });

  group('ProviderDocument model', () {
    test('fromMap parses a selfie row', () {
      final doc = ProviderDocument.fromMap({
        'id': 'doc-1',
        'provider_id': 'prov-1',
        'document_type': 'selfie',
        'document_url': 'https://example.com/selfie.jpg',
        'document_number': null,
        'verification_status': 'pending',
        'created_at': '2026-11-15T10:00:00Z',
      });
      expect(doc.isSelfie, isTrue);
      expect(doc.documentType, 'selfie');
      expect(doc.documentUrl, 'https://example.com/selfie.jpg');
      expect(doc.documentNumber, isNull);
      expect(doc.verificationStatus, 'pending');
    });

    test('fromMap parses a CNIC front row with the CNIC number', () {
      final doc = ProviderDocument.fromMap({
        'id': 'doc-2',
        'provider_id': 'prov-1',
        'document_type': 'cnic_front',
        'document_url': 'https://example.com/cnic.jpg',
        'document_number': '3520212345671',
        'verification_status': 'approved',
        'created_at': '2026-11-15T10:00:00Z',
      });
      expect(doc.isSelfie, isFalse);
      expect(doc.documentNumber, '3520212345671');
    });
  });

  group('priceGuidelineWarning', () {
    test('no warning inside 50%–200% of the base price', () {
      expect(priceGuidelineWarning(1000, 1000), isNull);
      expect(priceGuidelineWarning(500, 1000), isNull);
      expect(priceGuidelineWarning(2000, 1000), isNull);
    });

    test('warns below 50% and above 200% of the base price', () {
      expect(priceGuidelineWarning(499, 1000), isNotNull);
      expect(priceGuidelineWarning(2001, 1000), isNotNull);
    });

    test('no warning when the base price is missing', () {
      expect(priceGuidelineWarning(100, 0), isNull);
    });
  });
}
