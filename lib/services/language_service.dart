// App language (Urdu / English) — persisted locally, no account needed.
// The choice is stored in SharedPreferences under `asaankaam_language_v1`
// ('en' default, 'ur') and exposed as a ValueNotifier so the whole app
// rebuilds the moment the user switches. The service is a singleton:
// load it once in main() before runApp, then read `languageService`
// anywhere (UI strings come from lib/l10n/strings.dart).
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the saved language code.
const String kLanguagePrefKey = 'asaankaam_language_v1';

/// Supported language codes.
const String kLanguageEnglish = 'en';
const String kLanguageUrdu = 'ur';

const List<String> kSupportedLanguages = [kLanguageEnglish, kLanguageUrdu];

class LanguageService extends ValueNotifier<String> {
  /// Public constructor for tests; the app uses the [instance] singleton.
  LanguageService([super.value = kLanguageEnglish]);

  static final LanguageService _instance = LanguageService();

  /// The app-wide singleton. Call [load] once at startup before runApp.
  static LanguageService get instance => _instance;

  SharedPreferences? _prefs;

  /// Current language code ('en' or 'ur').
  String get language => value;

  bool get isUrdu => value == kLanguageUrdu;

  /// Load the saved language (English when nothing was saved yet).
  /// A [prefs] override exists for tests; the app passes none.
  Future<void> load([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
    final saved = _prefs!.getString(kLanguagePrefKey);
    if (saved != null && kSupportedLanguages.contains(saved)) {
      value = saved;
    }
  }

  /// Switch language and persist the choice. No-op for unknown codes.
  Future<void> setLanguage(String code) async {
    if (!kSupportedLanguages.contains(code)) return;
    if (value == code) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(kLanguagePrefKey, code);
    value = code;
  }
}

/// The app-wide language service singleton.
final LanguageService languageService = LanguageService.instance;
