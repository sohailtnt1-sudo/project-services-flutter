// Widget test for the live Urdu/English switch (no network, no real
// Supabase): pumps the REAL ProjectServicesApp with a dummy Supabase
// client, taps the auth screen's language toggle, and asserts the visible
// labels actually become Urdu WITHOUT an app restart.
//
// Regression test for the 20 Nov report: tapping Urdu changed nothing —
// not even the bottom tabs — because `home: const AuthGate()` in main.dart
// short-circuited the rebuild: the ValueListenableBuilder rebuilt
// MaterialApp, but the identical const home widget meant the AuthGate
// subtree was never re-invoked, so tr() was never re-evaluated.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/main.dart';
import 'package:project_services/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns a valid 1x1 transparent PNG for image keys, and valid empty
/// manifests for the manifest keys the framework looks up, so the auth
/// screen's logo (Image.asset) decodes in tests without the real bundle.
class _TestAssetBundle extends CachingAssetBundle {
  static final ByteData _png = ByteData.view(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    ).buffer,
  );

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      // Empty binary asset manifest (StandardMessageCodec-encoded map).
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    if (key == 'AssetManifest.json') {
      return ByteData.view(Uint8List.fromList(utf8.encode('{}')).buffer);
    }
    if (key == 'FontManifest.json') {
      return ByteData.view(Uint8List.fromList(utf8.encode('[]')).buffer);
    }
    return _png;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await languageService.load();
    // Dummy client so AuthGate's db.auth stream works offline; no network
    // call happens at init or while signed out.
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (_) {
      // Already initialised in this process (another test file).
    }
  });

  setUp(() async {
    await languageService.setLanguage(kLanguageEnglish);
  });

  tearDown(() async {
    await languageService.setLanguage(kLanguageEnglish);
  });

  testWidgets('tapping Urdu on the auth screen switches visible labels live',
      (tester) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _TestAssetBundle(),
        child: const ProjectServicesApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Signed out, English by default.
    expect(find.text('Log in'), findsWidgets);
    expect(find.text('لاگ ان'), findsNothing);
    expect(find.text('Sign up'), findsWidgets);

    // The auth screen's text toggle shows the OTHER language: 'اردو'.
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();

    // Live switch: labels become Urdu without any restart.
    expect(find.text('لاگ ان'), findsWidgets);
    expect(find.text('سائن اپ'), findsWidgets);
    expect(find.text('Log in'), findsNothing);
    expect(find.text('Sign up'), findsNothing);
  });
}
