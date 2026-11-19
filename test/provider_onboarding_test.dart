// Unit tests for provider onboarding helpers (no Supabase needed):
// CNIC validation/normalisation, the ProviderDocument model, and the
// platform guideline warning for a provider's own charge.
import 'package:flutter/material.dart';
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

  group('Pakistani mobile helpers', () {
    test('normalizePakistaniMobile strips spaces and dashes', () {
      expect(normalizePakistaniMobile('0300-1234567'), '03001234567');
      expect(normalizePakistaniMobile('0300 1234567'), '03001234567');
      expect(normalizePakistaniMobile('03001234567'), '03001234567');
    });

    test('normalizePakistaniMobile converts +92 to the 0 form', () {
      expect(normalizePakistaniMobile('+92 300 1234567'), '03001234567');
      expect(normalizePakistaniMobile('+923001234567'), '03001234567');
      expect(normalizePakistaniMobile('0092 300 1234567'), '03001234567');
    });

    test('isValidPakistaniMobile accepts 11 digits starting with 03', () {
      expect(isValidPakistaniMobile('03001234567'), isTrue);
      expect(isValidPakistaniMobile('0300-1234567'), isTrue);
      expect(isValidPakistaniMobile('0300 1234567'), isTrue);
      expect(isValidPakistaniMobile('+92 300 1234567'), isTrue);
      expect(isValidPakistaniMobile('03331234567'), isTrue);
    });

    test('isValidPakistaniMobile rejects landlines and wrong lengths', () {
      expect(isValidPakistaniMobile('02131234567'), isFalse); // landline
      expect(isValidPakistaniMobile('0300123456'), isFalse); // 10 digits
      expect(isValidPakistaniMobile('030012345678'), isFalse); // 12 digits
      expect(isValidPakistaniMobile(''), isFalse);
      expect(isValidPakistaniMobile('abc'), isFalse);
      expect(isValidPakistaniMobile('92001234567'), isFalse);
    });
  });

  group('MobileNumberField (Step 1 form field)', () {
    testWidgets('renders a phone-keyboard field labelled Mobile number',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileNumberField(controller: controller),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.phone);
      expect(field.decoration?.labelText, 'Mobile number');
      expect(field.decoration?.hintText, '0300-1234567');
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows the prefilled number from the account profile',
        (tester) async {
      final controller = TextEditingController(text: '03063833728');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileNumberField(controller: controller),
          ),
        ),
      );
      expect(find.text('03063833728'), findsOneWidget);
    });
  });
}
