// Unit tests for the Urdu/English language option (no Supabase needed):
// the language service defaults to English, switching to Urdu persists
// across a fresh service instance, and every English key has a
// non-empty Urdu value.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/l10n/language_toggle.dart';
import 'package:project_services/l10n/strings.dart';
import 'package:project_services/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    // Fresh prefs for every test.
    await prefs.clear();
  });

  group('LanguageService', () {
    test('default language is English', () async {
      final service = LanguageService();
      await service.load(prefs);
      expect(service.language, kLanguageEnglish);
      expect(service.isUrdu, isFalse);
    });

    test('switching to Urdu persists and a fresh service reads it back', () async {
      final service = LanguageService();
      await service.load(prefs);
      await service.setLanguage(kLanguageUrdu);
      expect(service.language, kLanguageUrdu);
      expect(service.isUrdu, isTrue);
      expect(prefs.getString(kLanguagePrefKey), kLanguageUrdu);

      final fresh = LanguageService();
      await fresh.load(prefs);
      expect(fresh.language, kLanguageUrdu);
    });

    test('switching back to English persists', () async {
      final service = LanguageService();
      await service.load(prefs);
      await service.setLanguage(kLanguageUrdu);
      await service.setLanguage(kLanguageEnglish);
      expect(service.language, kLanguageEnglish);
      expect(prefs.getString(kLanguagePrefKey), kLanguageEnglish);
    });

    test('unknown language codes are ignored', () async {
      final service = LanguageService();
      await service.load(prefs);
      await service.setLanguage('xx');
      expect(service.language, kLanguageEnglish);
      expect(prefs.getString(kLanguagePrefKey), isNull);
    });

    test('a saved invalid value falls back to English', () async {
      await prefs.setString(kLanguagePrefKey, 'fr');
      final service = LanguageService();
      await service.load(prefs);
      expect(service.language, kLanguageEnglish);
    });
  });

  group('strings', () {
    test('every English key has a non-empty Urdu value', () {
      for (final key in allStringKeys) {
        final ur = urduStrings[key];
        expect(ur, isNotNull, reason: 'missing Urdu for "$key"');
        expect(ur!.trim(), isNotEmpty, reason: 'empty Urdu for "$key"');
        expect(englishStrings[key]!.trim(), isNotEmpty,
            reason: 'empty English for "$key"');
      }
    });

    test('tr() follows the current language', () async {
      final service = languageService;
      await service.load(prefs);
      await service.setLanguage(kLanguageEnglish);
      expect(tr('home'), 'Home');
      await service.setLanguage(kLanguageUrdu);
      expect(tr('home'), 'ہوم');
      expect(trf('hello', {'name': 'Ali'}), 'السلام علیکم، Ali');
      // Leave the singleton in English for other tests.
      await service.setLanguage(kLanguageEnglish);
    });

    test('tr() falls back to the key for unknown keys', () {
      expect(tr('no_such_key_xyz'), 'no_such_key_xyz');
    });
  });

  group('LanguageToggle', () {
    testWidgets('shows a language menu with English and Urdu', (tester) async {
      await languageService.load(prefs);
      await languageService.setLanguage(kLanguageEnglish);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: LanguageToggle())),
        ),
      );
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
      expect(find.text('اردو'), findsOneWidget);
    });
  });
}
